-- Corrige nomes, locais e grafia dos cursos pré-encontro do IX ENEON 2026
-- conforme nomes oficiais em cursos.html (fonte de verdade).
-- Sabrina confirmou em 2026-05-18: Sala 716 (não 26), pavilhão "Nalva" (não "Neiva"),
-- e nomes longos dos cursos. Idempotente; preserva IDs e inscrições.

do $$
declare
  v_evento_id uuid;
begin
  select id into v_evento_id from public.eventos where nome = 'IX ENEON 2026' limit 1;
  if v_evento_id is null then return; end if;

  -- 1) Manhã, Sala 716: Amamentação → Punção venosa neonatal (VeinViewer®)
  -- chr(174) = ® (evita parser do SQL Editor quebrar com caractere literal)
  update public.cursos
    set nome = 'Punção venosa neonatal com realidade aumentada (VeinViewer' || chr(174) || ')',
        descricao = 'Aplicação da tecnologia VeinViewer' || chr(174) || ' como recurso de apoio à punção venosa em recém-nascidos.',
        local = 'Sala 716 — FENF UERJ',
        updated_at = now()
    where evento_id = v_evento_id
      and nome = 'Manejo Clínico da Amamentação associado à Laserterapia';

  -- 2) Manhã, Espaço Raquel Haddock Lobo: HPP — nome longo
  -- chr(8211) = – (en dash curto)
  update public.cursos
    set nome = 'Manejo da HPP em cenários não hospitalares ' || chr(8211) || ' Estabilização e Transporte Seguro',
        descricao = 'Estabilização e transporte seguro em casos de hemorragia pós-parto fora do ambiente hospitalar.',
        local = 'Espaço Raquel Haddock Lobo — FENF UERJ',
        updated_at = now()
    where evento_id = v_evento_id
      and nome = 'Manejo da Hemorragia Pós-Parto em cenários não hospitalares';

  -- 3) Manhã, Sala 23: Interpretação de Laudos — corrige grafia "Neiva" → "Nalva"
  update public.cursos
    set local = 'Sala 23 — Pav. Nalva Pereira Caldas — FENF UERJ',
        updated_at = now()
    where evento_id = v_evento_id
      and nome = 'Interpretação de Laudos Ultrassonográficos em Obstetrícia';

  -- 4) Tarde, Sala 716: Traumas Perineais → Proteção Térmica do RN
  update public.cursos
    set nome = 'Proteção Térmica do Recém-Nascido',
        descricao = 'Estratégias de termorregulação e prevenção da hipotermia no cuidado ao recém-nascido.',
        local = 'Sala 716 — FENF UERJ',
        updated_at = now()
    where evento_id = v_evento_id
      and nome = 'Manejo Clínico dos Traumas Perineais associado à Laserterapia';

  -- 5) Tarde, Espaço Raquel Haddock Lobo: Reconstrução Perineal — nome longo
  update public.cursos
    set nome = 'Atualização em procedimentos de reconstrução perineal e segurança farmacológica',
        descricao = 'Atualização em procedimentos de reconstrução perineal, com foco em segurança farmacológica.',
        local = 'Espaço Raquel Haddock Lobo — FENF UERJ',
        updated_at = now()
    where evento_id = v_evento_id
      and nome = 'Reconstrução Perineal e Segurança Farmacológica';

  -- 6) Tarde, Sala 23: Avaliação do RN — corrige sala (716 → 23) e grafia "Neiva" → "Nalva"
  update public.cursos
    set local = 'Sala 23 — Pav. Nalva Pereira Caldas — FENF UERJ',
        updated_at = now()
    where evento_id = v_evento_id
      and nome = 'Avaliação do RN em sala de parto e aplicação de Escalas para Exame Físico';
end $$;
