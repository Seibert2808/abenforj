-- Presença e certificado por CURSO pré-encontro — IX ENEON 2026 (21/07/2026)
--
-- Fecha o item do roadmap (playbook §11): hoje o curso tem inscrição e
-- credenciamento em papel, mas não havia presença digital nem certificado de
-- participante de curso. Só quem esteve PRESENTE no curso recebe o certificado.
--
-- O que esta migração faz:
--   1) presença por curso  → coluna inscricoes_curso.presente (+ presenca_em);
--   2) carga horária       → coluna cursos.carga_horaria (padrão "4 horas");
--   3) modelo `oficina`    → reaproveita a arte/config da declaração de participação,
--                            texto cita o {{curso}} e a {{carga_horaria}};
--   4) RPC pública         → externo baixa o certificado do curso por nº do Doity
--                            (mesmo padrão de declaracao_participacao_por_doity).
-- Idempotente. Rode no SQL editor do Supabase.

-- ── 1. Presença por curso ──────────────────────────────────────────────────
alter table public.inscricoes_curso
  add column if not exists presente    boolean     not null default false,
  add column if not exists presenca_em timestamptz;

create index if not exists inscricoes_curso_presente_idx
  on public.inscricoes_curso (curso_id) where presente;

-- ── 2. Carga horária do curso (vai impressa no certificado) ────────────────
alter table public.cursos
  add column if not exists carga_horaria text not null default '4 horas';

-- Todos os cursos pré-encontro do IX ENEON são de meio período = 4 horas.
update public.cursos
  set carga_horaria = '4 horas'
  where (carga_horaria is null or carga_horaria = '')
    and evento_id = (select id from public.eventos where nome = 'IX ENEON 2026' limit 1);

-- ── 3. Modelo `oficina` (reaproveita arte+config da declaração) ────────────
insert into public.certificado_modelos (evento_id, tipo, base_path, texto_pre, texto_template, config, ativo)
select e.id, 'oficina', base.base_path, 'Certificamos que',
  'participou do Curso Pré-Encontro «{{curso}}», com carga horária de {{carga_horaria}}, ' ||
  'realizado em 15 de julho de 2026, no âmbito do IX ENEON – IX Encontro de Enfermagem ' ||
  'Obstétrica e Neonatal do Estado do Rio de Janeiro, na UERJ.',
  coalesce(base.config,
    '{"cor":"#4a5866","fonte":"Calibri, Arial, sans-serif","margem":380,"band_top":1000,"pre_size":56,"nome_size":130,"corpo_size":64}'::jsonb)
    || '{"carga_horaria":"4 horas"}'::jsonb,
  true
from public.eventos e
left join lateral (
  select base_path, config from public.certificado_modelos
  where evento_id = e.id and tipo = 'participacao' limit 1
) base on true
where e.nome = 'IX ENEON 2026'
on conflict (evento_id, tipo) do update
  set base_path = excluded.base_path, texto_pre = excluded.texto_pre,
      texto_template = excluded.texto_template, config = excluded.config, ativo = true;

-- ── 4. RPC pública: certificado(s) de curso do EXTERNO por nº do Doity ─────
-- Retorna UMA linha por curso em que o inscrito externo esteve PRESENTE.
-- (Uma pessoa pode ter cursos de manhã e de tarde → mais de um certificado.)
-- Só devolve quando: é inscrito externo do IX ENEON, não cancelado, com presença
-- no curso, evento com certificados liberados e modelo `oficina` ativo.
create or replace function public.certificados_curso_por_doity(p_doity text)
returns table (
  curso          text,
  carga_horaria  text,
  nome           text,
  texto_pre      text,
  texto_template text,
  base_path      text,
  config         jsonb
)
language sql
security definer
set search_path = public
as $$
  select c.nome as curso,
         coalesce(nullif(c.carga_horaria, ''), m.config->>'carga_horaria', '4 horas') as carga_horaria,
         ie.nome, m.texto_pre, m.texto_template, m.base_path, m.config
  from public.inscritos_externos ie
  join public.eventos e  on e.id  = ie.evento_id
  join public.inscricoes_curso ic on ic.inscrito_externo_id = ie.id and ic.presente = true
  join public.cursos c on c.id = ic.curso_id
  join public.certificado_modelos m on m.evento_id = e.id and m.tipo = 'oficina' and m.ativo = true
  where e.nome = 'IX ENEON 2026'
    and e.certificados_liberados = true
    and ie.cancelado = false
    and length(regexp_replace(coalesce(p_doity, ''),     '[^A-Za-z0-9]', '', 'g')) >= 4
    and length(regexp_replace(coalesce(ie.doity_id, ''), '[^A-Za-z0-9]', '', 'g')) >= 4
    and upper(regexp_replace(coalesce(ie.doity_id, ''), '[^A-Za-z0-9]', '', 'g'))
      = upper(regexp_replace(coalesce(p_doity, ''),     '[^A-Za-z0-9]', '', 'g'))
  order by c.turno, c.nome;
$$;

grant execute on function public.certificados_curso_por_doity(text) to anon, authenticated;

-- ── 5. Conferência ─────────────────────────────────────────────────────────
select c.nome as curso, c.turno, c.carga_horaria,
  (select count(*) from public.inscricoes_curso ic where ic.curso_id = c.id) as inscritos,
  (select count(*) from public.inscricoes_curso ic where ic.curso_id = c.id and ic.presente) as presentes
from public.cursos c
where c.evento_id = (select id from public.eventos where nome = 'IX ENEON 2026')
order by c.turno, c.nome;
