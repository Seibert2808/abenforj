-- Credenciamento: vincula a presença de um EXTERNO ao seu registro de inscrito,
-- para o admin poder marcar/desmarcar presença de forma confiável (toggle) na
-- tela de credenciamento. Coluna nula para externos adicionados manualmente.
-- Rode no SQL editor do Supabase. Idempotente.

alter table public.participantes_externos
  add column if not exists inscrito_externo_id uuid
    references public.inscritos_externos(id) on delete set null;

create index if not exists participantes_externos_inscrito_idx
  on public.participantes_externos (inscrito_externo_id);
