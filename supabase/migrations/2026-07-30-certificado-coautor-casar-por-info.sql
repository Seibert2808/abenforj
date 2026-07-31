-- FIX: coautor(a) nunca conseguia baixar o próprio certificado de trabalho.
--
-- As RPCs de certificado casavam o coautor por  a->>'email'  , mas o formulário
-- de submissão (submeter-trabalho.html:638) grava a lista de autores como
--     { nome, info, eh_relator }
-- onde "info" é um campo LIVRE rotulado "E-mail / Instituição". Não existe
-- chave "email" nesses registros, então  a->>'email'  é sempre NULL e o ramo do
-- coautor jamais casava. Na prática só o relator (que submeteu, via profile_id),
-- o externo (via inscrito_externo_id) e o admin conseguiam o PDF — contrariando
-- o comentário de 2026-07-19-certificado-trabalho.sql, que promete que
-- "se algum coautor for sócio, ele também baixa o MESMO PDF completo na área".
--
-- Como "info" é texto livre ("fulana@x.com / UFRJ", "fulana@x.com/UNESA" e às
-- vezes só "UFRJ MACAÉ", sem e-mail), a comparação passa a ser por SUBSTRING.
-- Usa position() em vez de LIKE de propósito: e-mail pode conter "_", que o
-- LIKE trataria como curinga.
-- Mantém o a->>'email' para registros antigos que porventura usem essa chave.
--
-- Ressalva conhecida: casar por substring pode dar falso-positivo se um e-mail
-- for substring de outro (ex.: "ana@x.com" dentro de "mariana@x.com" não ocorre,
-- mas "x@y.com" dentro de "x@y.com.br" sim). Aceitável aqui — o PDF do trabalho
-- já é o mesmo documento que o relator distribui a todos os autores.
--
-- Rode no SQL editor do Supabase. Idempotente.

-- 1) RPC do SÓCIO
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
      or lower(coalesce(t.relator_email, '')) = lower(coalesce(p.email, ''))
         and coalesce(p.email, '') <> ''
      or exists (
        select 1 from jsonb_array_elements(coalesce(t.autores, '[]'::jsonb)) a
        where coalesce(p.email, '') <> ''
          and (
            lower(coalesce(a->>'email', '')) = lower(p.email)
            or position(lower(p.email) in lower(coalesce(a->>'info', ''))) > 0
          )
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
        or lower(coalesce(t.relator_email, '')) = lower(trim(coalesce(p_email, '')))
           and trim(coalesce(p_email, '')) <> ''
        or exists (
          select 1 from jsonb_array_elements(coalesce(t.autores, '[]'::jsonb)) a
          where trim(coalesce(p_email, '')) <> ''
            and (
              lower(coalesce(a->>'email', '')) = lower(trim(p_email))
              or position(lower(trim(p_email)) in lower(coalesce(a->>'info', ''))) > 0
            )
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
