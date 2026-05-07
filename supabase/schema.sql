-- ============================================================
-- Schema inicial do Supabase para a área da associada — Abenfo RJ
--
-- Como rodar:
--   1. No painel do Supabase, abra "SQL Editor"
--   2. Crie uma nova query, cole TODO este arquivo
--   3. Clique em "Run"
--
-- Pode rodar de novo sem medo: usa "if not exists" e "or replace".
-- ============================================================


-- ============================================================
-- Tabela de perfis das associadas
-- ============================================================

create table if not exists public.profiles (
  id              uuid primary key references auth.users(id) on delete cascade,
  nome_completo   text,
  coren           text,
  telefone        text,
  foto_url        text,
  ano_vigencia    integer,
  status          text not null default 'pendente'
                  check (status in ('pendente', 'ativo', 'inativo')),
  is_admin        boolean not null default false,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

comment on table public.profiles is 'Perfil estendido das usuárias autenticadas (associadas).';
comment on column public.profiles.status is 'pendente = aguardando aprovação | ativo = liberada | inativo = revogada';
comment on column public.profiles.is_admin is 'Diretoras que podem aprovar associadas e gerenciar conteúdo.';


-- ============================================================
-- Trigger para criar perfil automaticamente após signup
-- ============================================================

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, nome_completo, coren, telefone)
  values (
    new.id,
    new.raw_user_meta_data->>'nome_completo',
    new.raw_user_meta_data->>'coren',
    new.raw_user_meta_data->>'telefone'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();


-- ============================================================
-- Função auxiliar para checar se o usuário atual é admin
-- (evita recursão nas policies)
-- ============================================================

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select coalesce(
    (select is_admin from public.profiles where id = auth.uid()),
    false
  );
$$;


-- ============================================================
-- RLS — Row Level Security
-- ============================================================

alter table public.profiles enable row level security;

-- Drop policies anteriores (idempotência)
drop policy if exists "Associada lê próprio perfil" on public.profiles;
drop policy if exists "Associada atualiza próprio perfil" on public.profiles;
drop policy if exists "Admin lê todos os perfis"     on public.profiles;
drop policy if exists "Admin atualiza qualquer perfil" on public.profiles;

-- Cada usuária vê só o próprio perfil
create policy "Associada lê próprio perfil"
  on public.profiles for select
  using (auth.uid() = id);

-- E pode atualizar (mas não pode mudar status nem is_admin — checagem feita no app)
create policy "Associada atualiza próprio perfil"
  on public.profiles for update
  using (auth.uid() = id);

-- Admin vê todos
create policy "Admin lê todos os perfis"
  on public.profiles for select
  using (public.is_admin());

-- Admin atualiza qualquer perfil (aprovar, mudar status etc.)
create policy "Admin atualiza qualquer perfil"
  on public.profiles for update
  using (public.is_admin());


-- ============================================================
-- Storage: bucket de fotos de perfil (carteirinha)
-- ============================================================

insert into storage.buckets (id, name, public)
values ('fotos-perfil', 'fotos-perfil', true)
on conflict (id) do nothing;

-- Policies do storage
drop policy if exists "Foto de perfil é pública" on storage.objects;
drop policy if exists "Associada sobe própria foto" on storage.objects;
drop policy if exists "Associada atualiza própria foto" on storage.objects;
drop policy if exists "Associada apaga própria foto" on storage.objects;

-- Qualquer associada autenticada pode VER as fotos (precisa pra carteirinha)
create policy "Foto de perfil é pública"
  on storage.objects for select
  using (bucket_id = 'fotos-perfil');

-- Cada usuária só pode subir/atualizar/apagar a própria foto
-- (caminho deve começar com o uuid do usuário, ex.: "{uid}/foto.jpg")
create policy "Associada sobe própria foto"
  on storage.objects for insert
  with check (
    bucket_id = 'fotos-perfil'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "Associada atualiza própria foto"
  on storage.objects for update
  using (
    bucket_id = 'fotos-perfil'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "Associada apaga própria foto"
  on storage.objects for delete
  using (
    bucket_id = 'fotos-perfil'
    and auth.uid()::text = (storage.foldername(name))[1]
  );


-- ============================================================
-- COMO PROMOVER A SABRINA A ADMIN
--
-- Depois que você se cadastrar no site (criar conta normal),
-- venha aqui no SQL Editor e rode:
--
--   update public.profiles
--   set is_admin = true, status = 'ativo'
--   where id = (
--     select id from auth.users
--     where email = 'sabrinalinsseibert@gmail.com'
--   );
--
-- A partir desse momento você pode aprovar outras associadas
-- direto pelo painel "Authentication > Users" + "Table Editor > profiles".
-- ============================================================
