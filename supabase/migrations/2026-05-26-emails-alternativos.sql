-- Permite associar emails alternativos a um perfil (caso comum: socia
-- cadastrada com email A no site usou email B no Doity). Quando o admin
-- usa o botao "Associar a socia cadastrada" no painel, o email do Doity
-- e salvo aqui, fazendo com que proximos imports cruzem corretamente.

-- Email sempre salvo em lowercase (normalizacao feita no app)
create table if not exists public.emails_alternativos (
  id          uuid        primary key default gen_random_uuid(),
  profile_id  uuid        not null references public.profiles(id) on delete cascade,
  email       text        not null unique,
  observacao  text,
  created_at  timestamptz not null default now(),
  created_by  uuid        references auth.users(id) on delete set null
);

create index if not exists emails_alternativos_profile_idx
  on public.emails_alternativos (profile_id);

alter table public.emails_alternativos enable row level security;

drop policy if exists "EmailsAlternativos: admin tudo" on public.emails_alternativos;
create policy "EmailsAlternativos: admin tudo"
  on public.emails_alternativos for all
  using (public.is_admin())
  with check (public.is_admin());
