-- Permite registrar e-mails enviados a inscritos externos (nao-socios)
-- alem das associadas. Estende emails_enviados com inscrito_externo_id
-- (XOR com profile_id), seguindo o padrao de inscricoes_curso.

alter table public.emails_enviados
  alter column profile_id drop not null;

alter table public.emails_enviados
  add column if not exists inscrito_externo_id uuid
    references public.inscritos_externos(id) on delete cascade;

alter table public.emails_enviados
  drop constraint if exists emails_enviados_owner_check;
alter table public.emails_enviados
  add constraint emails_enviados_owner_check check (
    (profile_id is not null and inscrito_externo_id is null) or
    (profile_id is null and inscrito_externo_id is not null)
  );

create index if not exists emails_enviados_inscrito_externo_idx
  on public.emails_enviados (inscrito_externo_id, enviado_em desc);
