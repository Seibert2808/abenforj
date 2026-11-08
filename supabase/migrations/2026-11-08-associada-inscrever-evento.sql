-- Autoinscricao da socia em um evento (gratuita, sob pedido dela mesma).
-- Nao acontece automaticamente ao aprovar/renovar anuidade -- a socia
-- precisa explicitamente clicar em "Inscrever-se" na area dela
-- (/area/cursos.html). So funciona pra quem esta com status ativo.

create or replace function public.associada_inscrever_evento(p_evento_id uuid)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_status text;
begin
  if v_uid is null then
    return json_build_object('ok', false, 'erro', 'Nao autenticada.');
  end if;

  select status into v_status from public.profiles where id = v_uid;
  if v_status is distinct from 'ativo' then
    return json_build_object('ok', false, 'erro', 'Sua associacao nao esta ativa no momento.');
  end if;

  insert into public.inscricoes_evento (profile_id, evento_id, observacao, created_by)
  values (v_uid, p_evento_id, 'Inscricao pela area da associada', v_uid)
  on conflict (profile_id, evento_id) do nothing;

  return json_build_object('ok', true);
end $$;

grant execute on function public.associada_inscrever_evento(uuid) to authenticated;
