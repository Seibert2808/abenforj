-- Corrige RLS de inscricoes_curso para permitir auto-servico de socias.
--
-- Contexto: a migration 2026-05-15-cursos-tabela.sql so criou policies
-- de INSERT/UPDATE/DELETE para admin. A pagina /area/cursos faz INSERT
-- e DELETE direto pelo cliente (linhas 440 e 453 de area/cursos.html),
-- entao toda socia (nao-admin) recebia o erro:
--   "new row violates row-level security policy for table inscricoes_curso"
-- ao clicar em "Escolher" ou "Cancelar".
--
-- Esta migration adiciona policies permitindo que cada socia gerencie
-- somente as proprias inscricoes (profile_id = auth.uid()).
-- Nao-socios continuam usando as RPCs externo_* (security definer).

-- INSERT: socia insere a propria inscricao
drop policy if exists "Inscricoes curso: socia insere a sua" on public.inscricoes_curso;
create policy "Inscricoes curso: socia insere a sua"
  on public.inscricoes_curso for insert
  with check (
    profile_id = auth.uid()
    and inscrito_externo_id is null
  );

-- DELETE: socia cancela a propria inscricao
drop policy if exists "Inscricoes curso: socia cancela a sua" on public.inscricoes_curso;
create policy "Inscricoes curso: socia cancela a sua"
  on public.inscricoes_curso for delete
  using (profile_id = auth.uid());
