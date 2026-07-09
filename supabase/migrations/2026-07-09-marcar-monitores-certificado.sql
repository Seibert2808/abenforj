-- Marca a observação "Monitora" na inscrição do IX ENEON para gerar o
-- CERTIFICADO de monitoria. Fonte do certificado = inscricoes_evento.observacao
-- ilike '%monitor%'. Casa os nomes de monitores_evento com profiles por nome
-- normalizado (sem acento, minúsculo, espaços colapsados). IDEMPOTENTE.
-- Rodar no SQL Editor do Supabase.

-- 1) MARCA (idempotente): quem tem perfil + inscrição no IX ENEON.
update public.inscricoes_evento ie
set observacao = case
  when ie.observacao is null or btrim(ie.observacao) = '' then 'Monitora'
  when ie.observacao ilike '%monitor%' then ie.observacao
  else ie.observacao || ' | Monitora' end
from public.monitores_evento m
join public.profiles p
  on regexp_replace(translate(lower(btrim(coalesce(p.nome_completo, p.nome_social))),
       'áàâãäéèêëíìîïóòôõöúùûüçñ','aaaaaeeeeiiiiooooouuuucn'), '\s+', ' ', 'g')
   = regexp_replace(translate(lower(btrim(m.nome)),
       'áàâãäéèêëíìîïóòôõöúùûüçñ','aaaaaeeeeiiiiooooouuuucn'), '\s+', ' ', 'g')
where m.evento_id = (select id from public.eventos where nome = 'IX ENEON 2026' limit 1)
  and ie.profile_id = p.id
  and ie.evento_id = m.evento_id;

-- 2) RELATÓRIO: para cada monitor, se tem perfil, se tem inscrição e a observação
--    atual. Quem aparecer com tem_inscricao=false precisa de atenção manual
--    (sem cadastro/sem inscrição no evento → não gera certificado sozinho).
select m.nome                          as monitor,
       (p.id  is not null)             as tem_perfil,
       (ie.id is not null)             as tem_inscricao,
       ie.observacao
from public.monitores_evento m
left join public.profiles p
  on regexp_replace(translate(lower(btrim(coalesce(p.nome_completo, p.nome_social))),
       'áàâãäéèêëíìîïóòôõöúùûüçñ','aaaaaeeeeiiiiooooouuuucn'), '\s+', ' ', 'g')
   = regexp_replace(translate(lower(btrim(m.nome)),
       'áàâãäéèêëíìîïóòôõöúùûüçñ','aaaaaeeeeiiiiooooouuuucn'), '\s+', ' ', 'g')
left join public.inscricoes_evento ie
  on ie.profile_id = p.id
 and ie.evento_id = (select id from public.eventos where nome = 'IX ENEON 2026' limit 1)
where m.evento_id = (select id from public.eventos where nome = 'IX ENEON 2026' limit 1)
order by tem_inscricao, tem_perfil, m.nome;
