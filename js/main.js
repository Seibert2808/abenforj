(function () {
  'use strict';

  // ============================================================
  // Toggle do menu mobile
  // ============================================================
  var toggle = document.querySelector('.nav-toggle');
  var nav = document.querySelector('.main-nav');

  if (toggle && nav) {
    toggle.addEventListener('click', function () {
      var isOpen = nav.classList.toggle('open');
      toggle.setAttribute('aria-expanded', isOpen ? 'true' : 'false');
    });
  }

  // Marca link ativo no menu pelo arquivo atual
  var path = window.location.pathname.split('/').pop() || 'index.html';
  document.querySelectorAll('.main-nav a').forEach(function (link) {
    var href = link.getAttribute('href');
    if (href === path || (path === '' && href === 'index.html')) {
      link.classList.add('active');
    }
  });

  // ============================================================
  // Pop-up — aparece só na primeira visita (por versão de conteúdo).
  // Conteúdo atual: cartaz da 3ª Reunião do Fórum de EO (30/06/2026).
  // Para forçar a reaparição após trocar o conteúdo, incremente o
  // sufixo da chave (v7 -> v8).
  // ============================================================
  var modal = document.getElementById('modal-boas-vindas');
  var STORAGE_KEY = 'abenfo_modal_ix_v8';
  // Cartaz do Fórum some sozinho a partir de 01/07/2026 (fórum é dia 30/06).
  var EXPIRA_MODAL = new Date('2026-07-01T00:00:00-03:00');

  if (modal) {
    var jaViu = false;
    try { jaViu = localStorage.getItem(STORAGE_KEY) === 'true'; } catch (e) { /* localStorage off */ }

    var expirado = new Date() >= EXPIRA_MODAL;

    if (!jaViu && !expirado) {
      // Atraso pequeno para não poluir o primeiro paint
      setTimeout(function () {
        modal.hidden = false;
        // forçar reflow antes da transição
        // eslint-disable-next-line no-unused-expressions
        modal.offsetHeight;
        modal.classList.add('open');
        // Foco no primeiro elemento interativo
        var firstFocusable = modal.querySelector('button, a, [tabindex]');
        if (firstFocusable) firstFocusable.focus();
      }, 600);
    }

    function fecharModal() {
      modal.classList.remove('open');
      try { localStorage.setItem(STORAGE_KEY, 'true'); } catch (e) { /* ok */ }
      setTimeout(function () { modal.hidden = true; }, 220);
    }

    var btnFechar = modal.querySelector('.modal-close');
    if (btnFechar) btnFechar.addEventListener('click', fecharModal);

    // Clicar fora (no overlay) fecha
    modal.addEventListener('click', function (e) {
      if (e.target === modal) fecharModal();
    });

    // Tecla Esc fecha
    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape' && modal.classList.contains('open')) fecharModal();
    });

    // Botões internos do modal (CTA "Inscreva-se") também marcam como visto
    modal.querySelectorAll('a').forEach(function (link) {
      link.addEventListener('click', function () {
        try { localStorage.setItem(STORAGE_KEY, 'true'); } catch (e) { /* ok */ }
      });
    });
  }
})();
