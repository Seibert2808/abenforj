-- Papel de AVALIADOR para todos os avaliadores do IX ENEON 2026.
--
-- Contexto (31/07/2026): a consulta de trabalhos_avaliacao devolveu 7 nomes —
-- Anna Porréca (30), Julianne Feijoli (20), Sabrina Seiberth (19),
-- José Antonio (18), Isis Nazareth (16), Carla Shubert (10), Adriana Reis (6).
--
-- Dois problemas com esses nomes:
--   • são CURTOS (primeiro nome + sobrenome), não servem para o certificado;
--   • alguns têm ERRO DE DIGITAÇÃO ("Sabrina Seiberth", "Carla Shubert").
-- Por isso o papel NÃO é criado com o texto de trabalhos_avaliacao: o script
-- procura a pessoa em profiles e usa o NOME COMPLETO DO CADASTRO, já com o
-- profile_id vinculado (é o que faz o certificado aparecer na área da sócia).
--
-- Casamento tolerante: primeiro nome inteiro + as 5 primeiras letras do último
-- sobrenome ("seiberth" → "seibe" acha "Sabrina Lins Seibert"). Só cria o papel
-- quando o casamento é ÚNICO — nome ambíguo ou sem casamento fica de fora e sai
-- listado no passo 3, para você cadastrar à mão no admin com o nome certo.
--
-- Rode no SQL editor do Supabase, DEPOIS de
-- 2026-07-31-certificados-avaliador-e-assistente.sql. Idempotente.

-- ── 1. diagnóstico: quem casou com qual cadastro ───────────────────────────
with ev as (select id from public.eventos where nome = 'IX ENEON 2026'),
aval as (
  select distinct trim(ta.avaliador_nome) as nome_bruto,
         public.f_norm_titulo(ta.avaliador_nome) as n
  from public.trabalhos_avaliacao ta
  join public.trabalhos_cientificos t on t.id = ta.trabalho_id
  where t.evento_id = (select id from ev)
    and coalesce(trim(ta.avaliador_nome), '') <> ''
),
tok as (
  select nome_bruto, n,
         split_part(n, ' ', 1) as prim,
         left(regexp_replace(n, '^.*\s', ''), 5) as ult5
  from aval
),
cand as (
  select k.nome_bruto, p.id as profile_id, p.nome_completo, p.email
  from tok k
  join public.profiles p
    on position(k.prim in public.f_norm_titulo(p.nome_completo)) > 0
   and position(k.ult5 in public.f_norm_titulo(p.nome_completo)) > 0
)
select a.nome_bruto as nome_na_avaliacao,
       count(c.profile_id) as cadastros_encontrados,
       coalesce(string_agg(c.nome_completo || ' <' || coalesce(c.email,'') || '>', ' | '), '—') as candidatos,
       case when count(c.profile_id) = 1 then '✅ vai virar papel com o nome do cadastro'
            when count(c.profile_id) = 0 then '⚠️ sem cadastro — cadastrar à mão no admin'
            else '⚠️ ambíguo — cadastrar à mão no admin' end as acao
from aval a
left join cand c on c.nome_bruto = a.nome_bruto
group by a.nome_bruto
order by a.nome_bruto;

-- ── 2. cria os papéis dos que casaram sozinhos ─────────────────────────────
with ev as (select id from public.eventos where nome = 'IX ENEON 2026'),
aval as (
  select distinct trim(ta.avaliador_nome) as nome_bruto,
         public.f_norm_titulo(ta.avaliador_nome) as n
  from public.trabalhos_avaliacao ta
  join public.trabalhos_cientificos t on t.id = ta.trabalho_id
  where t.evento_id = (select id from ev)
    and coalesce(trim(ta.avaliador_nome), '') <> ''
),
tok as (
  select nome_bruto, split_part(n, ' ', 1) as prim,
         left(regexp_replace(n, '^.*\s', ''), 5) as ult5
  from aval
),
cand as (
  select k.nome_bruto, p.id as profile_id, p.nome_completo
  from tok k
  join public.profiles p
    on position(k.prim in public.f_norm_titulo(p.nome_completo)) > 0
   and position(k.ult5 in public.f_norm_titulo(p.nome_completo)) > 0
),
unico as (
  select nome_bruto, min(profile_id::text)::uuid as profile_id, min(nome_completo) as nome_completo
  from cand group by nome_bruto having count(*) = 1
)
insert into public.certificado_papeis (evento_id, tipo, nome, detalhe, profile_id)
select (select id from ev), 'avaliador', u.nome_completo, null, u.profile_id
from unico u
where not exists (   -- já tem papel de avaliador (por conta OU por nome)
  select 1 from public.certificado_papeis cp
  where cp.evento_id = (select id from ev) and cp.tipo = 'avaliador'
    and (cp.profile_id = u.profile_id
         or public.f_norm_titulo(cp.nome) = public.f_norm_titulo(u.nome_completo))
);

