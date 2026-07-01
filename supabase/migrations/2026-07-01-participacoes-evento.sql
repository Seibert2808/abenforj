-- Registro de PARTICIPAÇÃO/PRESENÇA em eventos (ex.: Fórum de Enfermagem Obstétrica).
-- A sócia registra a PRÓPRIA presença na área logada; o admin só remove enganos.
-- A janela de registro é controlada por evento: interruptor permite_presenca +
-- horário opcional de fechamento (presenca_fecha_em). Assim dá pra abrir o registro
-- por 24h mesmo depois do dia do evento.

alter table public.eventos
  add column if not exists permite_presenca  boolean     not null default false,
  add column if not exists presenca_fecha_em timestamptz;

create table if not exists public.participacoes_evento (
  id            uuid        primary key default gen_random_uuid(),
  profile_id    uuid        not null references public.profiles(id) on delete cascade,
  evento_id     uuid        not null references public.eventos(id) on delete cascade,
  registrado_em timestamptz not null default now(),
  unique (profile_id, evento_id)
);

create index if not exists participacoes_evento_evento_idx  on public.participacoes_evento (evento_id);
create index if not exists participacoes_evento_profile_idx on public.participacoes_evento (profile_id);

alter table public.participacoes_evento enable row level security;

-- A sócia registra a PRÓPRIA presença, e só enquanto a janela do evento está aberta.
drop policy if exists "Presenca: associada registra a sua" on public.participacoes_evento;
create policy "Presenca: associada registra a sua"
  on public.participacoes_evento for insert
  with check (
    profile_id = auth.uid()
    and exists (
      select 1 from public.eventos e
      where e.id = evento_id
        and e.permite_presenca
        and (e.presenca_fecha_em is null or now() <= e.presenca_fecha_em)
    )
  );

-- A sócia vê (e pode remover) as suas.
drop policy if exists "Presenca: associada vê as suas" on public.participacoes_evento;
create policy "Presenca: associada vê as suas"
  on public.participacoes_evento for select
  using (profile_id = auth.uid());

drop policy if exists "Presenca: associada remove a sua" on public.participacoes_evento;
create policy "Presenca: associada remove a sua"
  on public.participacoes_evento for delete
  using (profile_id = auth.uid());

-- Admin vê/gerencia todas (inclui remover engano).
drop policy if exists "Presenca: admin tudo" on public.participacoes_evento;
create policy "Presenca: admin tudo"
  on public.participacoes_evento for all
  using (public.is_admin())
  with check (public.is_admin());

-- Listagem pública de participantes de um evento (para a ata, na página de eventos).
-- Só expõe eventos marcados permite_presenca (o fórum), nunca inscrições de outros eventos.
create or replace function public.participantes_do_evento(p_evento_id uuid)
returns table (nome text, registrado_em timestamptz)
language sql
security definer
set search_path = public
as $$
  select pr.nome_completo, pe.registrado_em
  from public.participacoes_evento pe
  join public.profiles pr on pr.id = pe.profile_id
  join public.eventos  e  on e.id  = pe.evento_id
  where pe.evento_id = p_evento_id
    and e.permite_presenca
  order by pr.nome_completo;
$$;

revoke all on function public.participantes_do_evento(uuid) from public;
grant execute on function public.participantes_do_evento(uuid) to anon, authenticated;
