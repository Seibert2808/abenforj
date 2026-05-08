-- ============================================================
-- Migração: expandir categorias profissionais
-- Data: 2026-05-08
-- Antes: 'enfermeira', 'tecnica', 'auxiliar', 'estudante'
-- Depois: adiciona 'enfermeira_obstetrica' e 'obstetriz' para
-- diferenciar especialização na carteirinha digital.
-- ============================================================

alter table public.profiles
  drop constraint if exists profiles_categoria_check;

alter table public.profiles
  add constraint profiles_categoria_check
  check (categoria in (
    'enfermeira_obstetrica',
    'obstetriz',
    'enfermeira',
    'tecnica',
    'auxiliar',
    'estudante'
  ));
