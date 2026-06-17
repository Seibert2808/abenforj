-- Marca inscrições de evento como canceladas sem perder o registro.
-- Cobre não-sócios (inscritos_externos) e sócias (inscricoes_evento).
alter table public.inscritos_externos
  add column if not exists cancelado        boolean not null default false,
  add column if not exists cancelado_motivo text,
  add column if not exists cancelado_em     timestamptz;

alter table public.inscricoes_evento
  add column if not exists cancelado        boolean not null default false,
  add column if not exists cancelado_motivo text,
  add column if not exists cancelado_em     timestamptz;
