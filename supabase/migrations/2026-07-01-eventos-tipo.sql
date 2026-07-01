-- Tipo do evento — define quais sub-abas aparecem no painel admin ao selecionar
-- o evento no dropdown. Valores: congresso | forum | curso | outro.

alter table public.eventos
  add column if not exists tipo text not null default 'congresso';

-- Backfill: o que já tem registro de presença é fórum; o resto fica congresso.
update public.eventos set tipo = 'forum' where permite_presenca = true;
