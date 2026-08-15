-- MONITORIA vira um PAPEL curado, como palestrante/professor/avaliador.
--
-- Por quê (pedido da Sabrina em 14/08/2026): os monitores não apareciam na
-- lista de papéis do admin (aba Certificados), então não havia como gerar o
-- certificado deles por lá para mandar por e-mail. A única via era a monitora
-- entrar na área logada, e o certificado só saía se a inscrição estivesse
-- marcada "Monitora" E houvesse presença registrada.
--
-- O que muda:
--   • 'monitoria' passa a ser aceito em certificado_papeis (o CHECK barrava);
--   • cada monitor de monitores_evento vira um papel, vinculado à conta da
--     sócia quando o nome casar com o cadastro;
--   • o nome do papel é trocado pelo nome_completo do cadastro quando vinculado
--     (a lista de monitores tem nome curto/torto, e nome torto vira certificado
--     torto — mesma lição dos avaliadores);
--   • no admin, cada linha da lista de papéis ganha o botão "📜 Certificado";
--   • na área da sócia (Meus Eventos) o certificado de monitoria passa a sair
--     também pelo papel, sem depender da observação da inscrição.
--
-- O caminho antigo (inscricoes_evento.observacao ilike '%monitor%' + presença)
-- CONTINUA valendo para quem não tiver papel. area/cursos.html ignora esse
-- caminho quando existe papel de monitoria no evento, para não duplicar.
--
-- Rode no SQL editor do Supabase. Idempotente.
-- Depois deste, rode de novo 2026-07-31-participacao-para-quem-tem-papel.sql
-- (ele dá a declaração de participação a todo mundo com papel vinculado).

-- ── 0. tokens do nome, para comparar "quase igual" ────────────────────────
-- "Rebeca da Silva Guimarães dos Santos" e "Rebeca Silva Guimarães dos Santos"
-- são a mesma pessoa; f_norm_titulo diz que não. Comparando conjuntos de tokens
-- (sem da/de/do/dos/das/e) elas casam, e "Gleicia da Cruz Paes" fica contido em
-- "Gleicia da Cruz Paes Carneiro".
create or replace function public.f_tokens_nome(t text)
returns text[] language sql immutable as $$
  select array(
    select tok
    from unnest(string_to_array(public.f_norm_titulo(t), ' ')) as tok
    where tok <> '' and tok not in ('da','de','do','das','dos','e','a','o')
    order by tok
  );
$$;

-- ── 1. 'monitoria' no CHECK dos papéis ─────────────────────────────────────
alter table public.certificado_papeis
  drop constraint if exists certificado_papeis_tipo_check;
alter table public.certificado_papeis
  add constraint certificado_papeis_tipo_check
  check (tipo in ('palestrante','professor','comissao','avaliador','assistente','monitoria'));

-- ── 2. papéis a partir da lista de monitores do evento ─────────────────────
-- distinct on: a mesma pessoa pode estar repetida em monitores_evento.
with ev as (select id from public.eventos where nome = 'IX ENEON 2026'),
mon as (
  select distinct on (public.f_norm_titulo(m.nome))
         m.evento_id, btrim(m.nome) as nome
  from public.monitores_evento m
  join ev on ev.id = m.evento_id
  where coalesce(btrim(m.nome), '') <> ''
  order by public.f_norm_titulo(m.nome), btrim(m.nome)
)
insert into public.certificado_papeis (evento_id, tipo, nome, detalhe)
select mon.evento_id, 'monitoria', mon.nome, null
from mon
where not exists (
  select 1 from public.certificado_papeis cp
  where cp.evento_id = mon.evento_id and cp.tipo = 'monitoria'
    and (public.f_norm_titulo(cp.nome) = public.f_norm_titulo(mon.nome)
         -- "quase igual" também conta: senão, depois da limpeza de duplicados,
         -- rodar este arquivo de novo recria o papel órfão com o nome da lista.
         or public.f_tokens_nome(cp.nome) @> public.f_tokens_nome(mon.nome))
);

-- ── 3. vincular à conta ANTES de olhar as inscrições ──────────────────────
-- ORDEM IMPORTA: vincular primeiro é o que permite a etapa 4 barrar por
-- profile_id. Rodando na ordem errada, quem está escrito diferente na lista e no
-- cadastro ganha DOIS papéis, um por fonte. Foi o que aconteceu na primeira
-- execução, em 14/08/2026, com Gleicia e Rebeca; limpeza em
-- 2026-08-14-monitoria-duplicados.sql.
update public.certificado_papeis cp
set profile_id = p.id
from public.profiles p
where cp.profile_id is null
  and cp.tipo = 'monitoria'
  and cp.evento_id = (select id from public.eventos where nome = 'IX ENEON 2026')
  and public.f_norm_titulo(cp.nome) = public.f_norm_titulo(coalesce(p.nome_completo, p.nome_social));

