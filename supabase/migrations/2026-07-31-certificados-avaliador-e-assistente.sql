-- Dois tipos NOVOS de certificado no IX ENEON 2026:
--   • AVALIADOR de trabalhos científicos
--   • ASSISTENTE de curso pré-encontro
--
-- Motivo: nenhum dos dois existia — os CHECKs de certificado_modelos /
-- certificado_papeis só aceitavam participacao, monitoria, oficina,
-- palestrante, professor, comissao, apresentacao, coautoria. Quem avaliou
-- trabalho ou ajudou num curso não tinha como receber nada.
--
-- Pedidos da Sabrina em 31/07/2026:
--   • José Antônio de Sá Neto — avaliador de trabalhos (ele só tinha recebido
--     o de professor; participação e coautoria estão na migração
--     2026-07-31-jose-antonio-participacao-e-coautoria.sql);
--   • Adriane Porto Santos — residente do Programa de Residência em Enfermagem
--     Neonatal da FENF/UERJ, assistente no curso "Termoproteção do
--     Recém-nascido", ministrado pelo Prof. José Antônio de Sá Neto.
--
-- Os dois tipos usam a mesma engrenagem dos papéis curados: o certificado
-- aparece na área da sócia quando o papel está vinculado a uma conta
-- (profile_id) e o modelo está ativo. Sem conta vinculada, sai por fora
-- (PDF/e-mail).
--
-- Rode no SQL editor do Supabase. Idempotente.
-- Depende do código novo (area/cursos.html + area/admin.html) estar publicado
-- para os certificados aparecerem na área da sócia.

-- ── 1. os dois tipos nos CHECKs ────────────────────────────────────────────
alter table public.certificado_modelos
  drop constraint if exists certificado_modelos_tipo_check;
alter table public.certificado_modelos
  add constraint certificado_modelos_tipo_check
  check (tipo in ('participacao','monitoria','oficina','palestrante','professor',
                  'comissao','avaliador','assistente','apresentacao','coautoria'));

alter table public.certificado_papeis
  drop constraint if exists certificado_papeis_tipo_check;
alter table public.certificado_papeis
  add constraint certificado_papeis_tipo_check
  check (tipo in ('palestrante','professor','comissao','avaliador','assistente'));

-- ── 2. modelos (mesma arte/config da declaração de participação) ───────────
-- Textos neutros de gênero de propósito: o mesmo modelo serve homens e mulheres.
-- 'assistente' usa {{curso}}, que a área preenche com o detalhe do papel.
insert into public.certificado_modelos (evento_id, tipo, base_path, texto_pre, texto_template, config, ativo)
select e.id, t.tipo, base.base_path, 'Certificamos que', t.template,
       coalesce(base.config, '{"fonte":"Calibri, Arial, sans-serif","cor":"#4a5866","margem":380,"pre_size":56,"nome_size":132,"corpo_size":62,"band_top":1020}'::jsonb),
       true
from public.eventos e
left join lateral (
  select base_path, config from public.certificado_modelos
  where evento_id = e.id and tipo = 'participacao' limit 1
) base on true
cross join (values
  ('avaliador', 'atuou na avaliação dos trabalhos científicos submetidos ao IX ENEON – IX Encontro de Enfermagem Obstétrica e Neonatal do Estado do Rio de Janeiro, realizado de 15 a 17 de julho de 2026, na UERJ.'),
  ('assistente', 'atuou como assistente no curso pré-encontro "{{curso}}" do IX ENEON – IX Encontro de Enfermagem Obstétrica e Neonatal do Estado do Rio de Janeiro, realizado em 15 de julho de 2026, na UERJ, com carga horária de 4 horas.')
) as t(tipo, template)
where e.nome = 'IX ENEON 2026'
  and not exists (
    select 1 from public.certificado_modelos m
    where m.evento_id = e.id and m.tipo = t.tipo
  );

