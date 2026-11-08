-- Ajusta as categorias de inscricao do ECOS DO ENEON: de socia/nao-socia
-- para as categorias reais da tabela de anuidade da ABENFO-RJ (ver
-- associe-se.html#valores):
--   Enfermeiros, Enfermeiras Obstetricas e Obstetrizes .... R$ 110,00
--   Auxiliar, Tecnico de Enfermagem e Estudante de Graduacao . R$ 60,00

alter table public.inscritos_externos
  drop constraint if exists inscritos_externos_categoria_check;
alter table public.inscritos_externos
  add constraint inscritos_externos_categoria_check
  check (categoria in ('enfermeiro_obstetriz', 'auxiliar_tecnico_estudante'));

create or replace function public.externo_inscrever_pix(
  p_evento_id uuid,
  p_nome text,
  p_email text,
  p_telefone text,
  p_categoria text,
  p_extensao text
) returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_codigo text;
  v_ext text;
  v_path text;
begin
  if p_categoria not in ('enfermeiro_obstetriz', 'auxiliar_tecnico_estudante') then
    return json_build_object('ok', false, 'erro', 'Categoria invalida.');
  end if;
  v_ext := lower(coalesce(p_extensao, 'pdf'));
  if v_ext not in ('pdf', 'jpg', 'jpeg', 'png') then
    return json_build_object('ok', false, 'erro', 'Extensao de arquivo invalida.');
  end if;

  select id, doity_id into v_id, v_codigo
    from public.inscritos_externos
    where evento_id = p_evento_id and lower(email) = lower(trim(p_email));

  if v_id is null then
    v_codigo := 'ECOS' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 7));
    v_id := gen_random_uuid();
    v_path := 'inscricoes/' || v_id || '.' || v_ext;
    insert into public.inscritos_externos (
      id, evento_id, nome, email, telefone, doity_id, categoria,
      comprovante_path, pago_confirmado
    ) values (
      v_id, p_evento_id, trim(p_nome), lower(trim(p_email)), trim(p_telefone), v_codigo, p_categoria,
      v_path, false
    );
  else
    v_path := 'inscricoes/' || v_id || '.' || v_ext;
    update public.inscritos_externos set
      nome = trim(p_nome),
      telefone = trim(p_telefone),
      categoria = p_categoria,
      comprovante_path = v_path,
      pago_confirmado = false,
      pago_confirmado_em = null,
      pago_confirmado_por = null
    where id = v_id;
  end if;

  return json_build_object(
    'ok', true,
    'inscrito_id', v_id,
    'codigo', v_codigo,
    'comprovante_path', v_path
  );
exception when others then
  return json_build_object('ok', false, 'erro', sqlerrm);
end $$;

grant execute on function public.externo_inscrever_pix(uuid, text, text, text, text, text) to anon, authenticated;
