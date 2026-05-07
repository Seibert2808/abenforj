-- ============================================================
-- Migração: adicionar coluna `cadastro_completo` em profiles
-- Data: 2026-05-07
-- Marca se a associada já enviou os documentos pelo Google Forms
-- e se a diretoria já arquivou no Drive da Abenfo.
-- ============================================================

alter table public.profiles
  add column if not exists cadastro_completo boolean not null default false;
