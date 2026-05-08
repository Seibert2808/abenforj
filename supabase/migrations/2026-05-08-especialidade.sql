-- ============================================================
-- Migração: separar Categoria e Especialidade
-- Data: 2026-05-08
--
-- Antes: 'enfermeira_obstetrica' era um valor de categoria.
-- Agora: categoria fica como "Enfermeira" e a especialização
-- (Obstétrica, Neonatal, Pediátrica, Outra livre) vai para
-- a coluna nova `especialidade`.
-- ============================================================

-- 1. Cria a coluna nova
alter table public.profiles
  add column if not exists especialidade text;

-- 2. Migra dados existentes (enfermeira_obstetrica → enfermeira + Obstétrica)
update public.profiles
  set categoria = 'enfermeira',
      especialidade = coalesce(especialidade, 'Enfermagem Obstétrica')
  where categoria = 'enfermeira_obstetrica';

-- 3. Atualiza constraint pra remover 'enfermeira_obstetrica'
alter table public.profiles drop constraint if exists profiles_categoria_check;
alter table public.profiles add constraint profiles_categoria_check
  check (categoria in ('enfermeira', 'obstetriz', 'tecnica', 'auxiliar', 'estudante'));

-- 4. Atualiza trigger para preencher especialidade no signup
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
    new.raw_user_meta_data->>'nome_completo',
    new.raw_user_meta_data->>'nome_social',
    new.email,
    new.raw_user_meta_data->>'coren',
    new.raw_user_meta_data->>'telefone',
    new.raw_user_meta_data->>'categoria',
    new.raw_user_meta_data->>'especialidade',
    new.raw_user_meta_data->>'genero'
  )
  on conflict (id) do update set email = excluded.email;
  return new;
end;
$$;
