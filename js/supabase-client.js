// ============================================================
// Cliente Supabase + helpers de auth para o site Abenfo RJ
// ============================================================

(function () {
  'use strict';

  var cfg = window.SUPABASE_CONFIG || {};
  var configurado = cfg.url && cfg.url.indexOf('COLE_AQUI') !== 0
                  && cfg.anonKey && cfg.anonKey.indexOf('COLE_AQUI') !== 0;

  // Sinalizador para que páginas saibam mostrar aviso quando ainda não
  // está configurado (durante o desenvolvimento, antes do deploy).
  window.SUPABASE_PRONTO = configurado;

  if (!configurado) {
    console.warn('[Abenfo RJ] Supabase ainda não configurado. Edite js/config.js.');
    return;
  }

  // Carrega Supabase do CDN (se ainda não estiver carregado pela página).
  // Páginas que usam auth devem incluir o script do CDN antes deste arquivo.
  if (typeof window.supabase === 'undefined' || !window.supabase.createClient) {
    console.error('[Abenfo RJ] Supabase SDK não encontrado. Inclua o script do CDN antes de supabase-client.js.');
    return;
  }

  var sb = window.supabase.createClient(cfg.url, cfg.anonKey, {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: true
    }
  });

  window.abenfo = window.abenfo || {};
  window.abenfo.sb = sb;

  // ============================================================
  // Utilities compartilhadas
  // ============================================================

  // Normaliza nome próprio em portugues — "ANA SOUZA" / "ana souza" -> "Ana Souza".
  // Mantem preposicoes/artigos comuns em minusculo (exceto se forem a primeira palavra).
  function tituloPt(s) {
    if (!s) return s;
    var pequenas = ['de','da','do','das','dos','e'];
    var partes = String(s).toLowerCase().trim().split(/\s+/);
    return partes.map(function (w, i) {
      if (!w) return w;
      if (i > 0 && pequenas.indexOf(w) !== -1) return w;
      return w.charAt(0).toUpperCase() + w.slice(1);
    }).join(' ');
  }
  window.abenfo.utils = window.abenfo.utils || {};
  window.abenfo.utils.tituloPt = tituloPt;

  // ============================================================
  // Helpers de auth
  // ============================================================

  window.abenfo.auth = {
    /**
     * Cadastra nova associada (status pendente até admin aprovar).
     */
    async cadastrar(dados) {
      var email = dados.email;
      var senha = dados.senha;
      var nomeCompletoNorm = tituloPt(dados.nome_completo);
      var nomeSocialNorm = dados.nome_social ? tituloPt(dados.nome_social) : null;
      // Se preencheram igual ao nome completo, ignora — nome social so faz sentido se for diferente
      if (nomeSocialNorm && nomeCompletoNorm && nomeSocialNorm.toLowerCase() === nomeCompletoNorm.toLowerCase()) {
        nomeSocialNorm = null;
      }
      var meta = {
        nome_completo: nomeCompletoNorm,
        nome_social: nomeSocialNorm,
        genero: dados.genero || null,
        categoria: dados.categoria || null,
        especialidade: dados.especialidade || null,
        coren: dados.coren || null,
        telefone: dados.telefone || null
      };
      var res = await sb.auth.signUp({
        email: email,
        password: senha,
        options: { data: meta }
      });
      return res;
    },

    /**
     * Login com email + senha.
     */
    async entrar(email, senha) {
      return await sb.auth.signInWithPassword({ email: email, password: senha });
    },

    /**
     * Envia e-mail de recuperação de senha. O link leva ao /redefinir-senha.html.
     */
    async recuperarSenha(email) {
      var redirectTo = window.location.origin + '/redefinir-senha.html';
      return await sb.auth.resetPasswordForEmail(email, { redirectTo: redirectTo });
    },

    /**
     * Atualiza senha (usado depois do magic link de recuperação).
     */
    async atualizarSenha(novaSenha) {
      return await sb.auth.updateUser({ password: novaSenha });
    },

    async sair() {
      return await sb.auth.signOut();
    },

    async sessao() {
      var r = await sb.auth.getSession();
      return r.data && r.data.session ? r.data.session : null;
    },

    async usuario() {
      var r = await sb.auth.getUser();
      return r.data && r.data.user ? r.data.user : null;
    },

    /**
     * Carrega perfil completo da associada (tabela profiles).
     */
    async meuPerfil() {
      var u = await this.usuario();
      if (!u) return null;
      var r = await sb.from('profiles').select('*').eq('id', u.id).maybeSingle();
      return r.data || null;
    },

    /**
     * Garante que a usuária está logada e com status 'ativo'.
     * Redireciona para /login.html se não estiver, ou para a página
     * "aguardando aprovação" se estiver pendente.
     */
    async exigirAcesso() {
      var sess = await this.sessao();
      if (!sess) {
        window.location.href = '/login?redirect=' + encodeURIComponent(window.location.pathname);
        return null;
      }
      var perfil = await this.meuPerfil();
      if (!perfil || perfil.status !== 'ativo') {
        window.location.href = '/aguardando-aprovacao';
        return null;
      }
      return perfil;
    },

    /**
     * Garante que é admin. Não-admins voltam para o dashboard.
     */
    async exigirAdmin() {
      var perfil = await this.exigirAcesso();
      if (!perfil) return null;
      if (!perfil.is_admin) {
        window.location.href = '/area';
        return null;
      }
      return perfil;
    }
  };
})();
