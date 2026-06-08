-- Certificados: modelos por evento × tipo, liberação por evento e papéis manuais.

-- Interruptor de liberação por evento (sócia/externo só baixam quando true)
alter table public.eventos
  add column if not exists certificados_liberados boolean not null default false;

-- Modelos: 1 por (evento, tipo). Guardam a arte base, os textos e a config de layout.
create table if not exists public.certificado_modelos (
  id             uuid        primary key default gen_random_uuid(),
  evento_id      uuid        not null references public.eventos(id) on delete cascade,
  tipo           text        not null check (tipo in ('participacao','oficina','palestrante','comissao')),
  base_path      text,
  texto_pre      text,
  texto_template text,
  config         jsonb       not null default '{}'::jsonb,
  ativo          boolean     not null default true,
  criado_em      timestamptz not null default now(),
  unique (evento_id, tipo)
);

alter table public.certificado_modelos enable row level security;

drop policy if exists certmodelos_admin_tudo on public.certificado_modelos;
create policy certmodelos_admin_tudo on public.certificado_modelos
  for all using (public.is_admin()) with check (public.is_admin());

drop policy if exists certmodelos_auth_le on public.certificado_modelos;
create policy certmodelos_auth_le on public.certificado_modelos
  for select to authenticated using (ativo = true);

-- Papéis manuais (palestrante, comissão) — não derivam das inscrições.
create table if not exists public.certificado_papeis (
  id          uuid        primary key default gen_random_uuid(),
  evento_id   uuid        not null references public.eventos(id) on delete cascade,
  tipo        text        not null check (tipo in ('palestrante','comissao')),
  nome        text        not null,
  email       text,
  detalhe     text,       -- título da palestra OU nome da comissão
  profile_id  uuid        references public.profiles(id) on delete set null,
  enviado_em  timestamptz,
  criado_em   timestamptz not null default now()
);

alter table public.certificado_papeis enable row level security;

drop policy if exists certpapeis_admin_tudo on public.certificado_papeis;
create policy certpapeis_admin_tudo on public.certificado_papeis
  for all using (public.is_admin()) with check (public.is_admin());

-- Sócia logada vê só os próprios papéis (pra baixar palestrante/comissão).
drop policy if exists certpapeis_socia_le_seus on public.certificado_papeis;
create policy certpapeis_socia_le_seus on public.certificado_papeis
  for select to authenticated using (profile_id = auth.uid());

-- Bucket público das artes base (leitura pública; gravação só admin).
insert into storage.buckets (id, name, public)
values ('certificados-bases', 'certificados-bases', true)
on conflict (id) do nothing;

drop policy if exists certbase_publica on storage.objects;
create policy certbase_publica on storage.objects
  for select using (bucket_id = 'certificados-bases');

drop policy if exists certbase_admin on storage.objects;
create policy certbase_admin on storage.objects
  for all
  using (bucket_id = 'certificados-bases' and public.is_admin())
  with check (bucket_id = 'certificados-bases' and public.is_admin());
