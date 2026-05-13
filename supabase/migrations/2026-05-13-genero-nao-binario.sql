-- ============================================================
-- Adiciona 'nao_binario' como opção válida no campo genero.
--
-- Valores aceitos passam de ('feminino', 'masculino', 'outro')
-- para ('feminino', 'masculino', 'nao_binario', 'outro').
-- 'Prefiro não declarar' continua representado por NULL.
-- ============================================================

alter table public.profiles drop constraint if exists profiles_genero_check;

alter table public.profiles add constraint profiles_genero_check
  check (genero in ('feminino', 'masculino', 'nao_binario', 'outro'));
