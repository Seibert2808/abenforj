-- Marca quais trabalhos foram DE FATO apresentados no IX ENEON.
-- Só trabalhos aceitos E apresentados geram certificado de apresentação/coautoria.
-- O admin liga/desliga na lista de trabalhos. Rode no SQL editor do Supabase.

alter table public.trabalhos_cientificos
  add column if not exists apresentado boolean not null default false;
