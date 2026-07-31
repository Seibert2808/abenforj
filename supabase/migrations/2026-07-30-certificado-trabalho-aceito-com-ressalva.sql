-- FIX: certificados de trabalho não saíam para status 'aceito_com_ressalva'.
--
-- As duas RPCs de 2026-07-19-certificado-trabalho.sql filtravam com igualdade
-- estrita (t.status = 'aceito'), então trabalhos APROVADOS COM RESSALVA ficavam
-- sem certificado de apresentação/coautoria mesmo estando apresentado = true.
-- O resto do sistema já usa in ('aceito','aceito_com_ressalva')
-- (ver 2026-07-08-apresentacoes-envio.sql, 2026-07-06-trabalhos-resultado.sql,
-- area/trabalhos.html:506, submeter-trabalho.html:578) — aqui ficou de fora.
--
-- Detectado em 30/07/2026 a partir do caso do trabalho "LACTAÇÃO INDUZIDA EM
-- MULHERES TRANS", aceito_com_ressalva + apresentado, cuja relatora recebeu o
-- certificado do outro trabalho dela (esse sim 'aceito') mas não deste.
--
-- Rode no SQL editor do Supabase. Idempotente. Só troca o filtro de status.

-- 1) RPC do SÓCIO (relator OU coautor por e-mail da conta)
create or replace function public.certificados_trabalho_socio()
returns table (evento_id uuid, titulo text, relator_nome text, relator_email text, autores jsonb)
language sql
security definer
set search_path = public
as $$
  select t.evento_id, t.titulo, t.relator_nome, t.relator_email, t.autores
  from public.trabalhos_cientificos t
  join public.eventos e on e.id = t.evento_id
  join public.profiles p on p.id = auth.uid()
  where e.nome = 'IX ENEON 2026'
    and e.certificados_liberados = true
    and t.status in ('aceito', 'aceito_com_ressalva')
    and t.apresentado = true
    and (
      t.profile_id = auth.uid()
      or exists (
        select 1 from jsonb_array_elements(coalesce(t.autores, '[]'::jsonb)) a
        where lower(a->>'email') = lower(coalesce(p.email, ''))
          and coalesce(p.email, '') <> ''
      )
    );
$$;
grant execute on function public.certificados_trabalho_socio() to authenticated;

-- 2) RPC do EXTERNO (por e-mail + número do Doity)
create or replace function public.certificados_trabalho_por_doity(p_email text, p_doity text)
returns jsonb
language sql
security definer
set search_path = public
as $$
  with ev as (
    select id from public.eventos where nome = 'IX ENEON 2026' and certificados_liberados = true
  ),
  ins as (
    select ie.id, ie.email
    from public.inscritos_externos ie
    where ie.evento_id = (select id from ev)
      and ie.cancelado = false
      and lower(ie.email) = lower(trim(coalesce(p_email, '')))
      and length(regexp_replace(coalesce(p_doity, ''),     '[^A-Za-z0-9]', '', 'g')) >= 4
      and upper(regexp_replace(coalesce(ie.doity_id, ''), '[^A-Za-z0-9]', '', 'g'))
        = upper(regexp_replace(coalesce(p_doity, ''),     '[^A-Za-z0-9]', '', 'g'))
    limit 1
  ),
  mods as (
    select
      max(m.texto_pre) as texto_pre,
      (array_agg(m.config))[1] as config,
      jsonb_object_agg(m.tipo, jsonb_build_object('texto_template', m.texto_template, 'base_path', m.base_path)) as modelos
    from public.certificado_modelos m
    where m.evento_id = (select id from ev) and m.tipo in ('apresentacao','coautoria') and m.ativo = true
  ),
  trabs as (
    select coalesce(jsonb_agg(jsonb_build_object(
      'titulo', t.titulo, 'relator_nome', t.relator_nome, 'relator_email', t.relator_email, 'autores', t.autores
    )), '[]'::jsonb) as arr
    from public.trabalhos_cientificos t
    where t.evento_id = (select id from ev)
      and t.status in ('aceito', 'aceito_com_ressalva')
      and t.apresentado = true
      and (
        t.inscrito_externo_id = (select id from ins)
        or exists (
          select 1 from jsonb_array_elements(coalesce(t.autores, '[]'::jsonb)) a
          where lower(a->>'email') = lower(trim(coalesce(p_email, ''))) and trim(coalesce(p_email,'')) <> ''
        )
      )
  )
  select case when (select id from ins) is null then null
    else jsonb_build_object(
      'texto_pre', (select texto_pre from mods),
      'config',    (select config from mods),
      'modelos',   (select modelos from mods),
      'trabalhos', (select arr from trabs)
    ) end;
$$;
grant execute on function public.certificados_trabalho_por_doity(text, text) to anon, authenticated;
