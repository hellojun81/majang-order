create table if not exists public.product_price_history (
  id bigint generated always as identity primary key,
  product_id bigint not null references public.products(id) on delete cascade,
  old_price numeric(12, 2) not null,
  new_price numeric(12, 2) not null check (new_price > 0),
  pricing_unit text not null check (pricing_unit in ('kg', 'box', 'piece', 'pack')),
  change_note text not null default '',
  changed_by uuid not null references public.profiles(id),
  changed_at timestamptz not null default now()
);

create index if not exists product_price_history_product_changed_idx
on public.product_price_history (product_id, changed_at desc);

alter table public.product_price_history enable row level security;

drop policy if exists "admins can read product price history"
on public.product_price_history;
create policy "admins can read product price history"
on public.product_price_history for select to authenticated
using (public.is_admin());

drop policy if exists "admins can create product price history"
on public.product_price_history;
create policy "admins can create product price history"
on public.product_price_history for insert to authenticated
with check (public.is_admin() and changed_by = auth.uid());

grant select, insert on public.product_price_history to authenticated;
grant usage, select
on sequence public.product_price_history_id_seq to authenticated;

create or replace function public.change_product_price(
  p_product_id bigint,
  p_new_price numeric,
  p_note text default ''
)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_old_price numeric(12, 2);
  v_pricing_unit text;
begin
  if not public.is_admin() then
    raise exception '관리자만 단가를 변경할 수 있습니다.';
  end if;

  if p_new_price is null or p_new_price <= 0 then
    raise exception '단가는 0보다 커야 합니다.';
  end if;

  select unit_price, unit
  into v_old_price, v_pricing_unit
  from public.products
  where id = p_product_id
  for update;

  if not found then
    raise exception '상품을 찾을 수 없습니다.';
  end if;

  if v_old_price = p_new_price then
    return;
  end if;

  update public.products
  set unit_price = p_new_price
  where id = p_product_id;

  insert into public.product_price_history (
    product_id,
    old_price,
    new_price,
    pricing_unit,
    change_note,
    changed_by
  ) values (
    p_product_id,
    v_old_price,
    p_new_price,
    v_pricing_unit,
    coalesce(trim(p_note), ''),
    auth.uid()
  );
end;
$$;

grant execute on function public.change_product_price(bigint, numeric, text)
to authenticated;
