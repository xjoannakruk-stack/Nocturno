-- NOCTURNO V5 - NAPRAWA LOGOWANIA / RLS
-- V4 miała rekurencyjne polityki RLS na public.profiles.

create or replace function public.is_nocturno_manager()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role='manager' and p.active=true
  );
$$;
revoke all on function public.is_nocturno_manager() from public;
grant execute on function public.is_nocturno_manager() to authenticated;

alter table public.profiles enable row level security;
drop policy if exists "profiles_manager_select" on public.profiles;
drop policy if exists "profiles_manager_update" on public.profiles;
drop policy if exists "profiles_select_own" on public.profiles;
drop policy if exists "profiles_select_own_or_manager" on public.profiles;
drop policy if exists "profiles_manager_update_safe" on public.profiles;
create policy "profiles_select_own_or_manager" on public.profiles for select to authenticated
using (id=auth.uid() or public.is_nocturno_manager());
create policy "profiles_manager_update_safe" on public.profiles for update to authenticated
using (public.is_nocturno_manager()) with check (public.is_nocturno_manager());

drop policy if exists "work_sessions_manager_update" on public.work_sessions;
drop policy if exists "work_sessions_manager_update_safe" on public.work_sessions;
create policy "work_sessions_manager_update_safe" on public.work_sessions for update to authenticated
using (public.is_nocturno_manager()) with check (public.is_nocturno_manager());

drop policy if exists "audit_manager_select" on public.audit_log;
drop policy if exists "audit_manager_select_safe" on public.audit_log;
create policy "audit_manager_select_safe" on public.audit_log for select to authenticated using (public.is_nocturno_manager());
drop policy if exists "audit_manager_insert" on public.audit_log;
drop policy if exists "audit_manager_insert_safe" on public.audit_log;
create policy "audit_manager_insert_safe" on public.audit_log for insert to authenticated
with check (actor_id=auth.uid() and public.is_nocturno_manager());

drop policy if exists "receipts_manager_select" on public.receipts;
drop policy if exists "receipts_manager_select_safe" on public.receipts;
create policy "receipts_manager_select_safe" on public.receipts for select to authenticated using (public.is_nocturno_manager());

drop policy if exists "receipts_storage_insert" on storage.objects;
drop policy if exists "receipts_storage_insert_safe" on storage.objects;
create policy "receipts_storage_insert_safe" on storage.objects for insert to authenticated
with check (bucket_id='receipts' and ((storage.foldername(name))[1]=auth.uid()::text or public.is_nocturno_manager()));
drop policy if exists "receipts_storage_select" on storage.objects;
drop policy if exists "receipts_storage_select_safe" on storage.objects;
create policy "receipts_storage_select_safe" on storage.objects for select to authenticated
using (bucket_id='receipts' and ((storage.foldername(name))[1]=auth.uid()::text or public.is_nocturno_manager()));

drop policy if exists "job_applications_manager_select" on public.job_applications;
drop policy if exists "job_applications_manager_select_safe" on public.job_applications;
create policy "job_applications_manager_select_safe" on public.job_applications for select to authenticated using (public.is_nocturno_manager());
drop policy if exists "job_applications_manager_update" on public.job_applications;
drop policy if exists "job_applications_manager_update_safe" on public.job_applications;
create policy "job_applications_manager_update_safe" on public.job_applications for update to authenticated
using (public.is_nocturno_manager()) with check (public.is_nocturno_manager());
drop policy if exists "cv_storage_manager_select" on storage.objects;
drop policy if exists "cv_storage_manager_select_safe" on storage.objects;
create policy "cv_storage_manager_select_safe" on storage.objects for select to authenticated
using (bucket_id='cv-applications' and public.is_nocturno_manager());

drop policy if exists "shift_logs_manager_select" on public.shift_logs;
drop policy if exists "shift_logs_manager_select_safe" on public.shift_logs;
create policy "shift_logs_manager_select_safe" on public.shift_logs for select to authenticated using (public.is_nocturno_manager());
drop policy if exists "shift_logs_manager_insert" on public.shift_logs;
drop policy if exists "shift_logs_manager_insert_safe" on public.shift_logs;
create policy "shift_logs_manager_insert_safe" on public.shift_logs for insert to authenticated
with check (author_id=auth.uid() and public.is_nocturno_manager());

-- Napraw / ustaw konto właściciela.
do $$
declare target_id uuid;
begin
  select id into target_id from auth.users where lower(email)=lower('xjoanna.kruk@gmail.com') limit 1;
  if target_id is null then raise exception 'Nie znaleziono xjoanna.kruk@gmail.com w auth.users'; end if;
  insert into public.profiles(id, full_name, position, role, active)
  values(target_id,'Joanna Kruk','Szef','manager',true)
  on conflict(id) do update set
    full_name=coalesce(nullif(public.profiles.full_name,''), excluded.full_name),
    position='Szef', role='manager', active=true;
end $$;

select u.id,u.email,p.full_name,p.position,p.role,p.active
from auth.users u left join public.profiles p on p.id=u.id
where lower(u.email)=lower('xjoanna.kruk@gmail.com');
