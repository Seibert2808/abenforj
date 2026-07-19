-- Ajustes nos papéis de certificado do IX ENEON 2026 — 19/07/2026
-- 1) Corrige o título da palestra da Isabelle (pedido da autora: sem "— HESFA/UFRJ").
-- 2) Cadastra a Apresentação Musical de Encerramento como palestrante
--    (Anna Christina Porréca + Rubem Figueiredo Sadok Menna Barreto),
--    detalhe "Musical de Encerramento".
-- Idempotente e seguro de rodar mais de uma vez. Rode no SQL editor do Supabase.
-- Depois, ligue o interruptor "certificados_liberados" do evento no admin.

-- ── 1. Título da Residência Multiprofissional (sem HESFA/UFRJ) ──────────────
update public.certificado_papeis cp
set detalhe = 'Residência Multiprofissional em Saúde da Mulher'
from public.eventos e
where cp.evento_id = e.id
  and e.nome = 'IX ENEON 2026'
  and cp.tipo = 'palestrante'
  and cp.nome = 'Isabelle Mangueira de Paula Gaspar';

-- ── 2. Apresentação Musical de Encerramento (2 papéis) ─────────────────────
insert into public.certificado_papeis (evento_id, tipo, nome, detalhe)
select e.id, v.tipo, v.nome, v.detalhe
from public.eventos e
cross join (values
  ('palestrante','Anna Christina de Almeida Porréca','Musical de Encerramento'),
  ('palestrante','Rubem Figueiredo Sadok Menna Barreto','Musical de Encerramento')
) as v(tipo, nome, detalhe)
where e.nome = 'IX ENEON 2026'
  and not exists (
    select 1 from public.certificado_papeis cp
    where cp.evento_id = e.id and cp.tipo = v.tipo and cp.nome = v.nome
      and coalesce(cp.detalhe,'') = coalesce(v.detalhe,'')
  );

-- ── 3. Vincular profile_id por nome normalizado (só os ainda sem vínculo) ───
update public.certificado_papeis cp
set profile_id = p.id
from public.profiles p
where cp.profile_id is null
  and cp.tipo = 'palestrante'
  and cp.evento_id = (select id from public.eventos where nome = 'IX ENEON 2026')
  and lower(translate(cp.nome,
        'ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇáàâãäéèêëíìîïóòôõöúùûüç',
        'AAAAAEEEEIIIIOOOOOUUUUCaaaaaeeeeiiiiooooouuuuc'))
    = lower(translate(p.nome_completo,
        'ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇáàâãäéèêëíìîïóòôõöúùûüç',
        'AAAAAEEEEIIIIOOOOOUUUUCaaaaaeeeeiiiiooooouuuuc'));

-- ── 4. Verificação — rode e confira a lista final de palestrantes ──────────
select cp.nome, cp.detalhe,
  case when cp.profile_id is null then '❌ sem conta vinculada'
       else '✅ vinculado' end as vinculo
from public.certificado_papeis cp
where cp.evento_id = (select id from public.eventos where nome = 'IX ENEON 2026')
  and cp.tipo = 'palestrante'
order by cp.nome, cp.detalhe;
