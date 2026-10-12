-- NEXUS WORK: cadastro de potenciais parceiros e identificação do cliente
alter table public.service_requests add column if not exists client_name text;

create table if not exists public.partners (
 id uuid primary key default gen_random_uuid(),
 organization_name text not null,
 contact_name text not null,
 entity_type text not null,
 activity_area text not null,
 headquarters_province text not null,
 headquarters_district text not null,
 headquarters_address text not null,
 phone text not null,
 email text,
 website text,
 operational_areas text,
 services_offered text not null,
 partnership_need text not null,
 additional_notes text,
 status text not null default 'PENDING',
 reviewed_by uuid references auth.users(id),
 reviewed_at timestamptz,
 review_note text,
 created_at timestamptz not null default now()
);

alter table public.partners enable row level security;

drop policy if exists partners_insert on public.partners;
create policy partners_insert
 on public.partners for insert to anon, authenticated
 with check (status = 'PENDING');

drop policy if exists partners_read on public.partners;
create policy partners_read
 on public.partners for select to authenticated
 using (public.is_admin());

grant usage on schema public to anon, authenticated;
grant insert on public.partners to anon, authenticated;
grant select on public.partners to authenticated;

create or replace function public.set_record_status(
 p_table text, p_id uuid, p_status text, p_note text default null
) returns boolean
language plpgsql
security definer
set search_path = public
as $function$
begin
 if not public.is_admin() then
   raise exception 'Acesso administrativo necessário.';
 end if;

 if lower(p_status) not in ('approved', 'rejected') then
   raise exception 'Estado de aprovação inválido.';
 end if;

 if p_table = 'service_requests' then
   update public.service_requests
   set status = lower(p_status), reviewed_by = auth.uid(),
       reviewed_at = now(), review_note = p_note
   where id = p_id;
 elsif p_table = 'workers' then
   update public.workers
   set status = upper(p_status), reviewed_by = auth.uid(),
       reviewed_at = now(), review_note = p_note
   where id = p_id;
 elsif p_table = 'jobs' then
   update public.jobs
   set status = upper(p_status), reviewed_by = auth.uid(),
       reviewed_at = now(), review_note = p_note
   where id = p_id;
 elsif p_table = 'partners' then
   update public.partners
   set status = upper(p_status), reviewed_by = auth.uid(),
       reviewed_at = now(), review_note = p_note
   where id = p_id;
 else
   raise exception 'Tabela inválida.';
 end if;

 return found;
end;
$function$;

revoke all on function public.set_record_status(text, uuid, text, text) from public, anon;
grant execute on function public.set_record_status(text, uuid, text, text) to authenticated;
