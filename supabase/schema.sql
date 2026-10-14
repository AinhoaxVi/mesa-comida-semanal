-- Run once in the Supabase SQL editor. Auth users are created through the app.
create extension if not exists pgcrypto;
create schema if not exists private;

create table public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (length(display_name) between 1 and 80),
  likes text[] not null default '{}',
  dislikes text[] not null default '{}',
  allergens text[] not null default '{}',
  intolerances text[] not null default '{}',
  updated_at timestamptz not null default now()
);
create table public.households (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id),
  name text not null default 'Nuestro hogar',
  created_at timestamptz not null default now()
);
create table public.household_members (
  household_id uuid not null references public.households(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('admin','member')),
  label text not null check (length(label) between 1 and 80),
  primary key (household_id,user_id)
);

create function private.is_member(hid uuid) returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.household_members where household_id=hid and user_id=(select auth.uid()))
$$;
create function private.is_admin(hid uuid) returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.household_members where household_id=hid and user_id=(select auth.uid()) and role='admin')
$$;
create function private.has_members(hid uuid) returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.household_members where household_id=hid)
$$;
grant usage on schema private to authenticated;
grant execute on function private.is_member(uuid), private.is_admin(uuid), private.has_members(uuid) to authenticated;

create table public.products (
  id uuid primary key default gen_random_uuid(), household_id uuid not null references public.households(id) on delete cascade,
  slug text not null, name text not null, package_size numeric not null check(package_size>0),
  unit text not null check(unit in ('g','ml','ud')), package_type text not null, category text not null,
  unique(household_id,slug)
);
create table public.recipes (
  id uuid primary key default gen_random_uuid(), household_id uuid not null references public.households(id) on delete cascade,
  slug text not null, name text not null, category text not null default 'personalizado',
  minutes int not null default 30, servings int not null default 2 check(servings>0),
  enabled boolean not null default true, ingredients jsonb not null default '[]' check(jsonb_typeof(ingredients)='array'),
  unique(household_id,slug), unique(household_id,id)
);
alter table public.products add constraint products_household_id_id_unique unique(household_id,id);
create table public.menu_slots (
  id uuid primary key default gen_random_uuid(), household_id uuid not null references public.households(id) on delete cascade,
  day date not null, meal text not null check(meal in ('comida','cena')),
  recipe_id uuid, eating_out boolean not null default false,
  foreign key(household_id,recipe_id) references public.recipes(household_id,id),
  unique(household_id,day,meal)
);
create table public.pantry (
  household_id uuid not null, product_id uuid not null, quantity numeric not null default 0 check(quantity>=0),
  primary key(household_id,product_id), foreign key(household_id,product_id) references public.products(household_id,id)
);
create table public.freezer (
  id uuid primary key default gen_random_uuid(), household_id uuid not null references public.households(id) on delete cascade,
  recipe_id uuid not null, portions int not null check(portions>0), made_on date not null default current_date,
  foreign key(household_id,recipe_id) references public.recipes(household_id,id)
);
create table public.shopping_extras (
  id uuid primary key default gen_random_uuid(), household_id uuid not null references public.households(id) on delete cascade,
  name text not null, quantity text not null default '1 ud', checked boolean not null default false,
  created_at timestamptz not null default now()
);
create table public.shopping_checks (
  household_id uuid not null references public.households(id) on delete cascade,
  product_id uuid not null, checked boolean not null default false,
  primary key(household_id,product_id), foreign key(household_id,product_id) references public.products(household_id,id)
);
create table public.tasks (
  id uuid primary key default gen_random_uuid(), household_id uuid not null references public.households(id) on delete cascade,
  name text not null, emoji text not null default '🧹', interval_days int not null check(interval_days between 1 and 365),
  start_day date not null default current_date, active boolean not null default true,
  unique(household_id,id)
);
create table public.task_completions (
  id uuid primary key default gen_random_uuid(), household_id uuid not null references public.households(id) on delete cascade,
  task_id uuid not null, cycle_day date not null, done_by uuid not null default auth.uid() references auth.users(id),
  done_at timestamptz not null default now(),
  foreign key(household_id,task_id) references public.tasks(household_id,id),
  unique(task_id,cycle_day)
);
create table public.notifications (
  id uuid primary key default gen_random_uuid(), household_id uuid not null references public.households(id) on delete cascade,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  actor_id uuid not null references auth.users(id), body text not null, read_at timestamptz,
  created_at timestamptz not null default now()
);
create table public.push_subscriptions (
  endpoint text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  subscription jsonb not null,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.households enable row level security;
alter table public.household_members enable row level security;
alter table public.products enable row level security;
alter table public.recipes enable row level security;
alter table public.menu_slots enable row level security;
alter table public.pantry enable row level security;
alter table public.freezer enable row level security;
alter table public.shopping_extras enable row level security;
alter table public.shopping_checks enable row level security;
alter table public.tasks enable row level security;
alter table public.task_completions enable row level security;
alter table public.notifications enable row level security;
alter table public.push_subscriptions enable row level security;

create policy own_profile_select on public.profiles for select to authenticated using(user_id=(select auth.uid()));
create policy own_profile_insert on public.profiles for insert to authenticated with check(user_id=(select auth.uid()));
create policy own_profile_update on public.profiles for update to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
create policy households_select on public.households for select to authenticated using(private.is_member(id) or owner_id=(select auth.uid()));
create policy households_insert on public.households for insert to authenticated with check(owner_id=(select auth.uid()));
create policy households_update on public.households for update to authenticated using(private.is_admin(id)) with check(private.is_admin(id));
create policy members_select on public.household_members for select to authenticated using(user_id=(select auth.uid()) or private.is_member(household_id));
create policy members_insert on public.household_members for insert to authenticated with check(
  (private.is_admin(household_id) and role='member') or
  (user_id=(select auth.uid()) and role='admin' and exists(select 1 from public.households h where h.id=household_members.household_id and h.owner_id=(select auth.uid())) and not private.has_members(household_id))
);
create policy members_delete on public.household_members for delete to authenticated using(private.is_admin(household_id) and role='member');

create policy products_read on public.products for select to authenticated using(private.is_member(household_id));
create policy products_write on public.products for all to authenticated using(private.is_member(household_id)) with check(private.is_member(household_id));
create policy recipes_read on public.recipes for select to authenticated using(private.is_member(household_id));
create policy recipes_write on public.recipes for all to authenticated using(private.is_member(household_id)) with check(private.is_member(household_id));
create policy menu_read on public.menu_slots for select to authenticated using(private.is_member(household_id));
create policy menu_write on public.menu_slots for all to authenticated using(private.is_member(household_id)) with check(private.is_member(household_id));
create policy pantry_read on public.pantry for select to authenticated using(private.is_member(household_id));
create policy pantry_write on public.pantry for all to authenticated using(private.is_member(household_id)) with check(private.is_member(household_id));
create policy freezer_read on public.freezer for select to authenticated using(private.is_member(household_id));
create policy freezer_write on public.freezer for all to authenticated using(private.is_member(household_id)) with check(private.is_member(household_id));
create policy extras_read on public.shopping_extras for select to authenticated using(private.is_member(household_id));
create policy extras_write on public.shopping_extras for all to authenticated using(private.is_member(household_id)) with check(private.is_member(household_id));
create policy checks_read on public.shopping_checks for select to authenticated using(private.is_member(household_id));
create policy checks_write on public.shopping_checks for all to authenticated using(private.is_member(household_id)) with check(private.is_member(household_id));
create policy tasks_read on public.tasks for select to authenticated using(private.is_member(household_id));
create policy tasks_write on public.tasks for all to authenticated using(private.is_admin(household_id)) with check(private.is_admin(household_id));
create policy completion_read on public.task_completions for select to authenticated using(private.is_member(household_id));
create policy completion_insert on public.task_completions for insert to authenticated with check(private.is_member(household_id) and done_by=(select auth.uid()));
create policy notification_read on public.notifications for select to authenticated using(recipient_id=(select auth.uid()) and private.is_member(household_id));
create policy notification_update on public.notifications for update to authenticated using(recipient_id=(select auth.uid()) and private.is_member(household_id)) with check(recipient_id=(select auth.uid()) and private.is_member(household_id));
create policy push_read on public.push_subscriptions for select to authenticated using(user_id=(select auth.uid()));
create policy push_insert on public.push_subscriptions for insert to authenticated with check(user_id=(select auth.uid()));
create policy push_delete on public.push_subscriptions for delete to authenticated using(user_id=(select auth.uid()));
revoke update on public.notifications from authenticated;
grant update(read_at) on public.notifications to authenticated;

create or replace function public.create_household(home_name text, initial_products jsonb default '[]', initial_recipes jsonb default '[]') returns uuid
language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); home_id uuid; actor_label text;
begin
  if actor is null then raise exception 'Inicia sesión antes de crear el hogar'; end if;
  if home_name is null or length(trim(home_name)) not between 1 and 80 then raise exception 'Introduce un nombre de hogar de 1 a 80 caracteres'; end if;
  if jsonb_typeof(initial_products) is distinct from 'array' or jsonb_typeof(initial_recipes) is distinct from 'array' then raise exception 'El catálogo debe contener listas'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(actor::text,0));
  select p.display_name into actor_label from public.profiles p where p.user_id=actor;
  if actor_label is null then raise exception 'Guarda tu perfil antes de crear el hogar'; end if;
  select m.household_id into home_id from public.household_members m where m.user_id=actor order by m.household_id limit 1;
  if home_id is null then
    select h.id into home_id from public.households h where h.owner_id=actor
      and not exists(select 1 from public.household_members m where m.household_id=h.id)
      order by h.created_at,h.id limit 1 for update;
    if home_id is null then
      insert into public.households(owner_id,name) values(actor,trim(home_name)) returning id into home_id;
    else
      update public.households set name=trim(home_name) where id=home_id and owner_id=actor;
    end if;
    insert into public.household_members(household_id,user_id,role,label) values(home_id,actor,'admin',actor_label);
  end if;
  insert into public.products(household_id,slug,name,package_size,unit,package_type,category)
    select home_id,x.slug,x.name,x.package_size,x.unit,x.package_type,x.category
    from jsonb_to_recordset(initial_products) as x(slug text,name text,package_size numeric,unit text,package_type text,category text)
    on conflict(household_id,slug) do nothing;
  insert into public.recipes(household_id,slug,name,category,minutes,servings,enabled,ingredients)
    select home_id,x.slug,x.name,coalesce(x.category,'personalizado'),coalesce(x.minutes,30),coalesce(x.servings,2),coalesce(x.enabled,true),coalesce(x.ingredients,'[]'::jsonb)
    from jsonb_to_recordset(initial_recipes) as x(slug text,name text,category text,minutes int,servings int,enabled boolean,ingredients jsonb)
    on conflict(household_id,slug) do nothing;
  return home_id;
