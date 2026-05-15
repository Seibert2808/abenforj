-- Renomeia os cursos pre-encontro do IX ENEON conforme nomes oficiais
-- enviados pela Sabrina em 2026-05-15. Preserva IDs e inscricoes.

do $$
declare
  v_evento_id uuid;
begin
  select id into v_evento_id from public.eventos where nome = 'IX ENEON 2026' limit 1;
  if v_evento_id is null then return; end if;

  -- Manha, Sala 716
  update public.cursos
    set nome = 'Punção venosa neonatal com realidade aumentada (VeinViewer®)',
        descricao = 'Aplicação da tecnologia VeinViewer® como recurso de apoio à punção venosa em recém-nascidos.',
        updated_at = now()
    where evento_id = v_evento_id
      and nome = 'Manejo Clínico da Amamentação associado à Laserterapia';

  -- Manha, Espaco Raquel Haddock Lobo
  update public.cursos
    set nome = 'Manejo da HPP em cenários não hospitalares – Estabilização e Transporte Seguro',
        updated_at = now()
    where evento_id = v_evento_id
      and nome = 'Manejo da Hemorragia Pós-Parto em cenários não hospitalares';

  -- Manha, Sala 23 — nome ja correto, sem mudanca

  -- Tarde, Sala 716
  update public.cursos
    set nome = 'Termoproteção do Recém-Nascido',
        descricao = 'Estratégias de termorregulação e prevenção da hipotermia no cuidado ao recém-nascido.',
        updated_at = now()
    where evento_id = v_evento_id
      and nome = 'Manejo Clínico dos Traumas Perineais associado à Laserterapia';

  -- Tarde, Espaco Raquel Haddock Lobo
  update public.cursos
    set nome = 'Atualização em procedimentos de reconstrução perineal e segurança farmacológica',
        updated_at = now()
    where evento_id = v_evento_id
      and nome = 'Reconstrução Perineal e Segurança Farmacológica';

  -- Tarde, Sala 23
  update public.cursos
    set nome = 'Avaliação do RN em sala de parto e aplicação de Escalas para Exame Físico',
        descricao = 'Avaliação clínica do recém-nascido em sala de parto e aplicação de escalas para o exame físico.',
        updated_at = now()
    where evento_id = v_evento_id
      and nome = 'Avaliação do Recém-Nascido em Sala de Parto';
end $$;
