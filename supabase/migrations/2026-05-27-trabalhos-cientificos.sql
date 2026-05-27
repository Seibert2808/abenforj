-- Schema para submissao de trabalhos cientificos do IX ENEON.
-- Regras do edital (resumo): so quem esta inscrito no evento pode submeter;
-- ate 2 trabalhos por relator(a); area + eixo + tipo + resumo estruturado;
-- 3-5 descritores; 3-5 referencias; ate 6 autores; PDF anexo.

create table if not exists public.trabalhos_cientificos (
  id                    uuid        primary key default gen_random_uuid(),
  evento_id             uuid        not null references public.eventos(id) on delete cascade,

  -- Quem submeteu (XOR — pode ser socia OU nao-socia inscrita)
  profile_id            uuid        references public.profiles(id) on delete set null,
  inscrito_externo_id   uuid        references public.inscritos_externos(id) on delete set null,

  -- Cache do relator(a) principal — facilita exibicao e contagem
  relator_nome          text        not null,
  relator_email         text        not null,

  -- Dados do trabalho
  titulo                text        not null,
  area                  text        not null check (area in ('neonatal','obstetrica','saude_coletiva')),
  eixo_tematico         text        not null check (eixo_tematico in ('ensino_formacao_regulacao','cenario_politico','protagonismo_social','cuidado_qualificado')),
  tipo_trabalho         text        not null check (tipo_trabalho in (
                          'pesquisa_original','revisao_sistematizada','ensaio_reflexao',
                          'relato_experiencia','nota_previa','revisao_narrativa','projeto_pesquisa'
                        )),
  resumo                text        not null,
  cep_caae              text,
  ceua                  text,
  referencias           text        not null,
  descritores           text[]      not null default '{}',

  -- Lista de autores (ate 6 objetos: {nome, email, instituicao, eh_relator})
  autores               jsonb       not null default '[]'::jsonb,

  -- Arquivo PDF no bucket trabalhos-cientificos
  pdf_path              text        not null,

  -- Status e auditoria
  status                text        not null default 'submetido'
                          check (status in ('submetido','em_avaliacao','aceito','recusado')),
  bloqueado             boolean     not null default false,
  observacao_avaliacao  text,

  submetido_em          timestamptz not null default now(),
  atualizado_em         timestamptz not null default now(),

  constraint trabalhos_autor_check check (
    profile_id is not null or inscrito_externo_id is not null
  )
);

-- Indices pra contagem por relator (limite de 2 trabalhos) e por evento
create index if not exists trabalhos_evento_idx
  on public.trabalhos_cientificos (evento_id);
create index if not exists trabalhos_profile_idx
  on public.trabalhos_cientificos (profile_id) where profile_id is not null;
create index if not exists trabalhos_externo_idx
  on public.trabalhos_cientificos (inscrito_externo_id) where inscrito_externo_id is not null;
create index if not exists trabalhos_email_idx
  on public.trabalhos_cientificos (lower(relator_email));

-- updated_at automatico
create or replace function public.trabalhos_set_atualizado_em()
returns trigger language plpgsql as $$
begin
  new.atualizado_em := now();
  return new;
end $$;

drop trigger if exists trabalhos_atualizado_em on public.trabalhos_cientificos;
create trigger trabalhos_atualizado_em
  before update on public.trabalhos_cientificos
  for each row execute function public.trabalhos_set_atualizado_em();

-- RLS
alter table public.trabalhos_cientificos enable row level security;

-- Admin tem tudo
drop policy if exists "Trabalhos: admin tudo" on public.trabalhos_cientificos;
create policy "Trabalhos: admin tudo"
  on public.trabalhos_cientificos for all
  using (public.is_admin())
  with check (public.is_admin());

-- Autenticadas veem e gerenciam apenas seus proprios trabalhos
drop policy if exists "Trabalhos: socia ve seus" on public.trabalhos_cientificos;
create policy "Trabalhos: socia ve seus"
  on public.trabalhos_cientificos for select
  using (profile_id = auth.uid());

drop policy if exists "Trabalhos: socia insere proprio" on public.trabalhos_cientificos;
create policy "Trabalhos: socia insere proprio"
  on public.trabalhos_cientificos for insert
  with check (profile_id = auth.uid() and bloqueado = false);

drop policy if exists "Trabalhos: socia atualiza enquanto nao bloqueado" on public.trabalhos_cientificos;
create policy "Trabalhos: socia atualiza enquanto nao bloqueado"
  on public.trabalhos_cientificos for update
  using (profile_id = auth.uid() and bloqueado = false)
  with check (profile_id = auth.uid() and bloqueado = false);

drop policy if exists "Trabalhos: socia deleta enquanto nao bloqueado" on public.trabalhos_cientificos;
create policy "Trabalhos: socia deleta enquanto nao bloqueado"
  on public.trabalhos_cientificos for delete
  using (profile_id = auth.uid() and bloqueado = false);

-- Bucket de Storage para os PDFs (limite 10MB, somente PDF)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'trabalhos-cientificos',
  'trabalhos-cientificos',
  false,
  10 * 1024 * 1024,
  array['application/pdf']
) on conflict (id) do nothing;

-- Storage RLS: admin tudo; autenticadas podem ler/escrever em sua propria pasta
drop policy if exists "Trabalhos PDF: admin tudo" on storage.objects;
create policy "Trabalhos PDF: admin tudo"
  on storage.objects for all
  using (bucket_id = 'trabalhos-cientificos' and public.is_admin())
  with check (bucket_id = 'trabalhos-cientificos' and public.is_admin());

drop policy if exists "Trabalhos PDF: socia gerencia o seu" on storage.objects;
create policy "Trabalhos PDF: socia gerencia o seu"
  on storage.objects for all
  using (
    bucket_id = 'trabalhos-cientificos'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'trabalhos-cientificos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
