-- RPCs SECURITY DEFINER que permitem nao-socias (inscritos_externos)
-- gerenciar seus trabalhos cientificos via email + numero Doity, sem auth.
-- Padrao identico ao usado pelos cursos pre-encontro
-- (externo_meu_painel, externo_escolher_curso, etc.).

-- Helper interno: localiza o inscrito_externo pelo par (email, doity_id)
create or replace function public._externo_lookup(p_email text, p_doity_id text)
returns table (id uuid, evento_id uuid, nome text, email text)
language sql
security definer
set search_path = public
as $$
  select id, evento_id, nome, email
  from public.inscritos_externos
  where lower(email) = lower(trim(p_email))
    and doity_id = upper(trim(p_doity_id))
  limit 1;
$$;

-- Painel de um inscrito externo: dados + trabalhos ja submetidos
create or replace function public.externo_meus_trabalhos(p_email text, p_doity_id text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ins record;
  v_trabs json;
begin
  select * into v_ins from public._externo_lookup(p_email, p_doity_id);
  if v_ins is null then
    return json_build_object('ok', false, 'erro', 'Inscricao nao encontrada. Confira email e numero Doity (formato DOI-XXXXXXXXX).');
  end if;

  select json_agg(json_build_object(
    'id', t.id,
    'titulo', t.titulo,
    'area', t.area,
    'eixo_tematico', t.eixo_tematico,
    'tipo_trabalho', t.tipo_trabalho,
    'resumo', t.resumo,
    'cep_caae', t.cep_caae,
    'ceua', t.ceua,
    'referencias', t.referencias,
    'descritores', t.descritores,
    'autores', t.autores,
    'pdf_path', t.pdf_path,
    'status', t.status,
    'bloqueado', t.bloqueado,
    'observacao_avaliacao', t.observacao_avaliacao,
    'submetido_em', t.submetido_em
  ) order by t.submetido_em desc)
  into v_trabs
  from public.trabalhos_cientificos t
  where t.inscrito_externo_id = v_ins.id;

  return json_build_object(
    'ok', true,
    'inscrito', json_build_object(
      'id', v_ins.id,
      'evento_id', v_ins.evento_id,
      'nome', v_ins.nome,
      'email', v_ins.email
    ),
    'trabalhos', coalesce(v_trabs, '[]'::json)
  );
end $$;

grant execute on function public.externo_meus_trabalhos(text, text) to anon, authenticated;

-- Cria novo trabalho (sem PDF ainda) — devolve o id pra usar no upload.
-- Aplica limite de 2 trabalhos por relator.
create or replace function public.externo_submeter_trabalho(
  p_email text,
  p_doity_id text,
  p_dados jsonb
) returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ins record;
  v_count int;
  v_trabalho_id uuid;
  v_pdf_path text;
begin
  select * into v_ins from public._externo_lookup(p_email, p_doity_id);
  if v_ins is null then
    return json_build_object('ok', false, 'erro', 'Inscricao nao encontrada.');
  end if;

  -- Limite de 2 trabalhos
  select count(*) into v_count
  from public.trabalhos_cientificos
  where inscrito_externo_id = v_ins.id;
  if v_count >= 2 then
    return json_build_object('ok', false, 'erro', 'Voce ja submeteu o limite de 2 trabalhos como relator(a) principal.');
  end if;

  v_trabalho_id := gen_random_uuid();
  v_pdf_path := 'externos/' || v_trabalho_id || '.pdf';

  insert into public.trabalhos_cientificos (
    id, evento_id, inscrito_externo_id, relator_nome, relator_email,
    titulo, area, eixo_tematico, tipo_trabalho, resumo,
    cep_caae, ceua, referencias, descritores, autores, pdf_path, status
  ) values (
    v_trabalho_id,
    v_ins.evento_id,
    v_ins.id,
    v_ins.nome,
    v_ins.email,
    p_dados->>'titulo',
    p_dados->>'area',
    p_dados->>'eixo_tematico',
    p_dados->>'tipo_trabalho',
    p_dados->>'resumo',
    p_dados->>'cep_caae',
    p_dados->>'ceua',
    p_dados->>'referencias',
    array(select jsonb_array_elements_text(p_dados->'descritores')),
    coalesce(p_dados->'autores', '[]'::jsonb),
    v_pdf_path,
    'submetido'
  );

  return json_build_object(
    'ok', true,
    'id', v_trabalho_id,
    'pdf_path', v_pdf_path
  );
exception when others then
  return json_build_object('ok', false, 'erro', sqlerrm);
end $$;

grant execute on function public.externo_submeter_trabalho(text, text, jsonb) to anon, authenticated;

-- Atualiza trabalho (so se nao bloqueado e pertence ao inscrito)
create or replace function public.externo_atualizar_trabalho(
  p_email text,
  p_doity_id text,
  p_trabalho_id uuid,
  p_dados jsonb
) returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ins record;
  v_trab record;
begin
  select * into v_ins from public._externo_lookup(p_email, p_doity_id);
  if v_ins is null then
    return json_build_object('ok', false, 'erro', 'Inscricao nao encontrada.');
  end if;

  select id, bloqueado into v_trab
  from public.trabalhos_cientificos
  where id = p_trabalho_id and inscrito_externo_id = v_ins.id;

  if v_trab is null then
    return json_build_object('ok', false, 'erro', 'Trabalho nao encontrado.');
  end if;
  if v_trab.bloqueado then
    return json_build_object('ok', false, 'erro', 'Trabalho ja em avaliacao — nao pode mais ser editado.');
  end if;

  update public.trabalhos_cientificos set
    titulo        = coalesce(p_dados->>'titulo', titulo),
    area          = coalesce(p_dados->>'area', area),
    eixo_tematico = coalesce(p_dados->>'eixo_tematico', eixo_tematico),
    tipo_trabalho = coalesce(p_dados->>'tipo_trabalho', tipo_trabalho),
    resumo        = coalesce(p_dados->>'resumo', resumo),
    cep_caae      = p_dados->>'cep_caae',
    ceua          = p_dados->>'ceua',
    referencias   = coalesce(p_dados->>'referencias', referencias),
    descritores   = coalesce(
      array(select jsonb_array_elements_text(p_dados->'descritores')),
      descritores
    ),
    autores       = coalesce(p_dados->'autores', autores)
  where id = p_trabalho_id;

  return json_build_object('ok', true);
end $$;

grant execute on function public.externo_atualizar_trabalho(text, text, uuid, jsonb) to anon, authenticated;

-- Deleta trabalho (so se nao bloqueado e pertence ao inscrito)
create or replace function public.externo_deletar_trabalho(
  p_email text,
  p_doity_id text,
  p_trabalho_id uuid
) returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ins record;
  v_trab record;
begin
  select * into v_ins from public._externo_lookup(p_email, p_doity_id);
  if v_ins is null then
    return json_build_object('ok', false, 'erro', 'Inscricao nao encontrada.');
  end if;

  select id, bloqueado, pdf_path into v_trab
  from public.trabalhos_cientificos
  where id = p_trabalho_id and inscrito_externo_id = v_ins.id;

  if v_trab is null then
    return json_build_object('ok', false, 'erro', 'Trabalho nao encontrado.');
  end if;
  if v_trab.bloqueado then
    return json_build_object('ok', false, 'erro', 'Trabalho ja em avaliacao — nao pode mais ser removido.');
  end if;

  delete from public.trabalhos_cientificos where id = p_trabalho_id;

  return json_build_object('ok', true, 'pdf_path', v_trab.pdf_path);
end $$;

grant execute on function public.externo_deletar_trabalho(text, text, uuid) to anon, authenticated;

-- Storage policy: permite que anon faca upload no path 'externos/<uuid>.pdf'
-- mas APENAS se ja existe um registro em trabalhos_cientificos com aquele
-- pdf_path (criado pela RPC externo_submeter_trabalho).
-- Isso previne uploads orfaos sem autenticacao do par email+doity.
drop policy if exists "Trabalhos PDF: upload externo controlado" on storage.objects;
create policy "Trabalhos PDF: upload externo controlado"
  on storage.objects for insert
  to anon, authenticated
  with check (
    bucket_id = 'trabalhos-cientificos'
    and (storage.foldername(name))[1] = 'externos'
    and exists (
      select 1 from public.trabalhos_cientificos t
      where t.pdf_path = name
        and t.inscrito_externo_id is not null
        and t.bloqueado = false
    )
  );

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
        and t.bloqueado = false
    )
  )
  with check (
    bucket_id = 'trabalhos-cientificos'
    and (storage.foldername(name))[1] = 'externos'
    and exists (
      select 1 from public.trabalhos_cientificos t
      where t.pdf_path = name
        and t.inscrito_externo_id is not null
        and t.bloqueado = false
    )
  );

drop policy if exists "Trabalhos PDF: delete externo controlado" on storage.objects;
create policy "Trabalhos PDF: delete externo controlado"
  on storage.objects for delete
  to anon, authenticated
  using (
    bucket_id = 'trabalhos-cientificos'
    and (storage.foldername(name))[1] = 'externos'
    and exists (
      select 1 from public.trabalhos_cientificos t
      where t.pdf_path = name
        and t.inscrito_externo_id is not null
        and t.bloqueado = false
    )
  );
