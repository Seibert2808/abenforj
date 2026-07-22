-- Normaliza os nomes dos cursos: remove quebras de linha, tabs e espacos
-- duplicados que vieram do cadastro. O nome entra no certificado pelo
-- placeholder {{curso}}, entao espacos extras saem tortos no PDF.
--
-- Seguro: nada no site casa curso por nome literal (as referencias sao por id).

-- 1) PREVIA - rode primeiro e confira o "depois" antes de aplicar.
select
  id,
  nome as antes,
  btrim(regexp_replace(replace(nome, chr(160), ' '), '\s+', ' ', 'g')) as depois
from cursos
where nome <> btrim(regexp_replace(replace(nome, chr(160), ' '), '\s+', ' ', 'g'))
order by nome;

-- 2) APLICAR - so depois de conferir a previa acima.
update cursos
set nome = btrim(regexp_replace(replace(nome, chr(160), ' '), '\s+', ' ', 'g'))
where nome <> btrim(regexp_replace(replace(nome, chr(160), ' '), '\s+', ' ', 'g'));

-- 3) CONFERIR - deve listar os 7 cursos em uma linha cada.
select nome, turno, carga_horaria from cursos order by turno, nome;
