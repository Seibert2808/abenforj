-- Adiciona cursos e inscricoes_curso.
-- Cursos podem pertencer a um evento (FK opcional) ou ser standalone.

create table if not exists public.cursos (
  id              uuid        primary key default gen_random_uuid(),
  nome            text        not null,
  descricao       text,
  evento_id       uuid        references public.eventos(id) on delete set null,
  data            date,
  turno           text,
  local           text,
  link_externo    text,
  ativo           boolean     not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index if not exists cursos_data_idx
  on public.cursos (data desc nulls last);
create index if not exists cursos_evento_id_idx
  on public.cursos (evento_id);

alter table public.cursos enable row level security;

drop policy if exists "Cursos: leitura publica" on public.cursos;
create policy "Cursos: leitura publica"
  on public.cursos for select
  using (true);

drop policy if exists "Cursos: admin insere" on public.cursos;
create policy "Cursos: admin insere"
  on public.cursos for insert
  with check (public.is_admin());

drop policy if exists "Cursos: admin atualiza" on public.cursos;
create policy "Cursos: admin atualiza"
  on public.cursos for update
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists "Cursos: admin exclui" on public.cursos;
create policy "Cursos: admin exclui"
  on public.cursos for delete
  using (public.is_admin());

create table if not exists public.inscricoes_curso (
  id              uuid        primary key default gen_random_uuid(),
  profile_id      uuid        not null references public.profiles(id) on delete cascade,
  curso_id        uuid        not null references public.cursos(id) on delete cascade,
  data_inscricao  timestamptz not null default now(),
  observacao      text,
  created_at      timestamptz not null default now(),
  created_by      uuid        references auth.users(id) on delete set null,
  unique (profile_id, curso_id)
);

create index if not exists inscricoes_curso_profile_id_idx
  on public.inscricoes_curso (profile_id);
create index if not exists inscricoes_curso_curso_id_idx
  on public.inscricoes_curso (curso_id);

alter table public.inscricoes_curso enable row level security;

drop policy if exists "Inscricoes curso: associada ve as suas" on public.inscricoes_curso;
create policy "Inscricoes curso: associada ve as suas"
  on public.inscricoes_curso for select
  using (profile_id = auth.uid());

drop policy if exists "Inscricoes curso: admin ve todas" on public.inscricoes_curso;
create policy "Inscricoes curso: admin ve todas"
  on public.inscricoes_curso for select
  using (public.is_admin());

drop policy if exists "Inscricoes curso: admin insere" on public.inscricoes_curso;
create policy "Inscricoes curso: admin insere"
  on public.inscricoes_curso for insert
  with check (public.is_admin());

drop policy if exists "Inscricoes curso: admin atualiza" on public.inscricoes_curso;
create policy "Inscricoes curso: admin atualiza"
  on public.inscricoes_curso for update
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists "Inscricoes curso: admin exclui" on public.inscricoes_curso;
create policy "Inscricoes curso: admin exclui"
  on public.inscricoes_curso for delete
  using (public.is_admin());

-- Pre-cadastro dos 6 cursos pre-encontro do IX ENEON 2026.
do $$
declare
  v_evento_id uuid;
begin
  select id into v_evento_id from public.eventos where nome = 'IX ENEON 2026' limit 1;
  if v_evento_id is null then
    return;
  end if;

  insert into public.cursos (nome, descricao, evento_id, data, turno, local)
  select v.nome, v.descricao, v_evento_id, v.data, v.turno, v.local
  from (values
    ('Manejo Clínico da Amamentação associado à Laserterapia',
     'Atualização sobre as principais intercorrências da amamentação e o uso da laserterapia como tecnologia de cuidado.',
     '2026-07-15'::date, 'Manhã (08h às 12h)', 'Sala 716 — FENF UERJ'),
    ('Manejo da Hemorragia Pós-Parto em cenários não hospitalares',
     'Estabilização e transporte seguro em casos de hemorragia pós-parto fora do ambiente hospitalar.',
     '2026-07-15'::date, 'Manhã (08h às 12h)', 'Espaço Raquel Haddock Lobo — FENF UERJ'),
    ('Interpretação de Laudos Ultrassonográficos em Obstetrícia',
     'Leitura crítica e aplicação clínica de laudos ultrassonográficos no cuidado obstétrico.',
     '2026-07-15'::date, 'Manhã (08h às 12h)', 'Sala 23 — Pav. Nalva Pereira Caldas — FENF UERJ'),
    ('Manejo Clínico dos Traumas Perineais associado à Laserterapia',
     'Avaliação e manejo de traumas perineais com uso da laserterapia como recurso terapêutico.',
     '2026-07-15'::date, 'Tarde (13h às 17h)', 'Sala 716 — FENF UERJ'),
    ('Reconstrução Perineal e Segurança Farmacológica',
     'Atualização em procedimentos de reconstrução perineal, com foco em segurança farmacológica.',
     '2026-07-15'::date, 'Tarde (13h às 17h)', 'Espaço Raquel Haddock Lobo — FENF UERJ'),
    ('Avaliação do Recém-Nascido em Sala de Parto',
     'Aplicação de escalas para o exame físico do recém-nascido e avaliação clínica em sala de parto.',
     '2026-07-15'::date, 'Tarde (13h às 17h)', 'Sala 23 — Pav. Nalva Pereira Caldas — FENF UERJ')
  ) as v(nome, descricao, data, turno, local)
  where not exists (
    select 1 from public.cursos c
    where c.nome = v.nome and c.evento_id = v_evento_id
  );
end $$;
