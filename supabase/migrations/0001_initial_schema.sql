create type public.user_role as enum ('retailer', 'admin');
create type public.order_status as enum (
  'pending', 'accepted', 'price_confirmation', 'customer_confirmation',
  'preparing', 'shipped', 'delivered', 'rejected', 'cancelled'
);

create table public.operation_settings (
  id boolean primary key default true check (id),
  require_store_approval boolean not null default true,
  confirm_actual_weight boolean not null default true,
  require_customer_confirmation boolean not null default false,
  use_store_specific_pricing boolean not null default false,
  allow_backorder boolean not null default false,
  updated_at timestamptz not null default now(),
  check (confirm_actual_weight or not require_customer_confirmation)
);

insert into public.operation_settings (id) values (true);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role public.user_role not null default 'retailer',
  store_name text not null,
  business_number text,
  is_approved boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.products (
  id bigint generated always as identity primary key,
  name text not null,
  origin text not null,
  grade text,
  storage_type text not null check (storage_type in ('chilled', 'frozen')),
  unit text not null check (unit in ('kg', 'pack', 'box')),
  unit_price numeric(12, 2) not null check (unit_price >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.orders (
  id bigint generated always as identity primary key,
  order_number text not null unique,
  retailer_id uuid not null references public.profiles(id),
  status public.order_status not null default 'pending',
  estimated_total numeric(12, 2) not null default 0,
  final_total numeric(12, 2),
  requested_delivery_date date,
  memo text,
  settings_snapshot jsonb not null,
  created_at timestamptz not null default now()
);

create table public.order_items (
  id bigint generated always as identity primary key,
  order_id bigint not null references public.orders(id) on delete cascade,
  product_id bigint not null references public.products(id),
  product_name text not null,
  ordered_quantity numeric(10, 2) not null check (ordered_quantity > 0),
  actual_quantity numeric(10, 2),
  unit text not null,
  unit_price numeric(12, 2) not null,
  final_amount numeric(12, 2),
  processing_request text
);

alter table public.profiles enable row level security;
alter table public.products enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.operation_settings enable row level security;

create policy "authenticated users can read active products"
on public.products for select to authenticated using (is_active);

create policy "retailers can read own orders"
on public.orders for select to authenticated using (retailer_id = auth.uid());

create policy "retailers can create own orders"
on public.orders for insert to authenticated with check (retailer_id = auth.uid());

create policy "retailers can read own order items"
on public.order_items for select to authenticated using (
  exists (select 1 from public.orders where orders.id = order_items.order_id and orders.retailer_id = auth.uid())
);

create policy "authenticated users can read operation settings"
on public.operation_settings for select to authenticated using (true);