-- ── 3b. vincular por nome "quase igual", quando houver UM único candidato ──
-- Pega os casos Gleicia/Rebeca: o papel veio da lista com o nome incompleto e a
-- conta existe com o nome do cadastro. O count(*) = 1 é a trava, com dois
-- candidatos ninguém é vinculado no chute.
update public.certificado_papeis cp
set profile_id = c.pid
from (
  select cp2.id as papel_id, min(p.id::text)::uuid as pid, count(distinct p.id) as n
  from public.certificado_papeis cp2
  join public.inscricoes_evento ie
    on ie.evento_id = cp2.evento_id and ie.observacao ilike '%monitor%'
  join public.profiles p on p.id = ie.profile_id
  where cp2.tipo = 'monitoria'
    and cp2.profile_id is null
    and cp2.evento_id = (select id from public.eventos where nome = 'IX ENEON 2026')
    and public.f_tokens_nome(coalesce(p.nome_completo, p.nome_social)) @> public.f_tokens_nome(cp2.nome)
  group by cp2.id
) c
where cp.id = c.papel_id and c.n = 1;

-- ── 4. quem foi marcado monitor só na inscrição (não está em monitores_evento)
-- O "not exists" barra por três vias: conta já vinculada, nome idêntico e nome
-- "quase igual" (tokens do papel contidos no nome do cadastro). Sem a terceira,
-- quem está escrito diferente nas duas fontes ganha um papel repetido.
with ev as (select id from public.eventos where nome = 'IX ENEON 2026')
insert into public.certificado_papeis (evento_id, tipo, nome, detalhe, profile_id)
select distinct ie.evento_id, 'monitoria',
       btrim(coalesce(p.nome_completo, p.nome_social)), null, p.id
from public.inscricoes_evento ie
join ev on ev.id = ie.evento_id
join public.profiles p on p.id = ie.profile_id
where ie.observacao ilike '%monitor%'
  and coalesce(btrim(coalesce(p.nome_completo, p.nome_social)), '') <> ''
  and not exists (
    select 1 from public.certificado_papeis cp
    where cp.evento_id = ie.evento_id and cp.tipo = 'monitoria'
      and (cp.profile_id = p.id
           or public.f_norm_titulo(cp.nome) = public.f_norm_titulo(coalesce(p.nome_completo, p.nome_social))
           or public.f_tokens_nome(coalesce(p.nome_completo, p.nome_social)) @> public.f_tokens_nome(cp.nome))
  );

-- ── 5. nome do papel = nome do cadastro (quando vinculado) ─────────────────
-- A lista de monitoria foi digitada à mão; o cadastro é a fonte boa.
update public.certificado_papeis cp
set nome = btrim(p.nome_completo)
from public.profiles p
where cp.profile_id = p.id
  and cp.tipo = 'monitoria'
  and cp.evento_id = (select id from public.eventos where nome = 'IX ENEON 2026')
  and coalesce(btrim(p.nome_completo), '') <> ''
  and cp.nome is distinct from btrim(p.nome_completo);

-- ── 6. conferência: os papéis de monitoria e o vínculo ────────────────────
-- "sem conta vinculada" não é erro: significa que a pessoa não tem cadastro de
-- sócia ou o nome está escrito diferente. Nesse caso o certificado sai pelo
-- botão "📜 Certificado" do admin, por e-mail.
select cp.nome,
       case when cp.profile_id is null then '❌ sem conta vinculada — sai por e-mail'
            else '✅ vinculado: ' || coalesce(p.email, '(conta)') end as vinculo,
       case when exists (
         select 1 from public.participacoes_evento pe
         where pe.profile_id = cp.profile_id and pe.evento_id = cp.evento_id
       ) then '✅ presença' else '— sem presença (roda participacao-para-quem-tem-papel)' end as presenca
from public.certificado_papeis cp
left join public.profiles p on p.id = cp.profile_id
where cp.evento_id = (select id from public.eventos where nome = 'IX ENEON 2026')
  and cp.tipo = 'monitoria'
order by cp.nome;

-- ── 7. conferência: o modelo de monitoria existe e está ativo? ────────────
-- Sem modelo ATIVO o certificado não aparece na área da sócia (o botão do
-- admin funciona mesmo com o modelo desativado).
select tipo, ativo, (base_path is not null) as tem_arte, left(texto_template, 80) as texto
from public.certificado_modelos
where evento_id = (select id from public.eventos where nome = 'IX ENEON 2026')
  and tipo = 'monitoria';
