-- José Antônio de Sá Neto — certificados que faltavam no IX ENEON 2026.
-- Pedido da Sabrina em 31/07/2026: ele só recebeu o de PROFESSOR (curso
-- ministrado). Faltavam participação, coautoria em trabalhos e avaliador.
-- (O de avaliador está em 2026-07-31-certificados-avaliador-e-assistente.sql.)
--
-- Diagnóstico das duas causas tratadas aqui:
--
--  A) PARTICIPAÇÃO — a declaração exige presença em participacoes_evento, e
--     quem tem papel (palestrante/professor/comissão) NÃO aparece na lista de
--     credenciamento do admin. Ou seja: professor que deu curso e ficou no
--     evento não tinha como ser marcado presente. Ele foi.
--
--  B) COAUTORIA — a RPC certificados_trabalho_socio casa o coautor pelo
--     e-mail: ou a chave "email" do autor, ou o e-mail da conta aparecendo
--     dentro do campo livre "info" (rotulado "E-mail / Instituição" no
--     formulário de submissão). Quem preencheu "info" só com a instituição
--     — ou com um e-mail diferente do da conta — fica invisível. A correção
--     grava a chave "email" na entrada dele da lista de autores, que é
--     exatamente o que a RPC procura primeiro. Não mexe em "info", nem em
--     "eh_relator", nem no texto do trabalho.
--
-- Rode no SQL editor do Supabase, DEPOIS de
-- 2026-07-31-certificados-avaliador-e-assistente.sql.
-- Idempotente. Os SELECTs de diagnóstico ficam antes e depois de cada correção:
-- rode tudo e confira os resultados.

-- ═══ A. PARTICIPAÇÃO ═══════════════════════════════════════════════════════

-- A1. Antes: ele tem presença registrada?
select p.nome_completo, p.email,
  case when exists (
    select 1 from public.participacoes_evento pe
    where pe.profile_id = p.id
      and pe.evento_id = (select id from public.eventos where nome = 'IX ENEON 2026')
  ) then '✅ já tinha presença' else '❌ sem presença — vai ser inserida abaixo' end as antes
from public.profiles p
where public.f_norm_titulo(p.nome_completo) = public.f_norm_titulo('José Antônio de Sá Neto');

-- A2. Registra a presença dele no IX ENEON.
insert into public.participacoes_evento (profile_id, evento_id)
select p.id, e.id
from public.profiles p
cross join public.eventos e
where e.nome = 'IX ENEON 2026'
  and public.f_norm_titulo(p.nome_completo) = public.f_norm_titulo('José Antônio de Sá Neto')
on conflict (profile_id, evento_id) do nothing;

-- ═══ B. COAUTORIA EM TRABALHOS ═════════════════════════════════════════════

-- B1. Antes: em quais trabalhos ele aparece como autor, e por que não casava.
--     Confira status ('aceito'/'aceito_com_ressalva') e apresentado = true —
--     sem os dois, NÃO existe certificado de trabalho, e a correção B2 não
--     resolve (nesse caso é marcar "apresentado" no admin).
select t.titulo, t.status, t.apresentado,
       a->>'nome' as autor, a->>'info' as info_preenchida,
       a->>'email' as chave_email,
       case when a->>'eh_relator' = 'true' then 'relator' else 'coautor' end as papel_no_trabalho,
       case
         when lower(coalesce(a->>'email','')) = lower(p.email) then '✅ já casava pela chave email'
         when position(lower(p.email) in lower(coalesce(a->>'info',''))) > 0 then '✅ já casava pelo info'
         else '❌ não casava — corrigido no B2'
       end as situacao
from public.trabalhos_cientificos t
cross join lateral jsonb_array_elements(coalesce(t.autores, '[]'::jsonb)) a
cross join public.profiles p
where t.evento_id = (select id from public.eventos where nome = 'IX ENEON 2026')
  and public.f_norm_titulo(p.nome_completo) = public.f_norm_titulo('José Antônio de Sá Neto')
  and public.f_norm_titulo(a->>'nome') like '%sa neto%'
