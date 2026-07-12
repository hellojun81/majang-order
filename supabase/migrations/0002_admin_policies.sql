create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

create policy "admins can manage products"
on public.products for all to authenticated
using (public.is_admin()) with check (public.is_admin());

create policy "admins can manage orders"
on public.orders for all to authenticated
using (public.is_admin()) with check (public.is_admin());

create policy "admins can manage order items"
on public.order_items for all to authenticated
using (public.is_admin()) with check (public.is_admin());

create policy "admins can update operation settings"
on public.operation_settings for update to authenticated
using (public.is_admin()) with check (public.is_admin());

create policy "retailers can create own order items"
on public.order_items for insert to authenticated
with check (
  exists (
    select 1 from public.orders
    where orders.id = order_items.order_id
      and orders.retailer_id = auth.uid()
  )
);

create policy "users can read own profile"
on public.profiles for select to authenticated
using (id = auth.uid() or public.is_admin());

create policy "admins can update retailer profiles"
on public.profiles for update to authenticated
using (public.is_admin()) with check (public.is_admin());
