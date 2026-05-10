-- ============================================================
-- Hotfix: garantir que todas as colunas usadas pelo trigger
-- handle_new_user existam em public.profiles
--
-- Data: 2026-05-09
--
-- Motivação: a presidente recebeu "Database error saving new user"
-- ao se cadastrar. O log do Auth do Supabase mostrou:
--   ERROR: column "email" of relation "profiles" does not exist
-- Ou seja, a migração 2026-05-08-add-email-to-profiles.sql não
-- havia sido aplicada ao banco real, mas as posteriores haviam,
-- então o trigger ficou desalinhado do schema.
--
-- Esta migração consolida todas as colunas que o trigger atual usa
-- e recria o trigger no formato definitivo. É 100% idempotente:
-- pode rodar várias vezes sem efeito colateral.
-- ============================================================

-- 1. Garantir que cada coluna do trigger exista
alter table public.profiles add column if not exists email          text;
alter table public.profiles add column if not exists nome_social    text;
alter table public.profiles add column if not exists genero         text;
alter table public.profiles add column if not exists especialidade  text;
alter table public.profiles add column if not exists categoria      text;

-- 2. Constraints (drop+recreate para garantir o estado atual)
alter table public.profiles drop constraint if exists profiles_genero_check;
alter table public.profiles add constraint profiles_genero_check
  check (genero is null or genero in ('feminino', 'masculino', 'outro'));

alter table public.profiles drop constraint if exists profiles_categoria_check;
alter table public.profiles add constraint profiles_categoria_check
  check (categoria is null or categoria in (
    'enfermeira', 'obstetriz', 'tecnica', 'auxiliar', 'estudante'
  ));

-- 3. Migra dados antigos (categoria = enfermeira_obstetrica) caso existam
update public.profiles
  set categoria = 'enfermeira',
      especialidade = coalesce(especialidade, 'Enfermagem Obstétrica')
  where categoria = 'enfermeira_obstetrica';

-- 4. Backfill: copia email de auth.users para profiles existentes
update public.profiles p
set email = u.email
from auth.users u
where u.id = p.id
  and (p.email is null or p.email <> u.email);

-- 5. Recria trigger na forma final (com nullif para tolerar strings vazias
--    que possam vir do meta_data — defesa em profundidade)
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (
    id, nome_completo, nome_social, email, coren, telefone,
    categoria, especialidade, genero
  )
  values (
    new.id,
    nullif(new.raw_user_meta_data->>'nome_completo', ''),
    nullif(new.raw_user_meta_data->>'nome_social', ''),
    new.email,
    nullif(new.raw_user_meta_data->>'coren', ''),
    nullif(new.raw_user_meta_data->>'telefone', ''),
    nullif(new.raw_user_meta_data->>'categoria', ''),
    nullif(new.raw_user_meta_data->>'especialidade', ''),
    nullif(new.raw_user_meta_data->>'genero', '')
  )
  on conflict (id) do update set email = excluded.email;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
