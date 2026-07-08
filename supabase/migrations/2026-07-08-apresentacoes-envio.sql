-- ============================================================
-- Envio das APRESENTAÇÕES (slides) dos trabalhos aprovados — IX ENEON.
-- Só PDF, até 14/07/2026 23:59 (horário de Brasília). Espelha o fluxo de
-- correção do PDF, MAS com as políticas de storage SEMPRE encapsuladas em
-- função SECURITY DEFINER — nunca subselect inline (foi o que quebrou o
-- upload do PDF dos trabalhos duas vezes: o papel anon não enxerga as
-- linhas de trabalhos_cientificos, então o EXISTS inline dava falso).
-- ============================================================

-- 1. Colunas novas em trabalhos_cientificos
alter table public.trabalhos_cientificos
  add column if not exists apresentacao_path        text,
  add column if not exists apresentacao_enviada_em  timestamptz,
  add column if not exists sala                      text;  -- sala de apresentação (organização preenche depois)

-- 2. Bucket privado só das apresentações (separado do PDF dos trabalhos)
insert into storage.buckets (id, name, public)
values ('apresentacoes', 'apresentacoes', false)
on conflict (id) do nothing;

-- 3. Prazo único (14/07/2026 23:59:59 BRT). Fonte de verdade do deadline.
create or replace function public.apresentacao_prazo()
returns timestamptz language sql immutable as $$
  select timestamptz '2026-07-14 23:59:59-03';
$$;

-- 4. Extrai o id do trabalho do nome do objeto no bucket: '<uuid>.pdf'
create or replace function public._apresentacao_trab_id(p_name text)
returns text language sql immutable as $$
  select substring(p_name from '^([0-9a-fA-F-]{36})\.pdf$');
$$;

-- 5. Pode GRAVAR (upload/upsert): trabalho aprovado, do próprio dono, no prazo.
--    SECURITY DEFINER: ignora o RLS de trabalhos_cientificos (que anon não vê).
create or replace function public.apresentacao_gravavel(p_name text)
returns boolean language sql security definer set search_path = public as $$
  select exists (
    select 1 from public.trabalhos_cientificos t
    where t.id::text = public._apresentacao_trab_id(p_name)
      and t.status in ('aceito','aceito_com_ressalva')
      and now() <= public.apresentacao_prazo()
      and (t.profile_id = auth.uid() or t.inscrito_externo_id is not null)
  );
$$;
grant execute on function public.apresentacao_gravavel(text) to anon, authenticated;

-- 6. Pode LER (download): dono ou admin — sem restrição de prazo.
create or replace function public.apresentacao_legivel(p_name text)
returns boolean language sql security definer set search_path = public as $$
  select exists (
    select 1 from public.trabalhos_cientificos t
    where t.id::text = public._apresentacao_trab_id(p_name)
      and (t.profile_id = auth.uid() or t.inscrito_externo_id is not null or public.is_admin())
  );
$$;
grant execute on function public.apresentacao_legivel(text) to anon, authenticated;

-- 7. Políticas do bucket 'apresentacoes' (sempre via as funções acima)
drop policy if exists "Apresentacoes: admin tudo" on storage.objects;
create policy "Apresentacoes: admin tudo" on storage.objects for all
  using (bucket_id = 'apresentacoes' and public.is_admin())
  with check (bucket_id = 'apresentacoes' and public.is_admin());

drop policy if exists "Apresentacoes: upload controlado" on storage.objects;
create policy "Apresentacoes: upload controlado" on storage.objects for insert
  to anon, authenticated
  with check (bucket_id = 'apresentacoes' and public.apresentacao_gravavel(name));

drop policy if exists "Apresentacoes: update controlado" on storage.objects;
create policy "Apresentacoes: update controlado" on storage.objects for update
  to anon, authenticated
  using (bucket_id = 'apresentacoes' and public.apresentacao_gravavel(name))
  with check (bucket_id = 'apresentacoes' and public.apresentacao_gravavel(name));

