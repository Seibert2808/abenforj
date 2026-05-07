-- ============================================================
-- Migração: campos vindos do Google Forms (cadastro completo)
-- Data: 2026-05-07
-- ============================================================

alter table public.profiles
  add column if not exists cpf text;

alter table public.profiles
  add column if not exists formacao text
  check (formacao in ('fundamental', 'medio', 'graduacao', 'especializacao', 'mestrado', 'doutorado'));

alter table public.profiles
  add column if not exists tipo_socio text
  check (tipo_socio in ('efetiva', 'especial'));
