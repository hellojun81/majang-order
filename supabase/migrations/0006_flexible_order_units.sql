create table if not exists public.product_order_units (
  id bigint generated always as identity primary key,
  product_id bigint not null references public.products(id) on delete cascade,
  unit_code text not null check (unit_code in ('kg', 'box', 'piece', 'pack')),
  settlement_method text not null default 'actual_weight'
    check (settlement_method in ('ordered_quantity', 'actual_weight')),
  estimated_weight_per_unit numeric(10, 3),
  is_default boolean not null default false,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (product_id, unit_code)
);

drop trigger if exists product_order_units_set_updated_at
on public.product_order_units;
create trigger product_order_units_set_updated_at
  before update on public.product_order_units
  for each row execute procedure public.set_updated_at();

alter table public.product_order_units enable row level security;

drop policy if exists "authenticated users can read product order units"
on public.product_order_units;
create policy "authenticated users can read product order units"
on public.product_order_units for select to authenticated
using (
  is_active and exists (
    select 1 from public.products
    where products.id = product_order_units.product_id
      and products.is_active
  )
);

drop policy if exists "admins can manage product order units"
on public.product_order_units;
create policy "admins can manage product order units"
on public.product_order_units for all to authenticated
using (public.is_admin()) with check (public.is_admin());

grant select, insert, update, delete
on public.product_order_units to authenticated;
grant usage, select
on sequence public.product_order_units_id_seq to authenticated;

insert into public.product_order_units (
  product_id, unit_code, settlement_method, is_default, sort_order
)
select
  id,
  unit,
  'ordered_quantity',
  true,
  0
from public.products
on conflict (product_id, unit_code) do nothing;

alter table public.order_items
  add column if not exists pricing_unit text,
  add column if not exists settlement_method text not null default 'ordered_quantity';

update public.order_items
set pricing_unit = unit
where pricing_unit is null;

alter table public.order_items
  alter column pricing_unit set not null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'order_items_pricing_unit_check'
  ) then
    alter table public.order_items
      add constraint order_items_pricing_unit_check
      check (pricing_unit in ('kg', 'box', 'piece', 'pack'));
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'order_items_settlement_method_check'
  ) then
    alter table public.order_items
      add constraint order_items_settlement_method_check
      check (settlement_method in ('ordered_quantity', 'actual_weight'));
  end if;
end;
$$;
