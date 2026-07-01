-- Participantes EXTERNOS de um evento (sem conta no site): médicos (CRM), convidados etc.
-- Cadastrados pelo admin (nome + e-mail + documento). Entram na listagem/ata e poderão
-- receber a declaração de participação (Fase 2, junto com os certificados).

create table if not exists public.participantes_externos (
  id            uuid        primary key default gen_random_uuid(),
  evento_id     uuid        not null references public.eventos(id) on delete cascade,
  nome          text        not null,
  email         text,
  telefone      text,
  documento     text,       -- COREN/CPF, opcional
  observacao    text,
  registrado_em timestamptz not null default now(),
  criado_por    uuid        references auth.users(id) on delete set null
);

create index if not exists participantes_externos_evento_idx on public.participantes_externos (evento_id);

alter table public.participantes_externos enable row level security;

drop policy if exists "ParticipantesExternos: admin tudo" on public.participantes_externos;
create policy "ParticipantesExternos: admin tudo"
  on public.participantes_externos for all
  using (public.is_admin())
  with check (public.is_admin());

-- Atualiza a listagem pública (para a ata): une sócias (auto-registro) + externos (admin).
-- Muda a assinatura (agora inclui 'tipo'), então dropa antes de recriar.
drop function if exists public.participantes_do_evento(uuid);

create function public.participantes_do_evento(p_evento_id uuid)
returns table (nome text, tipo text, registrado_em timestamptz)
language sql
security definer
set search_path = public
as $$
  select pr.nome_completo as nome, 'socia'::text as tipo, pe.registrado_em
  from public.participacoes_evento pe
  join public.profiles pr on pr.id = pe.profile_id
  join public.eventos  e  on e.id  = pe.evento_id
  where pe.evento_id = p_evento_id and e.permite_presenca
  union all
  select ex.nome, 'externo'::text as tipo, ex.registrado_em
  from public.participantes_externos ex
  join public.eventos e on e.id = ex.evento_id
  where ex.evento_id = p_evento_id and e.permite_presenca
  order by nome;
$$;

revoke all on function public.participantes_do_evento(uuid) from public;
grant execute on function public.participantes_do_evento(uuid) to anon, authenticated;
