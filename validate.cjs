const fs = require('fs');
const vm = require('vm');
const assert = require('assert');
const context = {window:{}};
vm.runInNewContext(fs.readFileSync(__dirname+'/catalog.js','utf8'),context);
const {products,recipes}=context.window.CASA_CATALOG;
assert(products.length>=50 && recipes.length>=50);
const map=new Map(products.map(p=>[p.slug,p]));
assert.strictEqual(map.size,products.length);
for(const p of products){assert(p.package_size>0);assert(['g','ml','ud'].includes(p.unit))}
for(const r of recipes){assert(r.ingredients.length>0);for(const i of r.ingredients){assert(map.has(i.slug),`${r.name}: ${i.slug}`);assert(i.amount>0);assert.strictEqual(i.unit,map.get(i.slug).unit)}}
const schema=fs.readFileSync(__dirname+'/supabase/schema.sql','utf8');
for(const table of ['profiles','household_members','tasks','notifications','push_subscriptions'])assert(schema.includes(`alter table public.${table} enable row level security`));
assert(schema.includes('own_profile_select') && schema.includes('user_id=(select auth.uid())'));
assert(schema.includes('private.is_admin(household_id)'));
console.log(`Catálogo: ${products.length} productos, ${recipes.length} platos. Acceso RLS declarado.`);
