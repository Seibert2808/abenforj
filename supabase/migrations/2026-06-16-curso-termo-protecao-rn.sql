-- Adiciona o 7º curso pré-encontro do IX ENEON 2026:
-- "Termo-proteção do Recém-nascido", turno da tarde, Sala 606, 30 vagas.
--
-- Contexto: a tarde passou a ter 4 cursos. A Sala 716 (Manejo Clínico dos
-- Traumas Perineais) já existia no banco e foi restaurada nas páginas;
-- este curso novo entra na Sala 606. Idempotente.

do $$
declare
  v_evento_id uuid;
begin
  select id into v_evento_id from public.eventos where nome ilike '%IX ENEON%' limit 1;
  if v_evento_id is null then
    raise notice 'Evento IX ENEON não encontrado — nada inserido.';
    return;
  end if;

  insert into public.cursos (nome, descricao, evento_id, data, turno, local, vagas)
  select
    'Termo-proteção do Recém-nascido',
    'Estratégias de termorregulação e prevenção da hipotermia no cuidado ao recém-nascido.',
    v_evento_id,
    '2026-07-15'::date,
    'Tarde (13h às 17h)',
    'Sala 606 — FENF UERJ',
    30
  where not exists (
    select 1 from public.cursos c
    where c.evento_id = v_evento_id
      and c.nome ilike '%Termo-prote%Rec%nascido%'
  );

  -- Padroniza o nome do curso de reconstrução perineal para a versão longa,
  -- igual à usada em cursos.html / eventos.html (a renomeação de 2026-05-18
  -- não pegou no banco). Só atualiza se ainda estiver com o nome curto.
  update public.cursos
    set nome = 'Atualização em procedimentos de reconstrução perineal e segurança farmacológica',
        updated_at = now()
    where evento_id = v_evento_id
      and nome ilike '%Reconstru%perineal%'
      and nome not ilike 'Atualiza%';
end $$;
