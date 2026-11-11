-- ============================================================
-- Agendador diário da fila de comunicados (ABENFO-RJ)
--
-- ATENÇÃO: antes de rodar, troque COLE_AQUI_O_FILA_SECRET pelo valor
-- real do secret FILA_SECRET (o mesmo cadastrado em Edge Functions >
-- Secrets). O segredo NÃO fica versionado neste arquivo de propósito.
--
-- Rode no painel do Supabase: SQL Editor > New query > Run.
--
-- O que faz: todo dia às 13:00 UTC (10:00 de Brasília) chama a função
-- processar-fila-comunicados, que envia o lote do dia de quem ainda
-- está na fila. Se não houver ninguém pendente, a função não faz nada.
-- ============================================================

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- Remove o agendamento anterior, se já existir (deixa o script repetível).
do $$
begin
  perform cron.unschedule('comunicados-lote-diario');
exception
  when others then null;
end
$$;

select cron.schedule(
  'comunicados-lote-diario',
  '0 13 * * *',
  $cron$
  select net.http_post(
    url     := 'https://jetyugyyhdzllfckjhnq.supabase.co/functions/v1/processar-fila-comunicados',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      -- anonKey do projeto: é pública, já vive em js/config.js.
      -- Serve só para passar pelo porteiro das Edge Functions.
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpldHl1Z3l5aGR6bGxmY2tqaG5xIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgxNTM1NTksImV4cCI6MjA5MzcyOTU1OX0.wzHddArAjdrndxMIW4dIH3c1CkZn2CarVyr05sCAWRM',
      -- Este sim é o segredo: prova que a chamada veio do agendador.
      'x-fila-secret', 'COLE_AQUI_O_FILA_SECRET'
    ),
    body    := '{}'::jsonb
  );
  $cron$
);

-- Conferência: deve aparecer uma linha com o job ativo.
select jobid, jobname, schedule, active from cron.job where jobname = 'comunicados-lote-diario';

-- Para acompanhar as execuções depois:
--   select * from cron.job_run_details order by start_time desc limit 10;
-- Para desligar o agendamento:
--   select cron.unschedule('comunicados-lote-diario');
