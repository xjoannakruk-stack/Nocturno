-- NOCTURNO V4 — NAPRAWA KONTA LOGOWANIA
-- Uruchom w Supabase -> SQL Editor.
-- W PIERWSZYM kroku wpisz w manager_email adres e-mail konta, którym próbujesz się zalogować.
-- Ten skrypt nie zmienia hasła. Naprawia brakujący wpis w public.profiles.

DO $$
DECLARE
  manager_email text := 'WPISZ_TUTAJ_EMAIL_KONTA';
  manager_id uuid;
  manager_name text;
BEGIN
  IF manager_email = 'WPISZ_TUTAJ_EMAIL_KONTA' THEN
    RAISE EXCEPTION 'Uzupełnij manager_email w skrypcie przed uruchomieniem.';
  END IF;

  SELECT id, COALESCE(raw_user_meta_data->>'full_name', email)
    INTO manager_id, manager_name
  FROM auth.users
  WHERE lower(email) = lower(manager_email)
  ORDER BY created_at ASC
  LIMIT 1;

  IF manager_id IS NULL THEN
    RAISE EXCEPTION 'Nie znaleziono użytkownika Auth o adresie: %', manager_email;
  END IF;

  INSERT INTO public.profiles (id, full_name, position, role, active)
  VALUES (manager_id, COALESCE(manager_name, 'Administrator'), 'Szef', 'manager', true)
  ON CONFLICT (id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    position = 'Szef',
    role = 'manager',
    active = true;
END $$;

-- Kontrola po naprawie:
SELECT
  u.id,
  u.email,
  p.full_name,
  p.position,
  p.role,
  p.active
FROM auth.users u
LEFT JOIN public.profiles p ON p.id = u.id
WHERE lower(u.email) = lower('WPISZ_TUTAJ_EMAIL_KONTA');

-- Opcjonalnie: pokaż wszystkie konta Auth i informację, czy mają profil.
-- Odkomentuj, jeśli chcesz sprawdzić całą listę:
-- SELECT u.id, u.email, p.role, p.active
-- FROM auth.users u
-- LEFT JOIN public.profiles p ON p.id = u.id
-- ORDER BY u.created_at;
