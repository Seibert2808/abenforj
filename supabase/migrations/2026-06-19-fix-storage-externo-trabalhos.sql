-- FIX urgente: upload de PDF de trabalhos por NAO-SOCIOS falhava com
-- "new row violates row-level security policy".
--
-- Causa: as policies de storage.objects para a pasta 'externos' (criadas em
-- 2026-05-27-trabalhos-rpcs-externos.sql) faziam um subselect inline em
-- public.trabalhos_cientificos. Esse subselect roda sob a RLS do papel `anon`,
-- que NAO enxerga nenhuma linha de trabalhos_cientificos (so admin/socia veem).
-- Logo o EXISTS dava falso e o WITH CHECK do upload falhava.
-- (Confirmado em 2026-06-19: anon SELECT na linha retorna [].)
--
-- Solucao: encapsular a verificacao numa funcao SECURITY DEFINER (que bypassa
-- a RLS) e usa-la nas policies. Acrescenta tambem policy de leitura (download)
-- para que o nao-socio consiga baixar o proprio PDF.

create or replace function public.pdf_externo_valido(p_name text)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.trabalhos_cientificos t
    where t.pdf_path = p_name
      and t.inscrito_externo_id is not null
      and t.bloqueado = false
  );
$$;

grant execute on function public.pdf_externo_valido(text) to anon, authenticated;

-- INSERT (upload novo)
drop policy if exists "Trabalhos PDF: upload externo controlado" on storage.objects;
create policy "Trabalhos PDF: upload externo controlado"
  on storage.objects for insert
  to anon, authenticated
  with check (
    bucket_id = 'trabalhos-cientificos'
    and (storage.foldername(name))[1] = 'externos'
    and public.pdf_externo_valido(name)
  );

-- UPDATE (o upload do site usa upsert:true)
drop policy if exists "Trabalhos PDF: update externo controlado" on storage.objects;
create policy "Trabalhos PDF: update externo controlado"
  on storage.objects for update
  to anon, authenticated
  using (
    bucket_id = 'trabalhos-cientificos'
    and (storage.foldername(name))[1] = 'externos'
    and public.pdf_externo_valido(name)
  )
  with check (
    bucket_id = 'trabalhos-cientificos'
    and (storage.foldername(name))[1] = 'externos'
    and public.pdf_externo_valido(name)
  );

-- DELETE (trocar/remover trabalho)
drop policy if exists "Trabalhos PDF: delete externo controlado" on storage.objects;
create policy "Trabalhos PDF: delete externo controlado"
  on storage.objects for delete
  to anon, authenticated
  using (
    bucket_id = 'trabalhos-cientificos'
    and (storage.foldername(name))[1] = 'externos'
    and public.pdf_externo_valido(name)
  );

-- SELECT (download): nao-socio baixa o proprio PDF. Path e UUID (nao enumeravel).
drop policy if exists "Trabalhos PDF: leitura externo controlado" on storage.objects;
create policy "Trabalhos PDF: leitura externo controlado"
  on storage.objects for select
  to anon, authenticated
  using (
    bucket_id = 'trabalhos-cientificos'
    and (storage.foldername(name))[1] = 'externos'
    and public.pdf_externo_valido(name)
  );
