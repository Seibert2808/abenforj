-- ECOS DO ENEON 2026 — I Encontro Regional de Atencao ao Parto e Nascimento
-- do Norte Fluminense (04-05/12/2026, UFRJ Macae).
--
-- IMPORTANTE antes de rodar este script:
-- 1) Crie o evento pelo painel admin (admin.html -> aba Eventos -> Novo evento)
--    com o nome EXATO 'ECOS DO ENEON 2026' (as RPCs abaixo dependem desse nome
--    literal, no mesmo padrao usado para o IX ENEON 2026).
-- 2) So depois disso rode este script.
--
-- O que este script faz:
-- 1. Estende o enum (CHECK) de eixo_tematico em trabalhos_cientificos para
--    aceitar os 4 eixos do Ecos do Eneon, mantendo os 4 eixos do IX ENEON
--    (dados historicos existentes continuam validos).
-- 2. Substitui as RPCs publicas de trabalhos_aprovados_publico() e
--    inscritos_externos_publicos() para passarem a listar o ECOS DO ENEON
--    2026 (o IX ENEON fica arquivado em eneon-9.html com o PDF dos anais).
-- 3. Inscricao nativa via PIX: colunas novas em inscritos_externos, RPC
--    externo_inscrever_pix() e bucket de storage para o comprovante.

-- ------------------------------------------------------------
-- 1. Eixos tematicos do Ecos do Eneon
-- ------------------------------------------------------------
alter table public.trabalhos_cientificos
  drop constraint if exists trabalhos_cientificos_eixo_tematico_check;
alter table public.trabalhos_cientificos
  add constraint trabalhos_cientificos_eixo_tematico_check
  check (eixo_tematico in (
    -- IX ENEON 2026 (historico)
    'ensino_formacao_regulacao','cenario_politico','protagonismo_social','cuidado_qualificado',
    -- ECOS DO ENEON 2026
    'formacao_atuacao_inovacao','boas_praticas_qualidade','direitos_mulheres_equidade','politicas_publicas_gestao'
  ));

-- Opcao "Trabalho Concorrente a Premio" no ato da submissao (edital de
-- premiacao do Ecos do Eneon). Default false pra nao afetar dados historicos
-- do IX ENEON (sem premiacao).
alter table public.trabalhos_cientificos
  add column if not exists concorre_premio boolean not null default false;

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
    'submetido_em', t.submetido_em,
    'concorre_premio', t.concorre_premio,
    'correcao_enviada_em', t.correcao_enviada_em,
    'apresentacao_enviada_em', t.apresentacao_enviada_em
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
    cep_caae, ceua, referencias, descritores, autores, pdf_path, status, concorre_premio
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
    'submetido',
    coalesce((p_dados->>'concorre_premio')::boolean, false)
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
    autores       = coalesce(p_dados->'autores', autores),
    concorre_premio = coalesce((p_dados->>'concorre_premio')::boolean, concorre_premio)
  where id = p_trabalho_id;

  return json_build_object('ok', true);
end $$;

grant execute on function public.externo_atualizar_trabalho(text, text, uuid, jsonb) to anon, authenticated;

-- ------------------------------------------------------------
-- 2. RPCs publicas apontando para o ECOS DO ENEON 2026
-- ------------------------------------------------------------
create or replace function public.trabalhos_aprovados_publico()
returns table (titulo text)
language sql stable security definer set search_path = public as $$
  select t.titulo
  from public.trabalhos_cientificos t
  join public.eventos e on e.id = t.evento_id
  where e.nome = 'ECOS DO ENEON 2026'
    and t.status in ('aceito', 'aceito_com_ressalva')
  order by t.titulo
$$;

create or replace function public.inscritos_externos_publicos()
returns table (nome text)
language sql
security definer
set search_path = public
as $$
  select ie.nome
  from public.inscritos_externos ie
  join public.eventos e on e.id = ie.evento_id
  where e.nome = 'ECOS DO ENEON 2026'
    and ie.cancelado = false
    and coalesce(ie.pendente_verificacao_socia, false) = false
  order by lower(ie.nome);
$$;

-- ------------------------------------------------------------
-- 3. Inscricao nativa via PIX
-- ------------------------------------------------------------
alter table public.inscritos_externos
  add column if not exists categoria text check (categoria in ('socia','nao_socia')),
  add column if not exists comprovante_path text,
  add column if not exists pago_confirmado boolean not null default false,
  add column if not exists pago_confirmado_em timestamptz,
  add column if not exists pago_confirmado_por uuid references auth.users(id) on delete set null;

