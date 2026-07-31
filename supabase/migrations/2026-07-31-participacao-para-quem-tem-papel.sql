-- Declaração de participação para TODO MUNDO que tem papel no IX ENEON 2026.
--
-- Decisão da Sabrina em 31/07/2026: quem tem papel curado (palestrante,
-- professor, comissão, avaliador, assistente) esteve no evento e **deve
-- receber a declaração de participação** como qualquer participante.
--
-- Por que não recebiam: a declaração é travada na presença
-- (participacoes_evento), e quem tem papel NÃO aparece na lista de
-- credenciamento do admin — ou seja, não havia como marcar presente por lá.
--
-- Rode no SQL editor do Supabase, DEPOIS de 2026-07-31-avaliadores-todos.sql
-- (senão os avaliadores criados lá ficam de fora). Idempotente: pode rodar de
-- novo toda vez que cadastrar papéis novos.

-- ── 1. antes: quem vai ganhar presença agora ───────────────────────────────
select p.nome_completo, p.email, string_agg(distinct cp.tipo, ', ') as papeis
from public.certificado_papeis cp
join public.profiles p on p.id = cp.profile_id
where cp.evento_id = (select id from public.eventos where nome = 'IX ENEON 2026')
  and not exists (
    select 1 from public.participacoes_evento pe
    where pe.profile_id = p.id and pe.evento_id = cp.evento_id
  )
group by p.nome_completo, p.email
order by 1;

-- ── 2. registra a presença ─────────────────────────────────────────────────
insert into public.participacoes_evento (profile_id, evento_id)
select distinct cp.profile_id, cp.evento_id
from public.certificado_papeis cp
where cp.evento_id = (select id from public.eventos where nome = 'IX ENEON 2026')
  and cp.profile_id is not null
on conflict (profile_id, evento_id) do nothing;

-- ── 3. depois: confere que não sobrou ninguém ──────────────────────────────
-- Tem que voltar VAZIO.
select p.nome_completo, p.email, string_agg(distinct cp.tipo, ', ') as papeis
from public.certificado_papeis cp
join public.profiles p on p.id = cp.profile_id
where cp.evento_id = (select id from public.eventos where nome = 'IX ENEON 2026')
  and not exists (
    select 1 from public.participacoes_evento pe
    where pe.profile_id = p.id and pe.evento_id = cp.evento_id
  )
group by p.nome_completo, p.email
order by 1;

-- ── 4. papéis SEM conta vinculada — esses continuam sem nada na área ───────
-- Não é bug: sem conta de sócia não existe área logada. Para essas pessoas o
-- certificado (e a declaração) saem por fora, em PDF/e-mail. Se alguma delas
-- for sócia e só estiver com o nome escrito diferente, vincule pelo admin
-- (aba Certificados → papéis → campo de e-mail → "Vincular") e rode este
-- arquivo de novo.
select cp.tipo, cp.nome, coalesce(cp.detalhe, '—') as detalhe
from public.certificado_papeis cp
where cp.evento_id = (select id from public.eventos where nome = 'IX ENEON 2026')
  and cp.profile_id is null
order by cp.tipo, cp.nome;
