-- Avisos da área da associada.
-- Card "Avisos" no dashboard (/area) lê os ativos; admin gerencia em /area/admin.
create table if not exists public.avisos (
  id        uuid        primary key default gen_random_uuid(),
  titulo    text        not null,
  mensagem  text,
  ativo     boolean     not null default true,
  ordem     integer     not null default 0,
  criado_em timestamptz not null default now()
);

create index if not exists avisos_ativo_ordem_idx
  on public.avisos (ativo, ordem, criado_em desc);

alter table public.avisos enable row level security;

drop policy if exists avisos_admin_tudo on public.avisos;
create policy avisos_admin_tudo
  on public.avisos
  for all
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists avisos_socia_le_ativos on public.avisos;
create policy avisos_socia_le_ativos
  on public.avisos
  for select
  to authenticated
  using (ativo = true);
