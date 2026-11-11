-- ============================================================
-- Fila de disparos dos comunicados (ABENFO-RJ)
-- Rode este SQL no painel do Supabase: SQL Editor > New query > Run.
--
-- Por que existe: o plano gratuito do Resend envia ~100 e-mails por dia.
-- Com a base atual (263 associadas ativas) um disparo único seria recusado
-- pela metade. A fila guarda um registro por destinatária e envia por lotes
-- diários, sem perder ninguém e sem depender de a admin estar na tela.
-- ============================================================

create table if not exists public.comunicado_destinatarios (
  id            uuid primary key default gen_random_uuid(),
  comunicado_id uuid not null references public.comunicados(id) on delete cascade,
  email         text not null,
  nome          text,
  status        text not null default 'pendente',   -- 'pendente' | 'enviado' | 'falha'
  erro          text,
  tentativas    integer not null default 0,
  enviado_em    timestamptz,
  criado_em     timestamptz not null default now(),
  unique (comunicado_id, email)
);

-- Busca dos pendentes de um comunicado (usado a cada lote).
create index if not exists idx_com_dest_fila
  on public.comunicado_destinatarios (comunicado_id, status, criado_em);

-- Contagem do que já saiu hoje, para respeitar a cota diária do Resend.
create index if not exists idx_com_dest_enviado_em
  on public.comunicado_destinatarios (enviado_em)
  where status = 'enviado';

-- ------------------------------------------------------------
-- RLS: escrita só pela Edge Function (service role, ignora RLS).
-- Admins leem para acompanhar o andamento no painel.
-- ------------------------------------------------------------
alter table public.comunicado_destinatarios enable row level security;

drop policy if exists "admins leem destinatarios" on public.comunicado_destinatarios;
create policy "admins leem destinatarios" on public.comunicado_destinatarios
  for select
  using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.is_admin = true
    )
  );

-- Coluna de controle: quando o último lote rodou (alimenta o painel).
alter table public.comunicados
  add column if not exists ultimo_lote_em timestamptz;

comment on table  public.comunicado_destinatarios is
  'Fila de envio: uma linha por destinatária de cada comunicado.';
comment on column public.comunicados.ultimo_lote_em is
  'Quando o último lote deste comunicado foi processado.';

-- Status possíveis em public.comunicados a partir daqui:
--   'na_fila'     enfileirado, nada enviado ainda
--   'em_andamento' parte enviada, resto aguardando o lote do dia seguinte
--   'concluido'   fila zerada
--   'teste'       envio de teste para a própria admin
--   'enviado' / 'erro'  status antigos, mantidos para o histórico
