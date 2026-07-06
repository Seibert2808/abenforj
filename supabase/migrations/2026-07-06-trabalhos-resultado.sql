-- Resultado da avaliação dos trabalhos do IX ENEON 2026.
-- - Novo status "aceito_com_ressalva" (aprovado com ressalva).
-- - Campo correcao_enviada_em (carimbo do reenvio do PDF corrigido).
-- - Tabela interna (só admin) com o avaliador de cada trabalho.
-- - RPC público que devolve SÓ os títulos dos aprovados (sem vazar resumo,
--   e-mail, ressalva ou avaliador).
-- - RPC que o relator usa para registrar o envio da versão corrigida,
--   sem poder reeditar o texto do trabalho.
-- - Função de normalização de título (para casar a planilha na importação).

-- ------------------------------------------------------------
-- 1. Novo valor de status
-- ------------------------------------------------------------
alter table public.trabalhos_cientificos
  drop constraint if exists trabalhos_cientificos_status_check;
alter table public.trabalhos_cientificos
  add constraint trabalhos_cientificos_status_check
  check (status in ('submetido','em_avaliacao','aceito','aceito_com_ressalva','recusado'));

-- ------------------------------------------------------------
-- 2. Carimbo da correção
-- ------------------------------------------------------------
alter table public.trabalhos_cientificos
  add column if not exists correcao_enviada_em timestamptz;

-- ------------------------------------------------------------
-- 3. Normalização de título (lower + sem acentos + espaços colapsados)
--    Usada para casar os títulos da planilha com os do banco.
-- ------------------------------------------------------------
create or replace function public.f_norm_titulo(t text)
returns text language sql immutable as $$
  select trim(regexp_replace(
           translate(
             lower(coalesce(t, '')),
             'áàâãäéèêëíìîïóòôõöúùûüç',
             'aaaaaeeeeiiiiooooouuuuc'
           ),
           '\s+', ' ', 'g'))
$$;

-- ------------------------------------------------------------
-- 4. Tabela interna do avaliador (SOMENTE admin)
-- ------------------------------------------------------------
create table if not exists public.trabalhos_avaliacao (
  id            uuid        primary key default gen_random_uuid(),
  trabalho_id   uuid        not null unique
                              references public.trabalhos_cientificos(id) on delete cascade,
  avaliador_nome text,
  parecer        text,
  criado_em      timestamptz not null default now()
);

alter table public.trabalhos_avaliacao enable row level security;

-- Sem policy para anon/authenticated => RLS nega tudo a eles.
-- Só o admin (que também usa service_role no editor) enxerga.
drop policy if exists "Avaliacao interna: admin tudo" on public.trabalhos_avaliacao;
create policy "Avaliacao interna: admin tudo"
  on public.trabalhos_avaliacao for all
  using (public.is_admin())
  with check (public.is_admin());

-- ------------------------------------------------------------
-- 5. RPC público: só os títulos dos trabalhos aprovados
--    (security definer -> ignora o RLS, mas devolve APENAS o título)
-- ------------------------------------------------------------
create or replace function public.trabalhos_aprovados_publico()
returns table (titulo text)
language sql stable security definer set search_path = public as $$
  select t.titulo
  from public.trabalhos_cientificos t
  join public.eventos e on e.id = t.evento_id
  where e.nome = 'IX ENEON 2026'
    and t.status in ('aceito', 'aceito_com_ressalva')
  order by t.titulo
$$;

grant execute on function public.trabalhos_aprovados_publico() to anon, authenticated;

-- ------------------------------------------------------------
-- 6. RPC de correção: o relator só carimba o reenvio do PDF corrigido.
--    Não permite reeditar o texto; só vale para "aceito_com_ressalva"
--    e para o dono do trabalho.
-- ------------------------------------------------------------
create or replace function public.registrar_correcao_trabalho(p_trabalho_id uuid)
returns timestamptz
language plpgsql security definer set search_path = public as $$
declare
  v_ts timestamptz;
begin
  update public.trabalhos_cientificos
     set correcao_enviada_em = now()
   where id = p_trabalho_id
     and profile_id = auth.uid()
     and status = 'aceito_com_ressalva'
  returning correcao_enviada_em into v_ts;

  if v_ts is null then
    raise exception 'Correção não permitida para este trabalho.';
  end if;
  return v_ts;
end $$;

grant execute on function public.registrar_correcao_trabalho(uuid) to authenticated;
