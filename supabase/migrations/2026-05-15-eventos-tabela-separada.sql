-- Refatoracao: separar eventos em sua propria tabela.
-- Substitui o desenho de 2026-05-15-inscricoes-evento.sql.
-- Eventos viram entidade propria; inscricoes_evento aponta por FK.
-- O DROP eh seguro: tabela antiga estava vazia em 2026-05-15.

drop table if exists public.inscricoes_evento cascade;

create table if not exists public.eventos (
  id              uuid        primary key default gen_random_uuid(),
  nome            text        not null,
  data_inicio     date,
  data_fim        date,
  local           text,
  link_externo    text,
  ativo           boolean     not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index if not exists eventos_data_inicio_idx
  on public.eventos (data_inicio desc nulls last);

alter table public.eventos enable row level security;

-- Leitura publica para todos (cursos.html faz join, evento nao eh sensivel).
drop policy if exists "Eventos: leitura pública" on public.eventos;
create policy "Eventos: leitura pública"
  on public.eventos for select
  using (true);

drop policy if exists "Eventos: admin insere" on public.eventos;
create policy "Eventos: admin insere"
  on public.eventos for insert
  with check (public.is_admin());

drop policy if exists "Eventos: admin atualiza" on public.eventos;
create policy "Eventos: admin atualiza"
  on public.eventos for update
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists "Eventos: admin exclui" on public.eventos;
create policy "Eventos: admin exclui"
  on public.eventos for delete
  using (public.is_admin());

create table public.inscricoes_evento (
  id              uuid        primary key default gen_random_uuid(),
  profile_id      uuid        not null references public.profiles(id) on delete cascade,
  evento_id       uuid        not null references public.eventos(id) on delete cascade,
  data_inscricao  timestamptz not null default now(),
  observacao      text,
  created_at      timestamptz not null default now(),
  created_by      uuid        references auth.users(id) on delete set null,
  unique (profile_id, evento_id)
);

create index if not exists inscricoes_evento_profile_id_idx
  on public.inscricoes_evento (profile_id);
create index if not exists inscricoes_evento_evento_id_idx
  on public.inscricoes_evento (evento_id);

alter table public.inscricoes_evento enable row level security;

drop policy if exists "Inscrições: associada vê as suas" on public.inscricoes_evento;
create policy "Inscrições: associada vê as suas"
  on public.inscricoes_evento for select
  using (profile_id = auth.uid());

drop policy if exists "Inscrições: admin vê todas" on public.inscricoes_evento;
create policy "Inscrições: admin vê todas"
  on public.inscricoes_evento for select
  using (public.is_admin());

drop policy if exists "Inscrições: admin insere" on public.inscricoes_evento;
create policy "Inscrições: admin insere"
  on public.inscricoes_evento for insert
  with check (public.is_admin());

drop policy if exists "Inscrições: admin atualiza" on public.inscricoes_evento;
create policy "Inscrições: admin atualiza"
  on public.inscricoes_evento for update
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists "Inscrições: admin exclui" on public.inscricoes_evento;
create policy "Inscrições: admin exclui"
  on public.inscricoes_evento for delete
  using (public.is_admin());

-- Pre-cadastro do IX ENEON 2026.
insert into public.eventos (nome, data_inicio, data_fim, local, link_externo)
select 'IX ENEON 2026',
       '2026-07-15',
       '2026-07-17',
       'UERJ - Rio de Janeiro',
       'https://doity.com.br/ix-encontro-de-enfermagem-obsttrica-e-neonatal-do-estado-do-rio-de-janeiro'
where not exists (select 1 from public.eventos where nome = 'IX ENEON 2026');
