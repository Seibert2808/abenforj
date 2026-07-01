-- Adiciona telefone aos participantes externos (cadastro de contatos / CRM para
-- divulgação de eventos e cursos). Idempotente. Rodar no banco que já tem a tabela.

alter table public.participantes_externos
  add column if not exists telefone text;