end $$;
revoke all on function public.create_household(text,jsonb,jsonb) from public,anon;
grant execute on function public.create_household(text,jsonb,jsonb) to authenticated;

create or replace function public.send_test_notification(hid uuid) returns uuid
language plpgsql security definer set search_path = '' as $$
declare notice_id uuid;
begin
  if auth.uid() is null or not private.is_member(hid) then raise exception 'El hogar no está vinculado a tu cuenta'; end if;
  insert into public.notifications(household_id,recipient_id,actor_id,body)
    values(hid,auth.uid(),auth.uid(),'🔔 Las notificaciones de Casa a Punto están activadas') returning id into notice_id;
  return notice_id;
end $$;
revoke all on function public.send_test_notification(uuid) from public,anon;
grant execute on function public.send_test_notification(uuid) to authenticated;

-- Returns an anonymous recipe selection. Members cannot read one another's profile.
-- Text matching is only a suggestion filter; food labels require human review.
create function public.allowed_recipes(hid uuid) returns table(recipe_id uuid)
language sql stable security definer set search_path = '' as $$
  select r.id from public.recipes r
  where r.household_id=hid and r.enabled and private.is_member(hid)
  and not exists (
    select 1 from public.household_members m join public.profiles p on p.user_id=m.user_id
    cross join lateral unnest(p.dislikes || p.allergens || p.intolerances) as excluded(term)
    where m.household_id=hid and length(trim(excluded.term))>1
    and (r.name ilike '%' || excluded.term || '%' or exists (
      select 1 from jsonb_array_elements(r.ingredients) ing
      join public.products prod on prod.household_id=hid and prod.slug=ing->>'slug'
      where prod.name ilike '%' || excluded.term || '%'
    ))
  )
