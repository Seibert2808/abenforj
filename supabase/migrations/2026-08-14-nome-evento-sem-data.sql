-- Tira a data de dentro do NOME do evento.
--
-- Problema (14/08/2026): no seletor do painel a 4ª Reunião do Fórum aparecia
-- como "4ª Reunião do Fórum Permanente de Enfermagem Obstétrica 2026
-- (20/08/2026) (20/08/2026)". A segunda data é o seletor, que acrescenta
-- data_inicio formatada; a primeira estava gravada no próprio eventos.nome.
--
-- O nome guarda só o nome. A data quem mostra é a tela, a partir de
-- data_inicio, que é o campo que ordena a lista.
--
-- Rode no SQL editor. Idempotente: só mexe em quem termina com "(dd/mm/aaaa)".

-- ── 1. antes ───────────────────────────────────────────────────────────────
select id, nome, data_inicio
from public.eventos
where nome ~ '\(\d{2}/\d{2}/\d{4}\)\s*$'
order by data_inicio desc;

-- ── 2. limpar ──────────────────────────────────────────────────────────────
update public.eventos
set nome = btrim(regexp_replace(nome, '\s*\(\d{2}/\d{2}/\d{4}\)\s*$', ''))
where nome ~ '\(\d{2}/\d{2}/\d{4}\)\s*$';

-- ── 3. depois: confere que ninguém ficou com data no nome ─────────────────
-- A primeira consulta tem que voltar VAZIA.
select id, nome from public.eventos where nome ~ '\(\d{2}/\d{2}/\d{4}\)\s*$';

select nome, data_inicio from public.eventos order by data_inicio desc;