-- Cadastro + geracao do "numero de inscricao" (reaproveita a coluna doity_id
-- como codigo generico, assim submeter-trabalho.html funciona sem alteracao).
-- Reenviar o formulario com o mesmo e-mail ATUALIZA os dados e PEDE um novo
-- comprovante (pago_confirmado volta a false), mas preserva o codigo ja emitido.
create or replace function public.externo_inscrever_pix(
  p_evento_id uuid,
  p_nome text,
  p_email text,
  p_telefone text,
  p_categoria text,
  p_extensao text
) returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_codigo text;
  v_ext text;
  v_path text;
begin
  if p_categoria not in ('socia', 'nao_socia') then
    return json_build_object('ok', false, 'erro', 'Categoria invalida.');
  end if;
  v_ext := lower(coalesce(p_extensao, 'pdf'));
  if v_ext not in ('pdf', 'jpg', 'jpeg', 'png') then
    return json_build_object('ok', false, 'erro', 'Extensao de arquivo invalida.');
  end if;

  select id, doity_id into v_id, v_codigo
    from public.inscritos_externos
    where evento_id = p_evento_id and lower(email) = lower(trim(p_email));

  if v_id is null then
    v_codigo := 'ECOS' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 7));
    v_id := gen_random_uuid();
    v_path := 'inscricoes/' || v_id || '.' || v_ext;
    insert into public.inscritos_externos (
      id, evento_id, nome, email, telefone, doity_id, categoria,
      comprovante_path, pago_confirmado
    ) values (
      v_id, p_evento_id, trim(p_nome), lower(trim(p_email)), trim(p_telefone), v_codigo, p_categoria,
      v_path, false
    );
  else
    v_path := 'inscricoes/' || v_id || '.' || v_ext;
    update public.inscritos_externos set
      nome = trim(p_nome),
      telefone = trim(p_telefone),
      categoria = p_categoria,
      comprovante_path = v_path,
      pago_confirmado = false,
      pago_confirmado_em = null,
      pago_confirmado_por = null
    where id = v_id;
  end if;

  return json_build_object(
    'ok', true,
    'inscrito_id', v_id,
    'codigo', v_codigo,
    'comprovante_path', v_path
  );
exception when others then
  return json_build_object('ok', false, 'erro', sqlerrm);
end $$;

grant execute on function public.externo_inscrever_pix(uuid, text, text, text, text, text) to anon, authenticated;

-- Helper publico: id do evento, pelo nome fixo (pra pagina de inscricao nao
-- precisar conhecer o UUID com antecedencia). Mesmo padrao das RPCs acima.
create or replace function public.evento_ecos_eneon_id()
returns uuid
language sql stable security definer set search_path = public as $$
  select id from public.eventos where nome = 'ECOS DO ENEON 2026' limit 1;
$$;

grant execute on function public.evento_ecos_eneon_id() to anon, authenticated;

-- Bucket de storage para os comprovantes de PIX (privado, PDF ou imagem, ate 10MB)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'comprovantes-pix',
  'comprovantes-pix',
  false,
  10 * 1024 * 1024,
  array['application/pdf', 'image/jpeg', 'image/png']
) on conflict (id) do nothing;

-- Admin ve/gerencia tudo
drop policy if exists "Comprovantes PIX: admin tudo" on storage.objects;
create policy "Comprovantes PIX: admin tudo"
  on storage.objects for all
  using (bucket_id = 'comprovantes-pix' and public.is_admin())
  with check (bucket_id = 'comprovantes-pix' and public.is_admin());

-- Upload/atualizacao pelo proprio inscrito (anon), so no path ja alocado pela
-- RPC externo_inscrever_pix (mesmo padrao usado para o PDF de trabalhos).
create or replace function public.comprovante_pix_valido(p_name text)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.inscritos_externos ie
    where ie.comprovante_path = p_name
      and ie.pago_confirmado = false
  );
$$;

grant execute on function public.comprovante_pix_valido(text) to anon, authenticated;

drop policy if exists "Comprovantes PIX: upload externo controlado" on storage.objects;
create policy "Comprovantes PIX: upload externo controlado"
  on storage.objects for insert
  to anon, authenticated
  with check (
    bucket_id = 'comprovantes-pix'
    and (storage.foldername(name))[1] = 'inscricoes'
    and public.comprovante_pix_valido(name)
  );

drop policy if exists "Comprovantes PIX: update externo controlado" on storage.objects;
create policy "Comprovantes PIX: update externo controlado"
  on storage.objects for update
  to anon, authenticated
  using (
    bucket_id = 'comprovantes-pix'
    and (storage.foldername(name))[1] = 'inscricoes'
    and public.comprovante_pix_valido(name)
  )
  with check (
    bucket_id = 'comprovantes-pix'
    and (storage.foldername(name))[1] = 'inscricoes'
    and public.comprovante_pix_valido(name)
  );
