-- ============================================================
-- Comunicados por e-mail em massa (ABENFO-RJ)
-- Rode este SQL no painel do Supabase: SQL Editor > New query > Run.
-- Cria as tabelas de log de envios e de descadastros (opt-out / LGPD).
-- ============================================================

-- Log de cada envio em massa (um registro por comunicado disparado)
create table if not exists public.comunicados (
  id                  uuid primary key default gen_random_uuid(),
  assunto             text not null,
  corpo_html          text not null,
  enviado_por         uuid references auth.users(id),
  enviado_em          timestamptz not null default now(),
  total_destinatarios integer not null default 0,
  total_enviados      integer not null default 0,
  total_falhas        integer not null default 0,
  falhas              jsonb   not null default '[]'::jsonb,
  status              text    not null default 'enviado'  -- 'enviado' | 'teste' | 'erro'
);

-- Opt-out: e-mails que pediram para não receber comunicados.
-- A Edge Function remove estes destinatários antes de enviar.
create table if not exists public.descadastros (
  email      text primary key,
  motivo     text,
  criado_em  timestamptz not null default now()
);

-- ------------------------------------------------------------
-- RLS: por padrão nega tudo pelo cliente público (anonKey).
-- A Edge Function usa a SERVICE ROLE KEY e ignora RLS, então
-- só precisamos liberar a LEITURA do histórico para admins.
-- ------------------------------------------------------------
alter table public.comunicados  enable row level security;
alter table public.descadastros enable row level security;

drop policy if exists "admins leem comunicados" on public.comunicados;
create policy "admins leem comunicados" on public.comunicados
  for select
  using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.is_admin = true
    )
  );

-- descadastros e a escrita de comunicados ficam acessíveis apenas
-- via Edge Function (service role). Nenhuma policy = nenhum acesso anon.

comment on table public.comunicados  is 'Histórico de e-mails em massa enviados aos associados.';
comment on table public.descadastros is 'E-mails que optaram por não receber comunicados (LGPD).';