-- ── 3. papéis ──────────────────────────────────────────────────────────────
-- avaliador: detalhe nulo (o texto não usa placeholder).
-- assistente: detalhe = nome do curso, escrito igual ao papel de professor do
--             mesmo curso (vai no {{curso}} do texto).
insert into public.certificado_papeis (evento_id, tipo, nome, detalhe)
select e.id, v.tipo, v.nome, v.detalhe
from public.eventos e
cross join (values
  ('avaliador',  'José Antônio de Sá Neto', null),
  ('assistente', 'Adriane Porto Santos',    'Termoproteção do Recém-nascido')
) as v(tipo, nome, detalhe)
where e.nome = 'IX ENEON 2026'
  and not exists (
    select 1 from public.certificado_papeis cp
    where cp.evento_id = e.id and cp.tipo = v.tipo
      and public.f_norm_titulo(cp.nome) = public.f_norm_titulo(v.nome)
  );

-- ── 4. vincular profile_id por nome normalizado (só os ainda sem vínculo) ───
update public.certificado_papeis cp
set profile_id = p.id
from public.profiles p
where cp.profile_id is null
  and cp.tipo in ('avaliador','assistente')
  and cp.evento_id = (select id from public.eventos where nome = 'IX ENEON 2026')
  and public.f_norm_titulo(cp.nome) = public.f_norm_titulo(p.nome_completo);

-- ── 5. verificação — quem tem os papéis novos e se está vinculado ──────────
-- "sem conta vinculada" NÃO é erro: significa que a pessoa não tem conta de
-- sócia (ou o nome do cadastro está escrito diferente). Nesse caso o
-- certificado sai por fora, ou vincule pelo admin (aba Certificados → papéis).
select cp.tipo, cp.nome, coalesce(cp.detalhe, '—') as detalhe,
  case when cp.profile_id is null then '❌ sem conta vinculada — certificado sai por e-mail'
       else '✅ vinculado: ' || coalesce(p.email, '(conta)') end as vinculo
from public.certificado_papeis cp
left join public.profiles p on p.id = cp.profile_id
where cp.evento_id = (select id from public.eventos where nome = 'IX ENEON 2026')
  and cp.tipo in ('avaliador','assistente')
order by cp.tipo, cp.nome;

-- ── 5b. os DEMAIS avaliadores registrados (só informativo) ─────────────────
-- Fonte: trabalhos_avaliacao.avaliador_nome (tabela interna do admin).
select ta.avaliador_nome,
       count(*) as trabalhos_avaliados,
       case when exists (
         select 1 from public.certificado_papeis cp
         where cp.evento_id = t.evento_id and cp.tipo = 'avaliador'
           and public.f_norm_titulo(cp.nome) = public.f_norm_titulo(ta.avaliador_nome)
       ) then '✅ já tem papel' else '— sem papel de avaliador' end as situacao
from public.trabalhos_avaliacao ta
join public.trabalhos_cientificos t on t.id = ta.trabalho_id
where t.evento_id = (select id from public.eventos where nome = 'IX ENEON 2026')
  and coalesce(trim(ta.avaliador_nome), '') <> ''
group by ta.avaliador_nome, t.evento_id
order by 2 desc, 1;

-- ── 6. OPCIONAL — estender o certificado a TODOS os avaliadores ────────────
-- Só rode DEPOIS de conferir a lista do 5b (o campo avaliador_nome é texto
-- livre: pode ter nome torto, dois nomes na mesma célula, etc.).
-- Descomente e rode:
--
-- insert into public.certificado_papeis (evento_id, tipo, nome, detalhe)
-- select distinct t.evento_id, 'avaliador', trim(ta.avaliador_nome), null
-- from public.trabalhos_avaliacao ta
-- join public.trabalhos_cientificos t on t.id = ta.trabalho_id
-- where t.evento_id = (select id from public.eventos where nome = 'IX ENEON 2026')
--   and coalesce(trim(ta.avaliador_nome), '') <> ''
--   and not exists (
--     select 1 from public.certificado_papeis cp
--     where cp.evento_id = t.evento_id and cp.tipo = 'avaliador'
--       and public.f_norm_titulo(cp.nome) = public.f_norm_titulo(ta.avaliador_nome)
--   );
--
-- update public.certificado_papeis cp
-- set profile_id = p.id
-- from public.profiles p
-- where cp.profile_id is null
--   and cp.tipo = 'avaliador'
--   and cp.evento_id = (select id from public.eventos where nome = 'IX ENEON 2026')
--   and public.f_norm_titulo(cp.nome) = public.f_norm_titulo(p.nome_completo);
