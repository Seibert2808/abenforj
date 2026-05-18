-- Corrige nomes, locais e grafia dos cursos pré-encontro do IX ENEON 2026
-- conforme nomes oficiais em cursos.html (fonte de verdade).
-- Sabrina confirmou em 2026-05-18: Sala 716 (não 26), pavilhão "Nalva" (não "Neiva"),
-- e nomes longos dos cursos. Idempotente; preserva IDs e inscrições.
--
-- Usa ilike com substring única dos nomes antigos no WHERE — comparação exata
-- não bateu (caractere invisível/encoding no banco). chr(174)/chr(8211) são
-- usados pros caracteres ® e – respectivamente, que o SQL Editor do Supabase
-- não aceita como literais dentro de strings.

do $$
declare
  v_evento_id uuid;
  v_count int;
begin
  select id into v_evento_id from public.eventos where nome ilike '%IX ENEON%' limit 1;
  if v_evento_id is null then return; end if;

  -- 1) Manhã, Sala 716: Amamentação → Punção venosa neonatal (VeinViewer®)
  update public.cursos
    set nome = 'Punção venosa neonatal com realidade aumentada (VeinViewer' || chr(174) || ')',
        descricao = 'Aplicação da tecnologia VeinViewer' || chr(174) || ' como recurso de apoio à punção venosa em recém-nascidos.',
        local = 'Sala 716 — FENF UERJ',
        updated_at = now()
    where evento_id = v_evento_id and nome ilike '%Amamentação%Laserterapia%';
  get diagnostics v_count = row_count;
  raise notice 'Amamentação → Punção venosa: % linha(s)', v_count;

  -- 2) Manhã, Espaço Raquel Haddock Lobo: Hemorragia → HPP (nome longo)
  update public.cursos
    set nome = 'Manejo da HPP em cenários não hospitalares ' || chr(8211) || ' Estabilização e Transporte Seguro',
        descricao = 'Estabilização e transporte seguro em casos de hemorragia pós-parto fora do ambiente hospitalar.',
        local = 'Espaço Raquel Haddock Lobo — FENF UERJ',
        updated_at = now()
    where evento_id = v_evento_id and nome ilike '%Hemorragia%';
  get diagnostics v_count = row_count;
  raise notice 'Hemorragia → HPP: % linha(s)', v_count;

  -- 3) Manhã, Sala 23: Interpretação de Laudos — corrige grafia "Neiva" → "Nalva"
  update public.cursos
    set local = 'Sala 23 — Pav. Nalva Pereira Caldas — FENF UERJ',
        updated_at = now()
    where evento_id = v_evento_id and nome ilike '%Interpretação de Laudos%';
  get diagnostics v_count = row_count;
  raise notice 'Interpretação Laudos (só local): % linha(s)', v_count;

  -- 4) Tarde, Sala 716: Traumas Perineais → Proteção Térmica do RN
  update public.cursos
    set nome = 'Proteção Térmica do Recém-Nascido',
        descricao = 'Estratégias de termorregulação e prevenção da hipotermia no cuidado ao recém-nascido.',
        local = 'Sala 716 — FENF UERJ',
        updated_at = now()
    where evento_id = v_evento_id and nome ilike '%Traumas Perineais%';
  get diagnostics v_count = row_count;
  raise notice 'Traumas → Proteção Térmica: % linha(s)', v_count;

  -- 5) Tarde, Espaço Raquel Haddock Lobo: Reconstrução Perineal — nome longo
  update public.cursos
    set nome = 'Atualização em procedimentos de reconstrução perineal e segurança farmacológica',
        descricao = 'Atualização em procedimentos de reconstrução perineal, com foco em segurança farmacológica.',
        local = 'Espaço Raquel Haddock Lobo — FENF UERJ',
        updated_at = now()
    where evento_id = v_evento_id and nome ilike '%Reconstrução Perineal%';
  get diagnostics v_count = row_count;
  raise notice 'Reconstrução → Atualização: % linha(s)', v_count;

  -- 6) Tarde, Sala 23: Avaliação do RN — corrige sala (716 → 23) e grafia
  update public.cursos
    set local = 'Sala 23 — Pav. Nalva Pereira Caldas — FENF UERJ',
        updated_at = now()
    where evento_id = v_evento_id and nome ilike '%Avaliação do RN%';
  get diagnostics v_count = row_count;
  raise notice 'Avaliação RN (só local): % linha(s)', v_count;
end $$;
