-- Certificados de PROFESSOR (curso pré-encontro) e PALESTRANTE na área da sócia.
-- Pedido: se o professor/palestrante for sócio, o certificado dele também fica
-- disponível na área de sócios (liberação pelo interruptor geral do evento).
--
-- 1) inclui o tipo 'professor' nos CHECKs;
-- 2) semeia os 19 papéis do IX ENEON (7 professores + 12 palestrantes);
-- 3) semeia os modelos professor/palestrante reaproveitando arte+config do modelo de participação;
-- 4) vincula profile_id de quem já tem conta (por nome normalizado);
-- 5) SELECT de verificação no fim (rode e confira os vínculos).

-- ── 1. tipo 'professor' nos CHECKs ─────────────────────────────────────────
alter table public.certificado_modelos
  drop constraint if exists certificado_modelos_tipo_check;
alter table public.certificado_modelos
  add constraint certificado_modelos_tipo_check
  check (tipo in ('participacao','monitoria','oficina','palestrante','professor','comissao'));

alter table public.certificado_papeis
  drop constraint if exists certificado_papeis_tipo_check;
alter table public.certificado_papeis
  add constraint certificado_papeis_tipo_check
  check (tipo in ('palestrante','professor','comissao'));

-- ── 2. semear papéis (idempotente via NOT EXISTS) ──────────────────────────
insert into public.certificado_papeis (evento_id, tipo, nome, detalhe)
select e.id, v.tipo, v.nome, v.detalhe
from public.eventos e
cross join (values
  -- Professores dos cursos pré-encontro (15/07, 4h cada)
  ('professor','Ana Cláudia Monteiro','Punção venosa neonatal com realidade aumentada (VeinViewer®)'),
  ('professor','Anna Christina de Almeida Porréca','Manejo da HPP em cenários não hospitalares – Estabilização e Transporte Seguro'),
  ('professor','Reginaldo Lemos Soares','Interpretação de Laudos Ultrassonográficos em Obstetrícia'),
  ('professor','Ana Luiza Zapponi','Manejo Clínico dos Traumas Perineais associado à Laserterapia'),
  ('professor','José Antônio de Sá Neto','Termoproteção do Recém-nascido'),
  ('professor','Anna Christina de Almeida Porréca','Atualização em procedimentos de reconstrução perineal e segurança farmacológica'),
  ('professor','Michele de Lima Janotti Quaresma','Avaliação do RN em sala de parto e aplicação de Escalas para Exame Físico'),
  -- Palestrantes (conferencista + debatedores dos 3 painéis)
  ('palestrante','Marilanda Lopes de Lima','Cuidado perinatal especializado: impacto na qualidade e segurança da atenção materno-infantil'),
  ('palestrante','Mariana Moreira Tangari','Violência obstétrica: atualidades sobre os caminhos para a tipificação deste crime e a construção do conceito'),
  ('palestrante','Angela Mitrano Perazzini de Sá','Caminhos da implementação de políticas públicas de saúde na garantia do acesso ao cuidado'),
  ('palestrante','Ana Letícia Gomes','Direitos dos recém-nascidos no Brasil'),
  ('palestrante','Heloisa Lessa','Parto Domiciliar Planejado'),
  ('palestrante','Simone Pereira dos Santos','Casa de Parto'),
  ('palestrante','Renata Alves de Lima Nunes Barbosa','Maternidade hospitalar de natureza pública'),
  ('palestrante','José Felipe Riani Costa','Maternidade hospitalar de natureza suplementar/privada – ANS'),
  ('palestrante','Claudia Maria Messias','CEEO – Rede Alyne'),
  ('palestrante','Midian Oliveira Dias','Residência em Enfermagem Obstétrica'),
  ('palestrante','Marcele Sampaio de Freitas Guimarães Ribeiro','Residência em Enfermagem Neonatal'),
  ('palestrante','Isabelle Mangueira de Paula Gaspar','Residência Multiprofissional em Saúde da Mulher — HESFA/UFRJ')
) as v(tipo, nome, detalhe)
where e.nome = 'IX ENEON 2026'
  and not exists (
    select 1 from public.certificado_papeis cp
    where cp.evento_id = e.id and cp.tipo = v.tipo and cp.nome = v.nome
      and coalesce(cp.detalhe,'') = coalesce(v.detalhe,'')
  );

-- ── 3. semear modelos professor/palestrante (reaproveita arte+config do de participação) ──
insert into public.certificado_modelos (evento_id, tipo, base_path, texto_pre, texto_template, config, ativo)
select e.id, t.tipo, base.base_path, 'Certificamos que', t.template,
       coalesce(base.config, '{"fonte":"Calibri, Arial, sans-serif","cor":"#4a5866","margem":380,"pre_size":56,"nome_size":132,"corpo_size":62,"band_top":1020}'::jsonb),
       true
from public.eventos e
left join lateral (
  select base_path, config from public.certificado_modelos
  where evento_id = e.id and tipo = 'participacao' limit 1
) base on true
cross join (values
  ('professor', 'ministrou o curso pré-encontro "{{curso}}" no IX ENEON – IX Encontro de Enfermagem Obstétrica e Neonatal do Estado do Rio de Janeiro, realizado em 15 de julho de 2026, na UERJ, com carga horária de 4 horas.'),
  ('palestrante', 'atuou como palestrante no IX ENEON – IX Encontro de Enfermagem Obstétrica e Neonatal do Estado do Rio de Janeiro, apresentando "{{titulo_palestra}}", realizado de 15 a 17 de julho de 2026, na UERJ.')
) as t(tipo, template)
where e.nome = 'IX ENEON 2026'
  and not exists (
    select 1 from public.certificado_modelos m
    where m.evento_id = e.id and m.tipo = t.tipo
  );

-- ── 4. vincular profile_id por nome normalizado (só os ainda sem vínculo) ───
update public.certificado_papeis cp
set profile_id = p.id
from public.profiles p
where cp.profile_id is null
  and cp.tipo in ('professor','palestrante')
  and cp.evento_id = (select id from public.eventos where nome = 'IX ENEON 2026')
  and lower(translate(cp.nome,
        'ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇáàâãäéèêëíìîïóòôõöúùûüç',
        'AAAAAEEEEIIIIOOOOOUUUUCaaaaaeeeeiiiiooooouuuuc'))
    = lower(translate(p.nome_completo,
        'ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇáàâãäéèêëíìîïóòôõöúùûüç',
        'AAAAAEEEEIIIIOOOOOUUUUCaaaaaeeeeiiiiooooouuuuc'));

-- ── 5. verificação — rode e confira quem ficou vinculado ───────────────────
select cp.tipo, cp.nome, cp.detalhe,
  case when cp.profile_id is null then '❌ sem conta vinculada — verificar no admin'
       else '✅ vinculado: ' || coalesce(p.email, '(conta)') end as vinculo
from public.certificado_papeis cp
left join public.profiles p on p.id = cp.profile_id
where cp.evento_id = (select id from public.eventos where nome = 'IX ENEON 2026')
  and cp.tipo in ('professor','palestrante')
order by cp.tipo, cp.nome, cp.detalhe;
