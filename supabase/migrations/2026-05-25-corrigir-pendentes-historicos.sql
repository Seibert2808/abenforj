-- Correcao retroativa: inscritos importados ANTES da coluna
-- pendente_verificacao_socia ficaram com flag = false (default), mesmo
-- quando o lote do Doity era cota de socia (R$ reduzido). Esses casos
-- precisam virar pendentes para a admin notificar/regularizar.
--
-- Regra: lote contem "sócia" mas nao contem "não" (sem acento ou com).
-- Exclui quem ja tem perfil em profiles com o mesmo email — esses estao
-- corretos como nao-socias ou ja foram migrados.

update public.inscritos_externos as ie
set pendente_verificacao_socia = true
where pendente_verificacao_socia = false
  and ie.lote_doity is not null
  and ie.lote_doity ilike '%sócia%'
  and ie.lote_doity !~* 'n[aã]o'
  and not exists (
    select 1 from public.profiles p
    where lower(p.email) = lower(ie.email)
  );
