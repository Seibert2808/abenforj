-- ============================================================
-- Migração: adicionar gênero e nome social
-- Data: 2026-05-08
-- ============================================================

alter table public.profiles
  add column if not exists nome_social text;

alter table public.profiles
  add column if not exists genero text
  check (genero in ('feminino', 'masculino', 'outro'));

-- Atualiza trigger para preencher os novos campos a partir do signup
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, nome_completo, nome_social, email, coren, telefone, categoria, genero)
  values (
    new.id,
    new.raw_user_meta_data->>'nome_completo',
    new.raw_user_meta_data->>'nome_social',
    new.email,
    new.raw_user_meta_data->>'coren',
    new.raw_user_meta_data->>'telefone',
    new.raw_user_meta_data->>'categoria',
    new.raw_user_meta_data->>'genero'
  )
  on conflict (id) do update set email = excluded.email;
  return new;
end;
$$;
