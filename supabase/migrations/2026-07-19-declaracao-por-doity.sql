-- Declaração de participação por NÚMERO DO DOITY (para não-sócios presentes).
-- Página pública "declaracao.html": o participante externo digita o DOI-XXXX e baixa o PDF.
-- Só retorna dados quando TODAS as condições valem:
--   • é inscrito externo do IX ENEON e não cancelado;
--   • tem PRESENÇA registrada (participantes_externos.inscrito_externo_id);
--   • o evento está com certificados_liberados = true;
--   • o modelo de participação está ativo.
-- SECURITY DEFINER porque inscritos_externos / participantes_externos têm RLS de admin.
-- Expõe só o necessário para montar o certificado da própria pessoa (nada de e-mail/telefone).

create or replace function public.declaracao_participacao_por_doity(p_doity text)
returns table (nome text, texto_pre text, texto_template text, base_path text, config jsonb)
language sql
security definer
set search_path = public
as $$
  select ie.nome, m.texto_pre, m.texto_template, m.base_path, m.config
  from public.inscritos_externos ie
  join public.eventos e  on e.id = ie.evento_id
  join public.participantes_externos pe on pe.inscrito_externo_id = ie.id and pe.evento_id = e.id
  join public.certificado_modelos m on m.evento_id = e.id and m.tipo = 'participacao' and m.ativo = true
  where e.nome = 'IX ENEON 2026'
    and e.certificados_liberados = true
    and ie.cancelado = false
    and length(regexp_replace(coalesce(p_doity, ''),     '[^A-Za-z0-9]', '', 'g')) >= 4
    and length(regexp_replace(coalesce(ie.doity_id, ''), '[^A-Za-z0-9]', '', 'g')) >= 4
    and upper(regexp_replace(coalesce(ie.doity_id, ''), '[^A-Za-z0-9]', '', 'g'))
      = upper(regexp_replace(coalesce(p_doity, ''),     '[^A-Za-z0-9]', '', 'g'))
  limit 1;
$$;

grant execute on function public.declaracao_participacao_por_doity(text) to anon, authenticated;
