-- ============================================================
-- Permite que admins excluam perfis pelo painel /area/admin
--
-- Por que: a diretoria precisa conseguir remover cadastros
-- duplicados ou criados por engano direto pelo painel admin do
-- site, sem precisar abrir o painel do Supabase para cada caso.
--
-- Apenas o registro em public.profiles é apagado. O auth.users
-- correspondente permanece "órfão" (mantém o e-mail reservado).
-- Para apagar a conta de autenticação de vez, é preciso ir em
-- Authentication > Users no painel do Supabase.
-- ============================================================

drop policy if exists "Admin exclui qualquer perfil" on public.profiles;

create policy "Admin exclui qualquer perfil"
  on public.profiles for delete
  using (public.is_admin());
