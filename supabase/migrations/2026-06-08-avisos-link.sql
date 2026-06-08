-- Link opcional nos avisos: URL + texto do botão (rótulo).
-- Quando link_url está preenchido, o card "Avisos" mostra um botão clicável.
alter table public.avisos add column if not exists link_url   text;
alter table public.avisos add column if not exists link_texto text;
