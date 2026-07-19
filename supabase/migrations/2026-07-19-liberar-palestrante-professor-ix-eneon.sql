-- Liberação dos certificados de PALESTRANTE e PROFESSOR do IX ENEON 2026 — 19/07/2026
-- 1) nomes com qualificação (Profª Drª, Enfª Ma. ...) — vale no PDF e na área da sócia;
-- 2) desativa temporariamente participação e monitoria (não liberar ainda — falta registrar presença);
-- 3) liga o interruptor geral do evento.
-- Idempotente. Rode no SQL editor do Supabase.

-- ── 1a. Nomes com título — PALESTRANTES ────────────────────────────────────
update public.certificado_papeis cp
set nome = v.novo
from (values
  ('Ana Letícia Gomes','Profª Drª Ana Letícia Gomes'),
  ('Angela Mitrano Perazzini de Sá','Enfª Ma. Angela Mitrano Perazzini de Sá'),
  ('Anna Christina de Almeida Porréca','Profª Ma. Anna Christina de Almeida Porréca'),
  ('Claudia Maria Messias','Profª Drª Claudia Maria Messias'),
  ('Heloisa Lessa','Enfª Profª Drª Heloisa Lessa'),
  ('Isabelle Mangueira de Paula Gaspar','Enfª Ma. Isabelle Mangueira de Paula Gaspar'),
  ('José Felipe Riani Costa','Prof. Dr. José Felipe Riani Costa'),
  ('Marcele Sampaio de Freitas Guimarães Ribeiro','Profª Drª Marcele Sampaio de Freitas Guimarães Ribeiro'),
  ('Mariana Moreira Tangari','Exmª Srª Juíza Mariana Moreira Tangari'),
  ('Marilanda Lopes de Lima','Profª Drª Marilanda Lopes de Lima'),
  ('Midian Oliveira Dias','Profª Drª Midian Oliveira Dias'),
  ('Renata Alves de Lima Nunes Barbosa','Enfª Ma. Renata Alves de Lima Nunes Barbosa'),
  ('Rubem Figueiredo Sadok Menna Barreto','Prof. Dr. Rubem Figueiredo Sadok Menna Barreto'),
  ('Simone Pereira dos Santos','Enfª Ma. Simone Pereira dos Santos')
) as v(antigo, novo)
where cp.tipo = 'palestrante'
  and cp.nome = v.antigo
  and cp.evento_id = (select id from public.eventos where nome = 'IX ENEON 2026');

-- ── 1b. Nomes com título — PROFESSORES ─────────────────────────────────────
update public.certificado_papeis cp
set nome = v.novo
from (values
  ('Ana Cláudia Monteiro','Profª Drª Ana Cláudia Monteiro'),
  ('Anna Christina de Almeida Porréca','Profª Ma. Anna Christina de Almeida Porréca'),
  ('Reginaldo Lemos Soares','Prof. Me. Reginaldo Lemos Soares'),
  ('Ana Luiza Zapponi','Profª Drª Ana Luiza Zapponi'),
  ('José Antônio de Sá Neto','Prof. Dr. José Antônio de Sá Neto'),
  ('Michele de Lima Janotti Quaresma','Profª Ma. Michele de Lima Janotti Quaresma')
) as v(antigo, novo)
where cp.tipo = 'professor'
  and cp.nome = v.antigo
  and cp.evento_id = (select id from public.eventos where nome = 'IX ENEON 2026');

-- ── 2. Não liberar participação e monitoria ainda ──────────────────────────
update public.certificado_modelos m
set ativo = false
where m.tipo in ('participacao','monitoria')
  and m.evento_id = (select id from public.eventos where nome = 'IX ENEON 2026');

-- ── 3. Ligar o interruptor geral (libera palestrante + professor) ──────────
update public.eventos set certificados_liberados = true where nome = 'IX ENEON 2026';

-- ── 4. Verificação ─────────────────────────────────────────────────────────
select cp.tipo, cp.nome, cp.detalhe,
  case when cp.profile_id is null then '❌ e-mail (sem conta)' else '✅ área da sócia' end as entrega
from public.certificado_papeis cp
where cp.evento_id = (select id from public.eventos where nome = 'IX ENEON 2026')
order by cp.tipo, cp.nome;
