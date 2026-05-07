-- ============================================================
-- Migração: adicionar coluna `categoria` em profiles
-- Data: 2026-05-07
-- Roda no SQL Editor do Supabase. Idempotente: pode rodar de novo.
-- ============================================================

alter table public.profiles
  add column if not exists categoria text
  check (categoria in ('enfermeira', 'tecnica', 'auxiliar', 'estudante'));

-- Atualiza o trigger que cria perfil no signup, agora também
-- copiando a categoria do user metadata.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, nome_completo, coren, telefone, categoria)
  values (
    new.id,
    new.raw_user_meta_data->>'nome_completo',
    new.raw_user_meta_data->>'coren',
    new.raw_user_meta_data->>'telefone',
    new.raw_user_meta_data->>'categoria'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;
