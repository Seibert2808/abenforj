-- Carga horária no certificado de MONITORIA do IX ENEON 2026.
--
-- Problema (14/08/2026): o modelo tem config->>'carga_horaria' = 30, mas o
-- texto não usa {{carga_horaria}} em lugar nenhum, então o PDF saía sem citar
-- a carga. O edital da monitoria promete "certificado de 30 horas".
--
-- Conserto: acrescenta ", totalizando {{carga_horaria}} horas." ao final do
-- texto, no mesmo padrão da declaração de participação. Troca o ponto final
-- por vírgula antes de emendar.
--
-- Rode no SQL editor do Supabase. Idempotente: não mexe se o texto já usar o
-- placeholder. Não depende de deploy, o texto é lido na hora de gerar o PDF.

update public.certificado_modelos
set texto_template = regexp_replace(btrim(texto_template), '\.\s*$', '')
                     || ', totalizando {{carga_horaria}} horas.'
where evento_id = (select id from public.eventos where nome = 'IX ENEON 2026')
  and tipo = 'monitoria'
  and coalesce(texto_template, '') <> ''
  and texto_template not like '%{{carga_horaria}}%';

-- garante a carga (se estiver vazia, o texto sairia com um buraco no lugar)
update public.certificado_modelos
set config = jsonb_set(coalesce(config, '{}'::jsonb), '{carga_horaria}', '"30"')
where evento_id = (select id from public.eventos where nome = 'IX ENEON 2026')
  and tipo = 'monitoria'
  and coalesce(config->>'carga_horaria', '') = '';

-- conferência: como o texto vai sair no PDF
select replace(texto_template, '{{carga_horaria}}', coalesce(config->>'carga_horaria', '?')) as texto_final
from public.certificado_modelos
where evento_id = (select id from public.eventos where nome = 'IX ENEON 2026')
  and tipo = 'monitoria';
