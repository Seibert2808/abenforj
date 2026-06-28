-- Blindagem contra perda de escolhas de curso na migração não-sócia -> sócia.
--
-- Problema: inscricoes_curso.inscrito_externo_id tem ON DELETE CASCADE. Quando a
-- reimportação do Doity apaga o registro de inscritos_externos de quem já tem
-- cadastro de sócia (migração), o banco apagava junto a escolha de curso dela.
--
-- Solução: um gatilho BEFORE DELETE em inscritos_externos que, quando existe um
-- perfil com o mesmo e-mail, REAPONTA as escolhas de curso daquele registro
-- externo para o perfil (em vez de deixar o cascade apagar). Protege todos os
-- caminhos de exclusão (admin, SQL, etc.) de uma vez só.

create or replace function public.preservar_cursos_ao_apagar_externo()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_profile_id uuid;
begin
  -- Perfil (conta de sócia) com o mesmo e-mail do registro externo que será apagado.
  select id into v_profile_id
    from public.profiles
   where lower(email) = lower(OLD.email)
   limit 1;

  if v_profile_id is not null then
    -- Reaponta as escolhas de curso do externo para o perfil, sem duplicar:
    -- só transfere os cursos que o perfil ainda NÃO tem.
    update public.inscricoes_curso ic
       set inscrito_externo_id = null,
           profile_id = v_profile_id
     where ic.inscrito_externo_id = OLD.id
       and not exists (
         select 1 from public.inscricoes_curso ic2
          where ic2.profile_id = v_profile_id
            and ic2.curso_id = ic.curso_id
       );
    -- Cursos que o perfil já tinha (duplicados) continuam ligados ao externo e
    -- serão apagados pelo cascade normalmente — sem perda real (já existem no perfil).
  end if;

  return OLD;
end $fn$;

drop trigger if exists trg_preservar_cursos_externo on public.inscritos_externos;
create trigger trg_preservar_cursos_externo
  before delete on public.inscritos_externos
  for each row execute function public.preservar_cursos_ao_apagar_externo();
