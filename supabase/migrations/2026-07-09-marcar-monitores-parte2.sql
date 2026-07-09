-- Parte 2: resolve os monitores que o UPDATE não pegou (sem inscrição no
-- IX ENEON). Rodar no SQL Editor DEPOIS da parte 1.

-- A) Cria a inscrição no IX ENEON já marcada "Monitora" para os monitores que
--    TÊM perfil mas NÃO tinham inscrição (assim geram os 2 certificados:
--    participação + monitoria). Idempotente.
insert into public.inscricoes_evento (profile_id, evento_id, observacao)
select distinct p.id, m.evento_id, 'Monitora'
from public.monitores_evento m
join public.profiles p
  on regexp_replace(translate(lower(btrim(coalesce(p.nome_completo, p.nome_social))),
       'áàâãäéèêëíìîïóòôõöúùûüçñ','aaaaaeeeeiiiiooooouuuucn'), '\s+', ' ', 'g')
   = regexp_replace(translate(lower(btrim(m.nome)),
       'áàâãäéèêëíìîïóòôõöúùûüçñ','aaaaaeeeeiiiiooooouuuucn'), '\s+', ' ', 'g')
where m.evento_id = (select id from public.eventos where nome = 'IX ENEON 2026' limit 1)
  and not exists (
    select 1 from public.inscricoes_evento ie
    where ie.profile_id = p.id and ie.evento_id = m.evento_id
  )
on conflict (profile_id, evento_id) do nothing;

-- B) Localiza Gleicia e Rebeca por nome aproximado (o nome no perfil difere um
--    pouco do da lista). Mostra se já têm inscrição/observação no IX ENEON.
select p.id, p.nome_completo, p.email,
       (ie.id is not null) as tem_inscricao,
       ie.observacao
from public.profiles p
left join public.inscricoes_evento ie
  on ie.profile_id = p.id
 and ie.evento_id = (select id from public.eventos where nome = 'IX ENEON 2026' limit 1)
where translate(lower(coalesce(p.nome_completo, p.nome_social, '')),
        'áàâãäéèêëíìîïóòôõöúùûüçñ','aaaaaeeeeiiiiooooouuuucn')
      ~ '(gleicia.*paes|rebeca.*guimaraes)';
