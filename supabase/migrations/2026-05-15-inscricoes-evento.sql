-- ============================================================
-- Tabela `inscricoes_evento`: registra associadas inscritas em
-- eventos da Abenfo RJ (IX ENEON e futuros).
--
-- Por que: as inscrições acontecem na Doity (plataforma externa)
-- e a diretoria precisa cruzar a lista de inscritas com os perfis
-- das sócias para que elas vejam suas inscrições na área da
-- associada. O painel admin recebe um CSV/lista de e-mails,
-- cruza com `profiles.email` e popula esta tabela.
--
-- A unicidade (profile_id, evento_chave) impede que reimportar a
-- mesma lista duplique linhas.
-- ============================================================

create table if not exists public.inscricoes_evento (
  id               uuid        primary key default gen_random_uuid(),
  profile_id       uuid        not null references public.profiles(id) on delete cascade,
  evento_chave     text        not null,
  evento_nome      text        not null,
  data_inscricao   timestamptz not null default now(),
  observacao       text,
  created_at       timestamptz not null default now(),
  created_by       uuid        references auth.users(id) on delete set null,
  unique (profile_id, evento_chave)
);

create index if not exists inscricoes_evento_profile_id_idx
  on public.inscricoes_evento (profile_id);

create index if not exists inscricoes_evento_evento_chave_idx
  on public.inscricoes_evento (evento_chave);

alter table public.inscricoes_evento enable row level security;

-- Associada vê só as inscrições dela mesma
drop policy if exists "Associada vê suas inscrições" on public.inscricoes_evento;
create policy "Associada vê suas inscrições"
  on public.inscricoes_evento for select
  using (profile_id = auth.uid());

-- Admin vê todas
drop policy if exists "Admin vê todas as inscrições" on public.inscricoes_evento;
create policy "Admin vê todas as inscrições"
  on public.inscricoes_evento for select
  using (public.is_admin());

-- Admin insere
drop policy if exists "Admin insere inscrições" on public.inscricoes_evento;
create policy "Admin insere inscrições"
  on public.inscricoes_evento for insert
  with check (public.is_admin());

-- Admin atualiza
drop policy if exists "Admin atualiza inscrições" on public.inscricoes_evento;
create policy "Admin atualiza inscrições"
  on public.inscricoes_evento for update
  using (public.is_admin())
  with check (public.is_admin());

-- Admin exclui
drop policy if exists "Admin exclui inscrições" on public.inscricoes_evento;
create policy "Admin exclui inscrições"
  on public.inscricoes_evento for delete
  using (public.is_admin());
