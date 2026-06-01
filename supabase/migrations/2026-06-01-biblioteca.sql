create table if not exists public.biblioteca_obras (
  id          uuid        primary key default gen_random_uuid(),
  titulo      text        not null,
  autor       text,
  categoria   text        not null default 'publicacoes'
                check (categoria in ('publicacoes','legislacao','pareceres','didaticos')),
  descricao   text,
  capa_path   text,
  arquivo_url text        not null,
  ordem       integer     not null default 0,
  ativo       boolean     not null default true,
  criado_em   timestamptz not null default now()
);

create index if not exists biblioteca_categoria_idx
  on public.biblioteca_obras (categoria, ordem);

alter table public.biblioteca_obras enable row level security;

drop policy if exists biblioteca_admin_tudo on public.biblioteca_obras;
create policy biblioteca_admin_tudo
  on public.biblioteca_obras
  for all
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists biblioteca_socia_le_ativas on public.biblioteca_obras;
create policy biblioteca_socia_le_ativas
  on public.biblioteca_obras
  for select
  to authenticated
  using (ativo = true);

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
