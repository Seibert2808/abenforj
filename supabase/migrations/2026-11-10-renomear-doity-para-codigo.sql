-- O ECOS DO ENEON 2026 nao usa Doity (inscricao e via PIX, com codigo gerado
-- em externo_inscrever_pix). As mensagens de erro de externo_meu_painel e
-- externo_meus_trabalhos ainda citavam "numero Doity (formato DOI-XXXXXXXXX)",
-- o que confunde quem se inscreveu pelo PIX. Mantem a logica identica, so
-- troca o texto da mensagem para algo generico (vale tanto pra quem usa
-- Doity quanto pra quem usa o codigo gerado).

create or replace function public.externo_meu_painel(
  p_email text,
  p_doity_id text
) returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_inscrito record;
  v_cursos json;
begin
  select id, evento_id, nome, email, doity_id
    into v_inscrito
    from public.inscritos_externos
    where lower(email) = lower(trim(p_email))
      and doity_id = upper(trim(p_doity_id))
    limit 1;

  if v_inscrito is null then
    return json_build_object('ok', false, 'erro', 'Inscricao nao encontrada. Confira o email e o codigo da inscricao.');
  end if;

  select json_agg(json_build_object(
    'id', c.id,
    'nome', c.nome,
    'turno', c.turno,
    'data', c.data,
    'local', c.local
  ) order by c.data, c.turno)
    into v_cursos
    from public.inscricoes_curso ic
    join public.cursos c on c.id = ic.curso_id
    where ic.inscrito_externo_id = v_inscrito.id;

  return json_build_object(
    'ok', true,
    'inscrito', json_build_object(
      'id', v_inscrito.id,
      'evento_id', v_inscrito.evento_id,
      'nome', v_inscrito.nome
    ),
    'cursos', coalesce(v_cursos, '[]'::json)
  );
end $$;

grant execute on function public.externo_meu_painel(text, text) to anon, authenticated;

create or replace function public.externo_meus_trabalhos(p_email text, p_doity_id text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ins record;
  v_trabs json;
begin
  select * into v_ins from public._externo_lookup(p_email, p_doity_id);
  if v_ins is null then
    return json_build_object('ok', false, 'erro', 'Inscricao nao encontrada. Confira o email e o codigo da inscricao.');
  end if;

  select json_agg(json_build_object(
    'id', t.id,
    'titulo', t.titulo,
    'area', t.area,
    'eixo_tematico', t.eixo_tematico,
    'tipo_trabalho', t.tipo_trabalho,
    'resumo', t.resumo,
    'cep_caae', t.cep_caae,
    'ceua', t.ceua,
    'referencias', t.referencias,
    'descritores', t.descritores,
    'autores', t.autores,
    'pdf_path', t.pdf_path,
    'status', t.status,
    'bloqueado', t.bloqueado,
    'observacao_avaliacao', t.observacao_avaliacao,
    'submetido_em', t.submetido_em,
    'concorre_premio', t.concorre_premio,
    'correcao_enviada_em', t.correcao_enviada_em,
    'apresentacao_enviada_em', t.apresentacao_enviada_em
  ) order by t.submetido_em desc)
  into v_trabs
  from public.trabalhos_cientificos t
  where t.inscrito_externo_id = v_ins.id;

  return json_build_object(
    'ok', true,
    'inscrito', json_build_object(
      'id', v_ins.id,
      'evento_id', v_ins.evento_id,
      'nome', v_ins.nome,
      'email', v_ins.email
    ),
    'trabalhos', coalesce(v_trabs, '[]'::json)
  );
end $$;

grant execute on function public.externo_meus_trabalhos(text, text) to anon, authenticated;
