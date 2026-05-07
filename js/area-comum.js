// ============================================================
// Comportamento comum a todas as páginas /area/*
// - Verifica se usuária está logada e aprovada (senão redireciona)
// - Preenche o "chip" do usuário no header (nome + foto)
// - Liga o botão "Sair"
// ============================================================

(function () {
  'use strict';

  // Toggle do menu mobile (replicado aqui pra área não depender de main.js)
  var toggle = document.querySelector('.nav-toggle');
  var nav = document.querySelector('.main-nav');
  if (toggle && nav) {
    toggle.addEventListener('click', function () {
      var isOpen = nav.classList.toggle('open');
      toggle.setAttribute('aria-expanded', isOpen ? 'true' : 'false');
    });
  }

  // Botão Sair
  document.addEventListener('click', async function (e) {
    if (e.target.matches('.btn-sair, .btn-sair *')) {
      e.preventDefault();
      if (window.SUPABASE_PRONTO && window.abenfo) {
        await window.abenfo.auth.sair();
      }
      window.location.href = '../index.html';
    }
  });

  // Inicializa página: verifica auth e preenche chip do usuário
  async function inicializar() {
    if (!window.SUPABASE_PRONTO) {
      // Em dev, sem Supabase configurado, mostra aviso e não redireciona
      var main = document.querySelector('main');
      if (main) {
        main.innerHTML = '<div class="container" style="padding:3rem 1.5rem;">' +
          '<div class="aviso"><strong>Em configuração:</strong> a área da associada está sendo configurada. Volte em breve.</div>' +
          '<p><a href="../index.html" class="btn btn-ghost" style="margin-top:1rem;">Voltar para o site</a></p>' +
          '</div>';
      }
      return;
    }

    var perfil = await window.abenfo.auth.exigirAcesso();
    if (!perfil) return; // exigirAcesso já redirecionou

    // Preenche chip do usuário
    var chip = document.querySelector('.user-chip .nome');
    if (chip) chip.textContent = primeiroNome(perfil.nome_completo) || 'Associada';

    var miniFoto = document.querySelector('.user-chip .mini-foto');
    if (miniFoto) {
      if (perfil.foto_url) {
        miniFoto.innerHTML = '<img src="' + perfil.foto_url + '" alt="">';
      } else {
        miniFoto.textContent = (perfil.nome_completo || 'A').charAt(0).toUpperCase();
      }
    }

    // Marca link ativo
    var path = window.location.pathname.split('/').pop() || 'index.html';
    document.querySelectorAll('.main-nav a').forEach(function (link) {
      if (link.getAttribute('href') === path) link.classList.add('active');
    });

    // Disponibiliza o perfil pra páginas que precisem dele
    window.abenfo.perfilAtual = perfil;
    document.dispatchEvent(new CustomEvent('perfil-pronto', { detail: perfil }));
  }

  function primeiroNome(s) {
    if (!s) return '';
    return s.split(/\s+/)[0];
  }

  // Aguarda DOM + Supabase
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', inicializar);
  } else {
    inicializar();
  }
})();
