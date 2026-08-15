-- Uniformiza o nome das reuniões do Fórum.
--
-- Situação em 14/08/2026: a 4ª reunião está cadastrada como "Fórum Permanente
-- de Enfermagem Obstétrica" e a 1ª, a 2ª e a 3ª como "Fórum de Enfermagem
-- Obstétrica". O nome oficial é o com "Permanente" (é o que está no link de
-- inscrição do Doity), então as três antigas é que estavam abreviadas.
--
-- Depois desta, os quatro ficam assim:
--   Nª Reunião do Fórum Permanente de Enfermagem Obstétrica 2026
--
-- Só mexe no nome, nada mais depende dele: as migrações de certificado casam
-- por 'IX ENEON 2026', e os textos do site são escritos à mão em
-- eventos-passados.html.
--
-- Rode no SQL editor. Idempotente.

-- ── 1. antes ───────────────────────────────────────────────────────────────
select id, nome, data_inicio from public.eventos
where nome ilike '%Fórum%' order by data_inicio;

-- ── 2. uniformizar ─────────────────────────────────────────────────────────
update public.eventos
set nome = replace(nome, 'Fórum de Enfermagem Obstétrica', 'Fórum Permanente de Enfermagem Obstétrica')
where nome like '%Fórum de Enfermagem Obstétrica%';

-- ── 3. depois ──────────────────────────────────────────────────────────────
-- Os quatro têm que aparecer com "Fórum Permanente".
select nome, data_inicio from public.eventos
where nome ilike '%Fórum%' order by data_inicio;
