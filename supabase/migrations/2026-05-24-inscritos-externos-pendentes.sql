-- Adiciona colunas em inscritos_externos para rastrear a cota Doity escolhida
-- e marcar inscritos que pagaram como socia/o sem estarem cadastrados em profiles.
-- O admin notifica esses casos por e-mail e marca como regularizada quando
-- a pessoa filia-se ou paga a diferenca como nao-socia.

alter table public.inscritos_externos
  add column if not exists lote_doity                  text,
  add column if not exists valor_pago                  text,
  add column if not exists pendente_verificacao_socia  boolean not null default false,
  add column if not exists notificado_em               timestamptz;

create index if not exists inscritos_externos_pendentes_idx
  on public.inscritos_externos (evento_id)
  where pendente_verificacao_socia = true;
