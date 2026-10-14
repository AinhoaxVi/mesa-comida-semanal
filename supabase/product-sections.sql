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
