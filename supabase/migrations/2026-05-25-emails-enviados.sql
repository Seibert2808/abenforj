-- Registro de e-mails enviados pra associadas (cada clique no botao
-- "Enviar e-mail" cria uma linha aqui). Usado pra ver historico de
-- cobrancas em pendentes de aprovacao. Cada registro pode ser excluido
-- manualmente pelo admin.

create table if not exists public.emails_enviados (
  id           uuid        primary key default gen_random_uuid(),
  profile_id   uuid        not null references public.profiles(id) on delete cascade,
  enviado_em   timestamptz not null default now(),
  enviado_por  uuid        references auth.users(id) on delete set null
);

create index if not exists emails_enviados_profile_idx
  on public.emails_enviados (profile_id, enviado_em desc);

alter table public.emails_enviados enable row level security;

drop policy if exists "EmailsEnviados: admin tudo" on public.emails_enviados;
create policy "EmailsEnviados: admin tudo"
  on public.emails_enviados for all
  using (public.is_admin())
  with check (public.is_admin());
