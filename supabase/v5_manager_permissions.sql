-- NOCTURNO V5.3 - ręczne nadanie uprawnień Manager
-- Uruchom w Supabase SQL Editor.
-- Ustawia role systemowe na 'manager' dla profili o podanych nazwach.
-- Dla Hope Weed zmienione zostaną wszystkie profile o tej nazwie,
-- ponieważ na screenie widoczne są trzy osobne konta o tej samej nazwie.

update public.profiles
set role = 'manager',
    active = true
where lower(trim(full_name)) in (
  'hope weed',
  'nolan tubs',
  'ricardo tubs',
  'enzo tubs'
);

select id, full_name, position, role, active
from public.profiles
where lower(trim(full_name)) in (
  'hope weed',
  'nolan tubs',
  'ricardo tubs',
  'enzo tubs'
)
order by lower(full_name), id;
