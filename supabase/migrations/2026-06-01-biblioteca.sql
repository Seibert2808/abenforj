-- Biblioteca da ABENFO-RJ — acervo para as associadas.
-- Modelo híbrido: os metadados e a CAPA ficam no Supabase; o ARQUIVO da obra
-- mora no Google Drive (campo arquivo_url) — assim o acervo não tem teto de
-- volume. A sócia clica na capa e o download dispara direto.

create table if not exists public.biblioteca_obras (
  id          uuid        primary key default gen_random_uuid(),

  titulo      text        not null,
  autor       text,
  -- Mesmas 4 seções já usadas na página da biblioteca
  categoria   text        not null default 'publicacoes'
                check (categoria in ('publicacoes','legislacao','pareceres','didaticos')),
  descricao   text,

  -- Capa: caminho no bucket biblioteca-capas (opcional — sem capa, mostra placeholder)
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
drop policy if exists "Biblioteca: admin tudo" on public.biblioteca_obras;
create policy "Biblioteca: admin tudo"
  on public.biblioteca_obras for all
  using (public.is_admin())
  with check (public.is_admin());

-- Qualquer associada autenticada vê as obras ativas
drop policy if exists "Biblioteca: associada lê ativas" on public.biblioteca_obras;
create policy "Biblioteca: associada lê ativas"
  on public.biblioteca_obras for select
  to authenticated
  using (ativo = true);

-- Bucket de capas (público — capa não é sigilosa; o arquivo em si fica no Drive)
insert into storage.buckets (id, name, public)
values ('biblioteca-capas', 'biblioteca-capas', true)
on conflict (id) do nothing;

drop policy if exists "Capa biblioteca é pública" on storage.objects;
create policy "Capa biblioteca é pública"
  on storage.objects for select
  using (bucket_id = 'biblioteca-capas');

drop policy if exists "Capa biblioteca: admin gerencia" on storage.objects;
create policy "Capa biblioteca: admin gerencia"
  on storage.objects for all
  using (bucket_id = 'biblioteca-capas' and public.is_admin())
  with check (bucket_id = 'biblioteca-capas' and public.is_admin());
