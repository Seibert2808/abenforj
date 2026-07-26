-- Inclui a AUTORIA COMPLETA no certificado de apresentação (relator) do IX ENEON.
--
-- Antes, o certificado de apresentação citava só o título do trabalho. Agora
-- passa a listar todos os autores, com o relator primeiro e destacado — a linha
-- {{autores}} é montada no navegador (js/certificado.js → formatarAutores) e cai
-- aqui no lugar do placeholder. Ex.: "de autoria de Fulana (relator), Beltrano e Sicrana".
--
-- Só o modelo 'apresentacao' muda. O de 'coautoria' continua como está.
-- Idempotente. Rode no SQL editor do Supabase.

update public.certificado_modelos m
set texto_template =
  'apresentou o trabalho intitulado "{{titulo}}", de autoria de {{autores}}, ' ||
  'no IX ENEON – IX Encontro de Enfermagem Obstétrica e Neonatal do Estado do Rio de Janeiro, ' ||
  'realizado de 15 a 17 de julho de 2026, na UERJ.'
from public.eventos e
where m.evento_id = e.id
  and e.nome = 'IX ENEON 2026'
  and m.tipo = 'apresentacao';

-- Conferência: veja o texto novo.
select tipo, texto_template
from public.certificado_modelos m
join public.eventos e on e.id = m.evento_id
where e.nome = 'IX ENEON 2026' and m.tipo = 'apresentacao';
