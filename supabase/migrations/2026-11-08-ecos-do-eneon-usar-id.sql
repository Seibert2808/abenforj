-- Troca a identificacao do evento Ecos do Eneon de "nome literal" (que
-- corrompeu ao ser colado no SQL Editor, por ter acentos e ser longo) para
-- o UUID do evento, que e curto e sem acentos — elimina esse risco.

create or replace function public.trabalhos_aprovados_publico()
returns table (titulo text)
language sql stable security definer set search_path = public as $$
  select t.titulo
  from public.trabalhos_cientificos t
  where t.evento_id = '25ee0a7b-10fc-478a-8363-849ca98a9134'
    and t.status in ('aceito', 'aceito_com_ressalva')
  order by t.titulo
$$;

create or replace function public.inscritos_externos_publicos()
returns table (nome text)
language sql
security definer
set search_path = public
as $$
  select ie.nome
  from public.inscritos_externos ie
  where ie.evento_id = '25ee0a7b-10fc-478a-8363-849ca98a9134'
    and ie.cancelado = false
    and coalesce(ie.pendente_verificacao_socia, false) = false
  order by lower(ie.nome);
$$;

create or replace function public.evento_ecos_eneon_id()
returns uuid
language sql stable security definer set search_path = public as $$
  select '25ee0a7b-10fc-478a-8363-849ca98a9134'::uuid;
$$;
