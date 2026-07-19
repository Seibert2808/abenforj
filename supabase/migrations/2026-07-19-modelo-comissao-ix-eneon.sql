-- Certificados de COMISSÃO / ORGANIZAÇÃO do IX ENEON 2026 — 19/07/2026
-- 1) modelo (reaproveita arte+config do de participação; {{comissao}} vem do detalhe);
-- 2) 9 papéis da organização (nome inserido "plano" p/ vincular, depois recebe o título);
-- 3) vínculo por nome; 4) título nos nomes; 5) conferência.
-- Idempotente. Rode no SQL editor do Supabase.

-- ── 1. Modelo de comissão ──────────────────────────────────────────────────
insert into public.certificado_modelos (evento_id, tipo, base_path, texto_pre, texto_template, config, ativo)
select e.id, 'comissao', base.base_path, 'Certificamos que',
  'integrou a {{comissao}} do IX ENEON – IX Encontro de Enfermagem Obstétrica e Neonatal do Estado do Rio de Janeiro, realizado de 15 a 17 de julho de 2026, na UERJ.',
  coalesce(base.config, '{"cor":"#4a5866","fonte":"Calibri, Arial, sans-serif","margem":380,"band_top":1000,"pre_size":56,"nome_size":130,"corpo_size":64}'::jsonb),
  true
from public.eventos e
left join lateral (
  select base_path, config from public.certificado_modelos
  where evento_id = e.id and tipo = 'participacao' limit 1
) base on true
where e.nome = 'IX ENEON 2026'
on conflict (evento_id, tipo) do update
  set base_path = excluded.base_path, texto_pre = excluded.texto_pre,
      texto_template = excluded.texto_template, config = excluded.config, ativo = true;

-- ── 2. Papéis da organização (nome plano; guarda-se contra duplicar) ───────
insert into public.certificado_papeis (evento_id, tipo, nome, detalhe)
select e.id, 'comissao', d.plano, d.comissao
from public.eventos e
cross join (values
  ('Marcele Zveiter',                     'Profª Drª Marcele Zveiter',                     'Comissão Executiva'),
  ('Sabrina Seibert',                     'Profª Drª Sabrina Seibert',                     'Comissão Executiva'),
  ('Débora Cecília Chaves de Oliveira',   'Profª Drª Débora Cecília Chaves de Oliveira',   'Comissão Científica'),
  ('Anna Christina de Almeida Porréca',   'Profª Ma. Anna Christina de Almeida Porréca',   'Comissão Científica'),
  ('Midian Oliveira Dias',                'Profª Drª Midian Oliveira Dias',                'Comissão de Infraestrutura'),
  ('Michele de Lima Janotti Quaresma',    'Profª Ma. Michele de Lima Janotti Quaresma',    'Comissão de Secretaria'),
  ('Alan Messala de Aguiar Britto',       'Prof. Dr. Alan Messala de Aguiar Britto',       'Apoio ao Estudante e Monitoria'),
  ('Ana Beatriz Morais',                  'Acd. Enf. Ana Beatriz Morais',                  'Apoio ao Estudante e Monitoria'),
  ('Sabrina Seibert',                     'Profª Drª Sabrina Seibert',                     'Comissão de Divulgação')
) as d(plano, titulado, comissao)
where e.nome = 'IX ENEON 2026'
  and not exists (
    select 1 from public.certificado_papeis cp
    where cp.evento_id = e.id and cp.tipo = 'comissao' and cp.detalhe = d.comissao
      and cp.nome in (d.plano, d.titulado)
  );

-- ── 3. Vincular profile_id por nome normalizado (só os sem vínculo) ────────
update public.certificado_papeis cp
set profile_id = p.id
from public.profiles p
where cp.profile_id is null and cp.tipo = 'comissao'
  and cp.evento_id = (select id from public.eventos where nome = 'IX ENEON 2026')
  and lower(translate(cp.nome,
        'ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇáàâãäéèêëíìîïóòôõöúùûüç',
        'AAAAAEEEEIIIIOOOOOUUUUCaaaaaeeeeiiiiooooouuuuc'))
    = lower(translate(p.nome_completo,
        'ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇáàâãäéèêëíìîïóòôõöúùûüç',
        'AAAAAEEEEIIIIOOOOOUUUUCaaaaaeeeeiiiiooooouuuuc'));

-- ── 4. Título nos nomes (após o vínculo) ───────────────────────────────────
update public.certificado_papeis cp set nome = d.titulado
from (values
  ('Marcele Zveiter',                     'Profª Drª Marcele Zveiter'),
  ('Sabrina Seibert',                     'Profª Drª Sabrina Seibert'),
  ('Débora Cecília Chaves de Oliveira',   'Profª Drª Débora Cecília Chaves de Oliveira'),
  ('Anna Christina de Almeida Porréca',   'Profª Ma. Anna Christina de Almeida Porréca'),
  ('Midian Oliveira Dias',                'Profª Drª Midian Oliveira Dias'),
  ('Michele de Lima Janotti Quaresma',    'Profª Ma. Michele de Lima Janotti Quaresma'),
  ('Alan Messala de Aguiar Britto',       'Prof. Dr. Alan Messala de Aguiar Britto'),
  ('Ana Beatriz Morais',                  'Acd. Enf. Ana Beatriz Morais')
) as d(plano, titulado)
where cp.tipo = 'comissao' and cp.nome = d.plano
  and cp.evento_id = (select id from public.eventos where nome = 'IX ENEON 2026');

-- ── 5. Conferência ─────────────────────────────────────────────────────────
select cp.nome, cp.detalhe as comissao,
  case when cp.profile_id is null then '❌ e-mail (sem conta)' else '✅ área da sócia' end as entrega
from public.certificado_papeis cp
where cp.evento_id = (select id from public.eventos where nome = 'IX ENEON 2026')
  and cp.tipo = 'comissao'
order by cp.detalhe, cp.nome;
