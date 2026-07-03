-- Adiciona o tipo "monitoria" aos modelos de certificado.
-- Monitoras recebem 2 certificados: participação (via inscrição) + monitoria.
-- O CHECK original só aceitava participacao/oficina/palestrante/comissao.

alter table public.certificado_modelos
  drop constraint if exists certificado_modelos_tipo_check;

alter table public.certificado_modelos
  add constraint certificado_modelos_tipo_check
  check (tipo in ('participacao','monitoria','oficina','palestrante','comissao'));
