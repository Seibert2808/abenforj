-- FIX urgente: reenvio do PDF corrigido por NAO-SOCIOS (aprovado com
-- ressalva) falhava com "new row violates row-level security policy".
--
-- Causa: a migration 2026-07-06-trabalhos-correcao-externos.sql recriou a
-- policy de UPDATE de storage.objects usando um subselect INLINE em
-- public.trabalhos_cientificos. Esse subselect roda sob a RLS do papel
-- `anon`, que NAO enxerga nenhuma linha de trabalhos_cientificos (so
-- admin/socia veem) -> o EXISTS da falso -> o WITH CHECK do upsert falha.
-- E exatamente o mesmo bug que 2026-06-19-fix-storage-externo-trabalhos.sql
-- ja tinha corrigido para o upload normal, reintroduzido sem querer.
--
-- Solucao: funcao SECURITY DEFINER (bypassa a RLS) que aceita o par
-- (externo + editavel), onde "editavel" agora inclui aprovado com ressalva,
-- para permitir o reupload do PDF corrigido no MESMO caminho.

create or replace function public.pdf_externo_corrigivel(p_name text)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.trabalhos_cientificos t
    where t.pdf_path = p_name
      and t.inscrito_externo_id is not null
      and (t.bloqueado = false or t.status = 'aceito_com_ressalva')
  );
$$;

grant execute on function public.pdf_externo_corrigivel(text) to anon, authenticated;

-- UPDATE (o upload do site usa upsert:true -> vira UPDATE quando o PDF ja existe)
drop policy if exists "Trabalhos PDF: update externo controlado" on storage.objects;
create policy "Trabalhos PDF: update externo controlado"
  on storage.objects for update
  to anon, authenticated
  using (
    bucket_id = 'trabalhos-cientificos'
    and (storage.foldername(name))[1] = 'externos'
    and public.pdf_externo_corrigivel(name)
  )
  with check (
    bucket_id = 'trabalhos-cientificos'
    and (storage.foldername(name))[1] = 'externos'
    and public.pdf_externo_corrigivel(name)
  );

-- SELECT (download): o relator aprovado-com-ressalva tambem precisa baixar
-- o PDF atual enquanto corrige. pdf_externo_valido exigia bloqueado=false,
-- entao o trabalho aprovado (bloqueado=true) ficava sem download. Usa o
-- superset "corrigivel", que cobre bloqueado=false OU aceito_com_ressalva.
drop policy if exists "Trabalhos PDF: leitura externo controlado" on storage.objects;
create policy "Trabalhos PDF: leitura externo controlado"
  on storage.objects for select
  to anon, authenticated
  using (
    bucket_id = 'trabalhos-cientificos'
    and (storage.foldername(name))[1] = 'externos'
    and public.pdf_externo_corrigivel(name)
  );

-- INSERT e DELETE ficam como estao (pdf_externo_valido, bloqueado=false):
-- nao-socio nao deve criar/excluir arquivo de trabalho ja aprovado.
