-- Registro de DOCUMENTOS ENVIADOS pelas sócias (via formulário Google + Apps Script).
-- Objetivo: o site saber QUE documento já chegou, parar de cobrar o que foi enviado
-- e ainda permitir reenviar. A conferência final continua sendo o admin virar
-- profiles.cadastro_completo; esta tabela é o estado "recebido, em conferência".
--
-- Como é alimentada: o Apps Script do formulário (conta abenforio), a cada envio,
-- faz POST nesta tabela via REST com a service_role key (bypassa RLS). O vínculo
-- com o perfil é por NOME normalizado (o formulário vem pré-preenchido com o
-- nome_completo do perfil) e, quando disponível, por e-mail.

-- ── Normalização de texto (minúsculas, sem acento, espaços colapsados) ──────────
-- IMMUTABLE para poder ser usada em coluna gerada e em índice.
create or replace function public.norm_txt(t text)
returns text
language sql
immutable
as $$
  select trim(regexp_replace(
    translate(
      lower(coalesce(t, '')),
      'áàâãäéèêëíìîïóòôõöúùûüçñ',
      'aaaaaeeeeiiiiooooouuuucn'
    ),
    '\s+', ' ', 'g'
  ));
$$;

-- ── Tabela ──────────────────────────────────────────────────────────────────────
create table if not exists public.documentos_enviados (
  id           uuid        primary key default gen_random_uuid(),
  nome         text        not null,
  nome_norm    text        generated always as (public.norm_txt(nome)) stored,
  email        text,
  tipo         text        not null,   -- chave canônica: anuidade|matricula|graduacao|coren|pos|outros
  tipo_titulo  text,                   -- título original da pergunta no formulário
  arquivo_nome text,
  enviado_em   timestamptz not null default now()
);

create index if not exists documentos_enviados_nome_norm_idx
  on public.documentos_enviados (nome_norm);
create index if not exists documentos_enviados_email_idx
  on public.documentos_enviados (lower(email));

-- ── RLS: admin enxerga tudo; sócias leem só o delas via RPC abaixo ──────────────
alter table public.documentos_enviados enable row level security;

drop policy if exists "DocsEnviados: admin tudo" on public.documentos_enviados;
create policy "DocsEnviados: admin tudo"
  on public.documentos_enviados for all
  using (public.is_admin())
  with check (public.is_admin());

-- ── RPC: a sócia logada lê os documentos que ELA enviou ─────────────────────────
-- SECURITY DEFINER: roda com privilégio e devolve só as linhas que casam com o
-- perfil de quem chamou (por nome normalizado OU e-mail). Sem expor a tabela toda.
create or replace function public.meus_documentos_enviados()
returns table (tipo text, tipo_titulo text, arquivo_nome text, enviado_em timestamptz)
language sql
security definer
set search_path = public
as $$
  select d.tipo, d.tipo_titulo, d.arquivo_nome, d.enviado_em
  from public.documentos_enviados d
  join public.profiles p on p.id = auth.uid()
  where d.nome_norm = public.norm_txt(p.nome_completo)
     or (d.email is not null and p.email is not null and lower(d.email) = lower(p.email));
$$;

revoke all on function public.meus_documentos_enviados() from public;
grant execute on function public.meus_documentos_enviados() to authenticated;