order by t.titulo;

-- B2. Grava a chave "email" da conta dele nas entradas de autor que são dele.
--     Reescreve a lista de autores preservando a ordem e todas as outras chaves.
update public.trabalhos_cientificos t
set autores = sub.novo
from (
  select t2.id,
         (select jsonb_agg(
                   case when public.f_norm_titulo(a->>'nome') like '%sa neto%'
                        then a || jsonb_build_object('email', j.email)
                        else a end
                   order by ord)
          from jsonb_array_elements(t2.autores) with ordinality as e(a, ord)) as novo
  from public.trabalhos_cientificos t2
  cross join (
    select p.email from public.profiles p
    where public.f_norm_titulo(p.nome_completo) = public.f_norm_titulo('José Antônio de Sá Neto')
    limit 1
  ) j
  where t2.evento_id = (select id from public.eventos where nome = 'IX ENEON 2026')
    and exists (
      select 1 from jsonb_array_elements(coalesce(t2.autores, '[]'::jsonb)) a
      where public.f_norm_titulo(a->>'nome') like '%sa neto%'
        and lower(coalesce(a->>'email','')) <> lower(j.email)
    )
) sub
where t.id = sub.id;

-- ═══ C. VERIFICAÇÃO FINAL — o que ele passa a ver na área da sócia ═════════
-- Espere: 1 linha "participação", 1 "professor", 1 "avaliador" e 1 linha por
-- trabalho aceito+apresentado em que ele é autor.
with ev as (select id from public.eventos where nome = 'IX ENEON 2026' and certificados_liberados = true),
     jose as (
       select p.id, p.email, p.nome_completo from public.profiles p
       where public.f_norm_titulo(p.nome_completo) = public.f_norm_titulo('José Antônio de Sá Neto')
       limit 1
     )
select 'participação' as certificado, '(nome da conta)' as detalhe
from jose j
where exists (select 1 from public.participacoes_evento pe where pe.profile_id = j.id and pe.evento_id = (select id from ev))
  and exists (select 1 from public.certificado_modelos m where m.evento_id = (select id from ev) and m.tipo = 'participacao' and m.ativo)
union all
select cp.tipo, coalesce(cp.detalhe, '—')
from public.certificado_papeis cp, jose j
where cp.profile_id = j.id and cp.evento_id = (select id from ev)
  and exists (select 1 from public.certificado_modelos m where m.evento_id = cp.evento_id and m.tipo = cp.tipo and m.ativo)
union all
select 'trabalho (' || case when lower(coalesce(t.relator_email,'')) = lower(j.email) then 'apresentação' else 'coautoria' end || ')', t.titulo
from public.trabalhos_cientificos t, jose j
where t.evento_id = (select id from ev)
  and t.status in ('aceito','aceito_com_ressalva')
  and t.apresentado = true
  and exists (
    select 1 from jsonb_array_elements(coalesce(t.autores,'[]'::jsonb)) a
    where lower(coalesce(a->>'email','')) = lower(j.email)
       or position(lower(j.email) in lower(coalesce(a->>'info',''))) > 0
  );

-- ═══ D. INFORMATIVO — o mesmo furo em outras pessoas ══════════════════════
-- Quem tem papel curado (palestrante/professor/comissão/avaliador) vinculado a
-- uma conta e NÃO tem presença registrada. Todos estiveram no evento, mas
-- nenhum recebe a declaração de participação. Decida caso a caso: para liberar,
-- é o mesmo insert do A2 trocando o nome (ou marcar presença no admin).
select distinct p.nome_completo, p.email, string_agg(distinct cp.tipo, ', ') as papeis
from public.certificado_papeis cp
join public.profiles p on p.id = cp.profile_id
where cp.evento_id = (select id from public.eventos where nome = 'IX ENEON 2026')
  and not exists (
    select 1 from public.participacoes_evento pe
    where pe.profile_id = p.id and pe.evento_id = cp.evento_id
  )
group by p.nome_completo, p.email
order by 1;
