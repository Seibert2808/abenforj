-- Vincular as monitoras que sobraram sem conta: Gleicia e Rebeca.
--
-- Contexto (14/08/2026): depois de 2026-08-14-papel-monitoria.sql, só esses dois
-- papéis de monitoria ficaram com profile_id nulo. O nome no cadastro é escrito
-- diferente do nome da lista de monitoria, então o casamento automático por
-- nome normalizado não pega (a migração 2026-07-09-marcar-monitores-parte2.sql
-- já tinha topado com as mesmas duas).
--
-- Sem conta vinculada elas não veem nada na área logada e não entram na regra
-- "quem tem papel recebe participação". O certificado delas sairia só pelo
-- botão 📜 do admin.
--
-- Rode no SQL editor, uma etapa de cada vez.

-- ── A) achar as contas ─────────────────────────────────────────────────────
-- Anote os e-mails que aparecerem aqui, é o que a etapa B usa.
select p.id, p.nome_completo, p.email,
       (ie.id is not null) as tem_inscricao_ix_eneon,
       ie.observacao
from public.profiles p
left join public.inscricoes_evento ie
  on ie.profile_id = p.id
 and ie.evento_id = (select id from public.eventos where nome = 'IX ENEON 2026')
where public.f_norm_titulo(coalesce(p.nome_completo, p.nome_social))
      ~ '(gleicia|rebeca .*(guimaraes|silva))'
order by p.nome_completo;

-- ── B) vincular pelo e-mail ────────────────────────────────────────────────
-- TROQUE os dois e-mails abaixo pelos que vieram da etapa A e rode.
-- Se alguma delas não tiver conta de sócia, deixe a linha dela de fora: o
-- certificado sai pelo botão 📜 Certificado do admin, por e-mail.
update public.certificado_papeis cp
set profile_id = p.id
from public.profiles p
where cp.evento_id = (select id from public.eventos where nome = 'IX ENEON 2026')
  and cp.tipo = 'monitoria'
  and cp.profile_id is null
  and (
    (public.f_norm_titulo(cp.nome) = public.f_norm_titulo('Gleicia da Cruz Paes')
     and lower(p.email) = lower('EMAIL_DA_GLEICIA'))
    or
    (public.f_norm_titulo(cp.nome) = public.f_norm_titulo('Rebeca da Silva Guimarães dos Santos')
     and lower(p.email) = lower('EMAIL_DA_REBECA'))
  );

-- ── C) alinhar nome e presença (as mesmas etapas 5 e da participação) ──────
-- O nome do papel passa a ser o do cadastro, e quem tem papel ganha presença.
update public.certificado_papeis cp
set nome = btrim(p.nome_completo)
from public.profiles p
where cp.profile_id = p.id
  and cp.tipo = 'monitoria'
  and cp.evento_id = (select id from public.eventos where nome = 'IX ENEON 2026')
  and coalesce(btrim(p.nome_completo), '') <> ''
  and cp.nome is distinct from btrim(p.nome_completo);

insert into public.participacoes_evento (profile_id, evento_id)
select distinct cp.profile_id, cp.evento_id
from public.certificado_papeis cp
where cp.evento_id = (select id from public.eventos where nome = 'IX ENEON 2026')
  and cp.profile_id is not null
on conflict (profile_id, evento_id) do nothing;

-- ── D) conferência final ───────────────────────────────────────────────────
select cp.nome,
       case when cp.profile_id is null then '❌ sem conta — sai pelo botão do admin'
            else '✅ ' || coalesce(p.email, '(conta)') end as vinculo
from public.certificado_papeis cp
left join public.profiles p on p.id = cp.profile_id
where cp.evento_id = (select id from public.eventos where nome = 'IX ENEON 2026')
  and cp.tipo = 'monitoria'
order by cp.profile_id nulls first, cp.nome;
