// ============================================================
// Configuração do Supabase — área da associada
// ============================================================
//
// SABRINA: depois de criar o projeto no https://supabase.com,
// vá em Settings → API e copie:
//   - Project URL  → cole em SUPABASE_URL abaixo
//   - anon / public key  → cole em SUPABASE_ANON_KEY abaixo
//
// Estes dois valores são públicos por design — podem ficar no
// código aberto. A segurança vem das políticas de RLS no banco.
// ============================================================

window.SUPABASE_CONFIG = {
  url: 'COLE_AQUI_A_URL_DO_PROJETO_SUPABASE',
  anonKey: 'COLE_AQUI_A_ANON_KEY_DO_SUPABASE'
};