$$;
revoke all on function public.allowed_recipes(uuid) from public;
revoke all on function public.allowed_recipes(uuid) from anon;
grant execute on function public.allowed_recipes(uuid) to authenticated;

create function private.notify_task() returns trigger language plpgsql security definer set search_path = '' as $$
declare t public.tasks; actor text;
begin
  select * into t from public.tasks where id=new.task_id and household_id=new.household_id;
  select label into actor from public.household_members where household_id=new.household_id and user_id=new.done_by;
  insert into public.notifications(household_id,recipient_id,actor_id,body)
  select new.household_id,m.user_id,new.done_by,t.emoji || ' ' || actor || ' ha completado: ' || t.name
  from public.household_members m where m.household_id=new.household_id and m.user_id<>new.done_by;
  return new;
end $$;
create trigger task_done_notice after insert on public.task_completions for each row execute function private.notify_task();
-- A member cannot forge the completion of a task in another home or somebody else's identity.
create index notifications_recipient_created on public.notifications(recipient_id,created_at desc);
create index slots_household_day on public.menu_slots(household_id,day);
create index completion_task_day on public.task_completions(task_id,cycle_day);

-- Realtime only publishes the shared tables and each recipient's notifications.
alter publication supabase_realtime add table public.menu_slots,public.products,public.recipes,public.pantry,public.freezer,public.shopping_extras,public.shopping_checks,public.tasks,public.task_completions,public.notifications;

-- Custom shared product sections
create table if not exists public.product_sections (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  name text not null check(length(trim(name)) between 1 and 80)
);
create unique index if not exists product_sections_unique_name on public.product_sections(household_id,lower(name));
alter table public.product_sections enable row level security;
create policy product_sections_read on public.product_sections for select to authenticated using(private.is_member(household_id));
create policy product_sections_insert on public.product_sections for insert to authenticated with check(private.is_member(household_id));
grant select,insert on public.product_sections to authenticated;
alter publication supabase_realtime add table public.product_sections;
