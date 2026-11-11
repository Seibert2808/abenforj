-- Acrescenta o 5o minicurso do ECOS DO ENEON 2026 (04/12, 09h-12h, UFRJ
-- Macae), que entrou na programacao depois da migracao anterior
-- (2026-11-10-ecos-do-eneon-minicursos.sql).

do $$
declare
  v_evento_id uuid;
begin
  select id into v_evento_id from public.eventos where nome = 'ECOS DO ENEON 2026' limit 1;
  if v_evento_id is null then
    raise notice 'Evento "ECOS DO ENEON 2026" ainda nao foi criado em Eventos -- minicurso nao cadastrado.';
    return;
  end if;

  insert into public.cursos (nome, descricao, evento_id, data, turno, local, vagas)
  select
    'Hemorragia Pós-Parto: Prevenção, reconhecimento precoce e manejo oportuno na prática da Enfermagem Obstétrica',
    'Enfa. Obstétrica Bárbara Jorge',
    v_evento_id, '2026-12-04'::date, 'Manhã (09h às 12h)', 'Sala 314B — UFRJ Macaé', 25
  where not exists (
    select 1 from public.cursos c
    where c.nome = 'Hemorragia Pós-Parto: Prevenção, reconhecimento precoce e manejo oportuno na prática da Enfermagem Obstétrica'
      and c.evento_id = v_evento_id
  );
end $$;
