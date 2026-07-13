alter table public.products
  add column if not exists animal_type text not null default '기타',
  add column if not exists cut_name text not null default '';

alter table public.products
  add constraint products_animal_type_check
  check (animal_type in ('소', '돼지', '닭', '양', '기타'));

update public.products
set animal_type = case
  when name like '%한우%' or name like '%소%' or name like '%갈비살%' then '소'
  when name like '%한돈%' or name like '%돼지%' or name like '%삼겹%' then '돼지'
  when name like '%닭%' then '닭'
  else animal_type
end,
cut_name = case
  when name like '%등심%' then '등심'
  when name like '%국거리%' then '국거리'
  when name like '%삼겹%' then '삼겹살'
  when name like '%갈비%' then '갈비'
  else cut_name
end;
