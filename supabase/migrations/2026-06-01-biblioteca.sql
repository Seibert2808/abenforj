-- Biblioteca da ABENFO-RJ — acervo para as associadas.
-- Modelo hibrido: os metadados e a CAPA ficam no Supabase; o ARQUIVO da obra
-- mora no Google Drive (campo arquivo_url) — assim o acervo nao tem teto de
-- volume. A socia clica na capa e o download dispara direto.

create table if not exists public.biblioteca_obras (
  id          uuid        primary key default gen_random_uuid(),

  titulo      text        not null,
  autor       text,
  -- Mesmas 4 secoes ja usadas na pagina da biblioteca
  categoria   text        not null default 'publicacoes'
                check (categoria in ('publicacoes','legislacao','pareceres','didaticos')),
  descricao   text,

  -- Capa: caminho no bucket biblioteca-capas (opcional)
  capa_path   text,
  -- Arquivo da obra: link do Google Drive (cru, como o admin colou)
  arquivo_url text        not null,

  ordem       integer     not null default 0,
  ativo       boolean     not null default true,
  criado_em   timestamptz not null default now()
);

create index if not exists biblioteca_categoria_idx
  on public.biblioteca_obras (categoria, ordem);

-- RLS
alter table public.biblioteca_obras enable row level security;

-- Admin gerencia tudo
drop policy if exists biblioteca_admin_tudo on public.biblioteca_obras;
create policy biblioteca_admin_tudo
  on public.biblioteca_obras
  for all
  using (public.is_admin())
  with check (public.is_admin());

-- Qualquer associada autenticada ve as obras ativas
drop policy if exists biblioteca_socia_le_ativas on public.biblioteca_obras;
create policy biblioteca_socia_le_ativas
  on public.biblioteca_obras
  for select
  to authenticated
  using (ativo = true);

-- Bucket de capas (publico — capa nao e sigilosa; o arquivo fica no Drive)
insert into storage.buckets (id, name, public)
values ('biblioteca-capas', 'biblioteca-capas', true)
on conflict (id) do nothing;

drop policy if exists biblioteca_capa_publica on storage.objects;
create policy biblioteca_capa_publica
  on storage.objects
  for select
  using (bucket_id = 'biblioteca-capas');

drop policy if exists biblioteca_capa_admin on storage.objects;
create policy biblioteca_capa_admin
  on storage.objects
  for all
  using (bucket_id = 'biblioteca-capas' and public.is_admin())
  with check (bucket_id = 'biblioteca-capas' and public.is_admin());
