-- Lista pública (somente nomes) dos não-sócios com inscrição no IX ENEON 2026
-- confirmada e regularizada — para exibir na página do evento (eventos.html).
--
-- "Confirmada e regularizada" =
--   cancelado = false                  (a inscrição não foi cancelada)
--   pendente_verificacao_socia = false (sem pendência de cota de sócia a regularizar)
--
-- A função expõe APENAS o nome (sem e-mail, telefone ou número Doity), via
-- SECURITY DEFINER, já que a tabela inscritos_externos tem RLS restrita a admin.

create or replace function public.inscritos_externos_publicos()
returns table (nome text)
language sql
security definer
set search_path = public
as $$
  select ie.nome
  from public.inscritos_externos ie
  join public.eventos e on e.id = ie.evento_id
  where e.nome = 'IX ENEON 2026'
    and ie.cancelado = false
    and ie.pendente_verificacao_socia = false
  order by lower(ie.nome);
$$;

grant execute on function public.inscritos_externos_publicos() to anon, authenticated;

-- Inscrições no IX ENEON encerradas: remove o link externo (Doity) do evento.
-- Com link_externo nulo, o convite na área da associada (area/cursos.html) passa
-- a mostrar "Saiba mais →" (eventos.html) em vez de "Inscreva-se no Doity".
update public.eventos
  set link_externo = null,
      updated_at = now()
  where nome = 'IX ENEON 2026';
