-- Corrige a regra: status='ativo' sozinho nao basta. Pra ganhar a
-- inscricao gratuita no Ecos do Eneon, a socia precisa estar com a
-- anuidade especificamente de 2027 paga (ano_vigencia >= 2027) -- quem
-- renovou so ate 2026 nao conta.

create or replace function public.associada_inscrever_evento(p_evento_id uuid)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_status text;
  v_ano int;
begin
  if v_uid is null then
    return json_build_object('ok', false, 'erro', 'Nao autenticada.');
  end if;

  select status, ano_vigencia into v_status, v_ano
    from public.profiles where id = v_uid;

  if v_status is distinct from 'ativo' or coalesce(v_ano, 0) < 2027 then
    return json_build_object('ok', false, 'erro', 'E preciso estar com a anuidade de 2027 em dia para se inscrever no Ecos do Eneon.');
  end if;

  insert into public.inscricoes_evento (profile_id, evento_id, observacao, created_by)
  values (v_uid, p_evento_id, 'Inscricao pela area da associada', v_uid)
  on conflict (profile_id, evento_id) do nothing;

  return json_build_object('ok', true);
end $$;

grant execute on function public.associada_inscrever_evento(uuid) to authenticated;
