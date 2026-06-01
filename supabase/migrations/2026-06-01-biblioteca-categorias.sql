alter table public.biblioteca_obras
  drop constraint if exists biblioteca_obras_categoria_check;

update public.biblioteca_obras set categoria = 'manuais_protocolos' where categoria = 'didaticos';
update public.biblioteca_obras set categoria = 'legislacao_regulacao' where categoria = 'legislacao';
update public.biblioteca_obras set categoria = 'outros' where categoria = 'publicacoes';

alter table public.biblioteca_obras
  alter column categoria set default 'manuais_protocolos';

alter table public.biblioteca_obras
  add constraint biblioteca_obras_categoria_check
  check (categoria in ('manuais_protocolos','legislacao_regulacao','artigos','pareceres','outros'));