drop policy if exists "Apresentacoes: leitura controlada" on storage.objects;
create policy "Apresentacoes: leitura controlada" on storage.objects for select
  to anon, authenticated
  using (bucket_id = 'apresentacoes' and public.apresentacao_legivel(name));

-- 8. RPC sócia: carimba o envio (grava path + data). Só dona, aprovado, no prazo.
create or replace function public.registrar_apresentacao_trabalho(p_trabalho_id uuid)
returns timestamptz language plpgsql security definer set search_path = public as $$
declare v_ts timestamptz;
begin
  if now() > public.apresentacao_prazo() then
    raise exception 'Prazo de envio da apresentação encerrado (14/07 às 23:59).';
  end if;
  update public.trabalhos_cientificos
     set apresentacao_path = p_trabalho_id::text || '.pdf',
         apresentacao_enviada_em = now()
   where id = p_trabalho_id
     and profile_id = auth.uid()
     and status in ('aceito','aceito_com_ressalva')
  returning apresentacao_enviada_em into v_ts;
  if v_ts is null then
    raise exception 'Envio de apresentação não permitido para este trabalho.';
  end if;
  return v_ts;
end $$;
grant execute on function public.registrar_apresentacao_trabalho(uuid) to authenticated;

-- 9. RPC externo: idem, identificação por email + número Doity.
create or replace function public.externo_registrar_apresentacao(
  p_email text, p_doity_id text, p_trabalho_id uuid
) returns json language plpgsql security definer set search_path = public as $$
declare v_ins record; v_trab record;
begin
  if now() > public.apresentacao_prazo() then
    return json_build_object('ok', false, 'erro', 'Prazo de envio encerrado (14/07 às 23:59).');
  end if;
  select * into v_ins from public._externo_lookup(p_email, p_doity_id);
  if v_ins is null then
    return json_build_object('ok', false, 'erro', 'Inscrição não encontrada.');
  end if;
  select id, status into v_trab
  from public.trabalhos_cientificos
  where id = p_trabalho_id and inscrito_externo_id = v_ins.id;
  if v_trab is null then
    return json_build_object('ok', false, 'erro', 'Trabalho não encontrado.');
  end if;
  if v_trab.status not in ('aceito','aceito_com_ressalva') then
    return json_build_object('ok', false, 'erro', 'Envio não permitido para este trabalho.');
  end if;
  update public.trabalhos_cientificos
     set apresentacao_path = p_trabalho_id::text || '.pdf',
         apresentacao_enviada_em = now()
   where id = p_trabalho_id;
  return json_build_object('ok', true);
end $$;
grant execute on function public.externo_registrar_apresentacao(text, text, uuid) to anon, authenticated;

-- 10. Painel do externo passa a devolver os carimbos de correção e apresentação,
--     para o site mostrar o estado do botão ("Enviar" / "Reenviar" / recebida).
create or replace function public.externo_meus_trabalhos(p_email text, p_doity_id text)
returns json language plpgsql security definer set search_path = public as $$
declare v_ins record; v_trabs json;
begin
  select * into v_ins from public._externo_lookup(p_email, p_doity_id);
  if v_ins is null then
    return json_build_object('ok', false, 'erro', 'Inscricao nao encontrada. Confira email e numero Doity (formato DOI-XXXXXXXXX).');
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
    'correcao_enviada_em', t.correcao_enviada_em,
    'apresentacao_enviada_em', t.apresentacao_enviada_em,
    'apresentacao_path', t.apresentacao_path
  ) order by t.submetido_em desc)
  into v_trabs
  from public.trabalhos_cientificos t
  where t.inscrito_externo_id = v_ins.id;

  return json_build_object(
    'ok', true,
    'inscrito', json_build_object(
      'id', v_ins.id, 'evento_id', v_ins.evento_id, 'nome', v_ins.nome, 'email', v_ins.email
    ),
    'trabalhos', coalesce(v_trabs, '[]'::json)
  );
end $$;
grant execute on function public.externo_meus_trabalhos(text, text) to anon, authenticated;
