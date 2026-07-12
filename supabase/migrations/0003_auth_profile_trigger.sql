create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, role, store_name, business_number, is_approved)
  values (
    new.id,
    'retailer',
    coalesce(nullif(new.raw_user_meta_data ->> 'store_name', ''), '신규 거래처'),
    nullif(new.raw_user_meta_data ->> 'business_number', ''),
    false
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

create policy "users can create own retailer profile"
on public.profiles for insert to authenticated
with check (id = auth.uid() and role = 'retailer');