-- ── 3. quem NÃO virou papel (cadastrar à mão) ──────────────────────────────
-- Admin → aba Certificados → "Palestrantes, professores, avaliadores e
-- assistentes (papéis)" → tipo "Avaliador de trabalhos" → nome completo correto
-- + e-mail da sócia (o e-mail vincula a conta e joga o certificado na área dela).
with ev as (select id from public.eventos where nome = 'IX ENEON 2026'),
aval as (
  select distinct trim(ta.avaliador_nome) as nome_bruto,
         public.f_norm_titulo(ta.avaliador_nome) as n
  from public.trabalhos_avaliacao ta
  join public.trabalhos_cientificos t on t.id = ta.trabalho_id
  where t.evento_id = (select id from ev)
    and coalesce(trim(ta.avaliador_nome), '') <> ''
),
tok as (
  select nome_bruto, split_part(n, ' ', 1) as prim,
         left(regexp_replace(n, '^.*\s', ''), 5) as ult5
  from aval
)
select k.nome_bruto as ainda_sem_papel
from tok k
where not exists (
  select 1 from public.certificado_papeis cp
  where cp.evento_id = (select id from ev) and cp.tipo = 'avaliador'
    and position(k.prim in public.f_norm_titulo(cp.nome)) > 0
    and position(k.ult5 in public.f_norm_titulo(cp.nome)) > 0
)
order by 1;

-- ── 4. conferência final — papéis novos (avaliador + assistente) ───────────
select cp.tipo, cp.nome, coalesce(cp.detalhe, '—') as detalhe,
  case when cp.profile_id is null then '❌ sem conta — certificado sai por e-mail'
       else '✅ na área da sócia: ' || coalesce(p.email, '(conta)') end as entrega
from public.certificado_papeis cp
left join public.profiles p on p.id = cp.profile_id
where cp.evento_id = (select id from public.eventos where nome = 'IX ENEON 2026')
  and cp.tipo in ('avaliador','assistente')
order by cp.tipo, cp.nome;

-- ── 5. OPCIONAL — declaração de participação de quem tem papel ─────────────
-- A consulta de "papel sem presença" devolveu 3 pessoas:
--   Débora Cecília Chaves de Oliveira (comissão)
--   Michele de Lima Janotti Quaresma (comissão, professor)
--   Renata Alves de Lima Nunes Barbosa (palestrante)
-- Nenhuma recebe a DECLARAÇÃO DE PARTICIPAÇÃO, porque papel não é presença.
-- Só rode se as três realmente estiveram no evento (tire da lista quem não foi).
-- Descomente:
--
-- insert into public.participacoes_evento (profile_id, evento_id)
-- select p.id, e.id
-- from public.profiles p
-- cross join public.eventos e
-- where e.nome = 'IX ENEON 2026'
--   and p.email in (
--     'ceciliadeby@gmail.com',
--     'michelleljqrj@hotmail.com',
--     'tinha_18@yahoo.com.br'
--   )
-- on conflict (profile_id, evento_id) do nothing;
--
-- Os avaliadores criados no passo 2 entram na mesma situação (papel, sem
-- presença). Para ver a lista atualizada, rode de novo a consulta D da migração
-- 2026-07-31-jose-antonio-participacao-e-coautoria.sql.
