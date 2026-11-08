-- Corrige o nome literal do evento usado pelas RPCs publicas.
-- O evento foi criado no admin com o titulo completo
-- "ECOS DO IX ENEON - I Encontro Regional de Atencao ao Parto e Nascimento
-- do Norte Fluminense", nao com o nome curto "ECOS DO ENEON 2026" que a
-- migration 2026-11-08-ecos-do-eneon-evento.sql assumiu por engano.

create or replace function public.trabalhos_aprovados_publico()
returns table (titulo text)
language sql stable security definer set search_path = public as $$
  select t.titulo
  from public.trabalhos_cientificos t
  join public.eventos e on e.id = t.evento_id
  where e.nome = 'ECOS DO IX ENEON - I Encontro Regional de Atenção ao Parto e Nascimento do Norte Fluminense'
    and t.status in ('aceito', 'aceito_com_ressalva')
  order by t.titulo
$$;

create or replace function public.inscritos_externos_publicos()
returns table (nome text)
language sql
security definer
set search_path = public
as $$
  select ie.nome
  from public.inscritos_externos ie
  join public.eventos e on e.id = ie.evento_id
  where e.nome = 'ECOS DO IX ENEON - I Encontro Regional de Atenção ao Parto e Nascimento do Norte Fluminense'
    and ie.cancelado = false
    and coalesce(ie.pendente_verificacao_socia, false) = false
  order by lower(ie.nome);
$$;

create or replace function public.evento_ecos_eneon_id()
returns uuid
language sql stable security definer set search_path = public as $$
  select id from public.eventos where nome = 'ECOS DO IX ENEON - I Encontro Regional de Atenção ao Parto e Nascimento do Norte Fluminense' limit 1;
$$;
