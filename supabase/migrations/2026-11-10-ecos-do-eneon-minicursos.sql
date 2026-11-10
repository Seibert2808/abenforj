-- Cadastra os 4 minicursos do ECOS DO ENEON 2026 (04/12, 09h-12h, UFRJ Macae),
-- mesmos dados ja publicados em programacao-ecos-eneon.html. Mesmo padrao
-- usado para os 6 cursos pre-encontro do IX ENEON 2026 (ver
-- 2026-05-15-cursos-tabela.sql) -- escolher-cursos.html e as RPCs
-- externo_meu_painel / externo_escolher_curso / cursos_com_vagas ja
-- funcionam por evento_id, sem precisar de nenhuma mudanca de codigo.

do $$
declare
  v_evento_id uuid;
begin
  select id into v_evento_id from public.eventos where nome = 'ECOS DO ENEON 2026' limit 1;
  if v_evento_id is null then
    raise notice 'Evento "ECOS DO ENEON 2026" ainda nao foi criado em Eventos -- minicursos nao cadastrados.';
    return;
  end if;

  insert into public.cursos (nome, descricao, evento_id, data, turno, local, vagas)
  select v.nome, v.descricao, v_evento_id, v.data, v.turno, v.local, v.vagas
  from (values
    ('Método Canguru: das evidências científicas à prática assistencial',
     'Profa. Dra. Marialda Christoffel · Doutoranda Glauciane Rego',
     '2026-12-04'::date, 'Manhã (09h às 12h)', 'Sala 209B — UFRJ Macaé', 25),
    ('Assistência de Enfermagem às Mulheres com Deficiência na Gestação, no Parto e no Puerpério',
     'Profa. Dra. Carla Oliveira Shubert',
     '2026-12-04'::date, 'Manhã (09h às 12h)', 'Sala 303B — UFRJ Macaé', 25),
    ('Princípios básicos e manejo da amamentação',
     'Profa. Dra. Carina Bulcão',
     '2026-12-04'::date, 'Manhã (09h às 12h)', 'Sala 307B — UFRJ Macaé', 25),
    ('Qualificação da assistência de enfermagem para manejo clínico da violência sexual no âmbito da APS',
     'Profa. Dra. Mariana Leonardo',
     '2026-12-04'::date, 'Manhã (09h às 12h)', 'Sala 308B — UFRJ Macaé', 25)
  ) as v(nome, descricao, data, turno, local, vagas)
  where not exists (
    select 1 from public.cursos c
    where c.nome = v.nome and c.evento_id = v_evento_id
  );
end $$;
