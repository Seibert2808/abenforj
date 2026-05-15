-- Auto-servico de cursos pre-encontro.
-- 1) Adiciona coluna `vagas` em cursos (padrao 50).
-- 2) Cria `inscritos_externos` para nao-socios (vindos da planilha Doity).
-- 3) Permite que `inscricoes_curso` aponte para profile OU inscrito externo.
-- 4) Funcoes RPC para nao-socios escolherem cursos via email + numero Doity.

-- (1) Coluna vagas
alter table public.cursos
  add column if not exists vagas integer;

update public.cursos set vagas = 50 where vagas is null and evento_id is not null;

-- (2) Tabela de nao-socios
create table if not exists public.inscritos_externos (
  id              uuid        primary key default gen_random_uuid(),
  evento_id       uuid        not null references public.eventos(id) on delete cascade,
  nome            text        not null,
  email           text        not null,
  doity_id        text,
  telefone        text,
  data_inscricao  timestamptz,
  observacao      text,
  created_at      timestamptz not null default now(),
  created_by      uuid        references auth.users(id) on delete set null,
  unique (evento_id, email)
);

create index if not exists inscritos_externos_email_idx
  on public.inscritos_externos (lower(email));
create index if not exists inscritos_externos_doity_id_idx
  on public.inscritos_externos (doity_id);

alter table public.inscritos_externos enable row level security;

drop policy if exists "InscritosExt: admin tudo" on public.inscritos_externos;
create policy "InscritosExt: admin tudo"
  on public.inscritos_externos for all
  using (public.is_admin())
  with check (public.is_admin());

-- (3) Modifica inscricoes_curso pra aceitar FK externa
alter table public.inscricoes_curso
  alter column profile_id drop not null;

alter table public.inscricoes_curso
  add column if not exists inscrito_externo_id uuid
    references public.inscritos_externos(id) on delete cascade;

alter table public.inscricoes_curso
  drop constraint if exists inscricoes_curso_owner_check;
alter table public.inscricoes_curso
  add constraint inscricoes_curso_owner_check check (
    (profile_id is not null and inscrito_externo_id is null) or
    (profile_id is null and inscrito_externo_id is not null)
  );

create unique index if not exists inscricoes_curso_externo_curso_unique
  on public.inscricoes_curso (inscrito_externo_id, curso_id)
  where inscrito_externo_id is not null;

-- (4) RPCs para nao-socios

-- Valida token (email + doity_id) e retorna dados do externo + cursos ja escolhidos
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
    return json_build_object('ok', false, 'erro', 'Inscricao nao encontrada. Confira email e numero Doity (formato DOI-XXXXXXXXX).');
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

-- Escolhe um curso. Se ja tem curso no mesmo turno, troca.
create or replace function public.externo_escolher_curso(
  p_email text,
  p_doity_id text,
  p_curso_id uuid
) returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_inscrito record;
  v_curso record;
  v_ocupadas integer;
begin
  select id, evento_id into v_inscrito
    from public.inscritos_externos
    where lower(email) = lower(trim(p_email))
      and doity_id = upper(trim(p_doity_id))
    limit 1;

  if v_inscrito is null then
    return json_build_object('ok', false, 'erro', 'Inscricao nao encontrada.');
  end if;

  select id, evento_id, turno, vagas, nome into v_curso
    from public.cursos where id = p_curso_id and ativo = true;

  if v_curso is null then
    return json_build_object('ok', false, 'erro', 'Curso nao encontrado.');
  end if;

  if v_curso.evento_id is not null and v_curso.evento_id <> v_inscrito.evento_id then
    return json_build_object('ok', false, 'erro', 'Curso nao pertence ao evento da sua inscricao.');
  end if;

  -- Remove curso ja escolhido no mesmo turno (se houver)
  if v_curso.turno is not null then
    delete from public.inscricoes_curso ic
    using public.cursos c
    where ic.curso_id = c.id
      and ic.inscrito_externo_id = v_inscrito.id
      and c.turno = v_curso.turno
      and c.id <> v_curso.id;
  end if;

  -- Confere vagas
  if v_curso.vagas is not null then
    select count(*) into v_ocupadas
      from public.inscricoes_curso where curso_id = v_curso.id;
    if v_ocupadas >= v_curso.vagas then
      return json_build_object('ok', false, 'erro', 'Vagas esgotadas neste curso.');
    end if;
  end if;

  insert into public.inscricoes_curso (inscrito_externo_id, curso_id)
  values (v_inscrito.id, v_curso.id)
  on conflict do nothing;

  return json_build_object('ok', true, 'curso', v_curso.nome);
end $$;

grant execute on function public.externo_escolher_curso(text, text, uuid) to anon, authenticated;

-- Cancela a escolha de um curso
create or replace function public.externo_cancelar_curso(
  p_email text,
  p_doity_id text,
  p_curso_id uuid
) returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_inscrito_id uuid;
begin
  select id into v_inscrito_id
    from public.inscritos_externos
    where lower(email) = lower(trim(p_email))
      and doity_id = upper(trim(p_doity_id))
    limit 1;

  if v_inscrito_id is null then
    return json_build_object('ok', false, 'erro', 'Inscricao nao encontrada.');
  end if;

  delete from public.inscricoes_curso
    where inscrito_externo_id = v_inscrito_id
      and curso_id = p_curso_id;

  return json_build_object('ok', true);
end $$;

grant execute on function public.externo_cancelar_curso(text, text, uuid) to anon, authenticated;

-- Lista cursos de um evento com vagas restantes (usado por ambos sócios e nao-socios)
create or replace function public.cursos_com_vagas(
  p_evento_id uuid
) returns table (
  id uuid,
  nome text,
  descricao text,
  data date,
  turno text,
  local text,
  vagas integer,
  ocupadas bigint
)
language sql
security definer
set search_path = public
as $$
  select c.id, c.nome, c.descricao, c.data, c.turno, c.local, c.vagas,
    (select count(*) from public.inscricoes_curso ic where ic.curso_id = c.id) as ocupadas
  from public.cursos c
  where c.evento_id = p_evento_id and c.ativo = true
  order by c.data, c.turno, c.nome;
$$;

grant execute on function public.cursos_com_vagas(uuid) to anon, authenticated;
