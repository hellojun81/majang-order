alter table public.products
  add column if not exists notes text not null default '',
  add column if not exists created_by uuid references public.profiles(id),
  add column if not exists updated_at timestamptz not null default now();

create table if not exists public.product_sub_items (
  id bigint generated always as identity primary key,
  product_id bigint not null references public.products(id) on delete cascade,
  name text not null,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (product_id, name)
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists products_set_updated_at on public.products;
create trigger products_set_updated_at
  before update on public.products
  for each row execute procedure public.set_updated_at();

drop trigger if exists product_sub_items_set_updated_at on public.product_sub_items;
create trigger product_sub_items_set_updated_at
  before update on public.product_sub_items
  for each row execute procedure public.set_updated_at();

alter table public.product_sub_items enable row level security;

drop policy if exists "authenticated users can read active product sub items"
on public.product_sub_items;
create policy "authenticated users can read active product sub items"
on public.product_sub_items for select to authenticated
using (
  is_active and exists (
    select 1 from public.products
    where products.id = product_sub_items.product_id
      and products.is_active
  )
);

drop policy if exists "admins can manage product sub items"
on public.product_sub_items;
create policy "admins can manage product sub items"
on public.product_sub_items for all to authenticated
using (public.is_admin()) with check (public.is_admin());

grant select, insert, update, delete on public.product_sub_items to authenticated;
grant usage, select on sequence public.product_sub_items_id_seq to authenticated;

update public.products
set notes = '', updated_at = coalesce(created_at, now())
where notes = '';
