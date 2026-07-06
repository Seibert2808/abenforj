-- Correção do PDF para NÃO-SÓCIOS (relator via inscritos_externos),
-- espelho do fluxo dos sócios. Identificação por email + Doity.
-- Requer 2026-07-06-trabalhos-resultado.sql (status aceito_com_ressalva
-- e coluna correcao_enviada_em) já aplicada.

-- RPC: o externo carimba o reenvio do PDF corrigido, sem reeditar o texto.
-- Só vale para trabalho dele e com status 'aceito_com_ressalva'.
create or replace function public.externo_registrar_correcao(
  p_email text,
  p_doity_id text,
  p_trabalho_id uuid
) returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ins  record;
  v_trab record;
begin
  select * into v_ins from public._externo_lookup(p_email, p_doity_id);
  if v_ins is null then
    return json_build_object('ok', false, 'erro', 'Inscrição não encontrada.');
  end if;

  select id, status into v_trab
  from public.trabalhos_cientificos
  where id = p_trabalho_id and inscrito_externo_id = v_ins.id;

  if v_trab is null then
    return json_build_object('ok', false, 'erro', 'Trabalho não encontrado.');
  end if;
  if v_trab.status <> 'aceito_com_ressalva' then
    return json_build_object('ok', false, 'erro', 'Correção não permitida para este trabalho.');
  end if;

  update public.trabalhos_cientificos
     set correcao_enviada_em = now()
   where id = p_trabalho_id;

  return json_build_object('ok', true);
end $$;

grant execute on function public.externo_registrar_correcao(text, text, uuid) to anon, authenticated;

-- Storage: a policy de UPDATE do externo hoje exige bloqueado = false.
-- Passa a permitir também quando o trabalho está 'aceito_com_ressalva',
-- para que o PDF corrigido possa substituir o anterior (mesmo caminho).
drop policy if exists "Trabalhos PDF: update externo controlado" on storage.objects;
create policy "Trabalhos PDF: update externo controlado"
  on storage.objects for update
  to anon, authenticated
  using (
    bucket_id = 'trabalhos-cientificos'
    and (storage.foldername(name))[1] = 'externos'
    and exists (
      select 1 from public.trabalhos_cientificos t
      where t.pdf_path = name
        and t.inscrito_externo_id is not null
        and (t.bloqueado = false or t.status = 'aceito_com_ressalva')
    )
  )
  with check (
    bucket_id = 'trabalhos-cientificos'
    and (storage.foldername(name))[1] = 'externos'
    and exists (
      select 1 from public.trabalhos_cientificos t
      where t.pdf_path = name
        and t.inscrito_externo_id is not null
        and (t.bloqueado = false or t.status = 'aceito_com_ressalva')
    )
  );
