-- ============================================================
-- Migração: adicionar coluna `email` em profiles
-- Data: 2026-05-08
-- Necessário pra exibir e-mail no painel admin (envio de
-- lembretes de renovação para associadas inativas).
-- ============================================================

alter table public.profiles
  add column if not exists email text;

-- Backfill: copia o email do auth.users pra cada profile existente
update public.profiles p
set email = u.email
from auth.users u
where u.id = p.id
  and (p.email is null or p.email <> u.email);

-- Atualiza trigger para também preencher email a partir de agora
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, nome_completo, email, coren, telefone, categoria)
  values (
    new.id,
    new.raw_user_meta_data->>'nome_completo',
    new.email,
    new.raw_user_meta_data->>'coren',
    new.raw_user_meta_data->>'telefone',
    new.raw_user_meta_data->>'categoria'
  )
  on conflict (id) do update set
    email = excluded.email;
  return new;
end;
$$;
