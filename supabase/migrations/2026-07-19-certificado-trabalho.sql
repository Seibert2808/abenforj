-- Certificados de TRABALHO do IX ENEON: apresentação (relator) e coautoria (coautores).
-- Um PDF por trabalho, uma página por pessoa (relator/coautor). O relator baixa e
-- distribui; se algum coautor for sócio, ele também baixa o MESMO PDF completo na área.
-- Só trabalhos aceitos + apresentados, com o evento liberado.
-- Rode no SQL editor do Supabase. Idempotente.

-- 1) Tipos nos CHECKs do modelo
alter table public.certificado_modelos drop constraint if exists certificado_modelos_tipo_check;
alter table public.certificado_modelos add constraint certificado_modelos_tipo_check
  check (tipo in ('participacao','monitoria','oficina','palestrante','professor','comissao','apresentacao','coautoria'));

-- 2) Modelos (reaproveita arte/config do de participação). {{titulo}} = título do trabalho.
insert into public.certificado_modelos (evento_id, tipo, base_path, texto_pre, texto_template, config, ativo)
select e.id, x.tipo, base.base_path, 'Certificamos que', x.template,
  coalesce(base.config, '{"cor":"#4a5866","fonte":"Calibri, Arial, sans-serif","margem":380,"band_top":1000,"pre_size":56,"nome_size":130,"corpo_size":64}'::jsonb),
  true
from public.eventos e
left join lateral (select base_path, config from public.certificado_modelos where evento_id = e.id and tipo = 'participacao' limit 1) base on true
cross join (values
  ('apresentacao', 'apresentou o trabalho intitulado "{{titulo}}" no IX ENEON – IX Encontro de Enfermagem Obstétrica e Neonatal do Estado do Rio de Janeiro, realizado de 15 a 17 de julho de 2026, na UERJ.'),
  ('coautoria',    'é coautor(a) do trabalho intitulado "{{titulo}}", apresentado no IX ENEON – IX Encontro de Enfermagem Obstétrica e Neonatal do Estado do Rio de Janeiro, realizado de 15 a 17 de julho de 2026, na UERJ.')
) as x(tipo, template)
where e.nome = 'IX ENEON 2026'
on conflict (evento_id, tipo) do update
  set base_path = excluded.base_path, texto_pre = excluded.texto_pre,
      texto_template = excluded.texto_template, config = excluded.config, ativo = true;

-- 3) RPC do SÓCIO (relator OU coautor por e-mail da conta)
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
    and t.status = 'aceito'
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

-- 4) RPC do EXTERNO (por e-mail + número do Doity). Retorna também os modelos,
--    porque o anônimo não pode ler certificado_modelos diretamente.
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
      and t.status = 'aceito' and t.apresentado = true
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
