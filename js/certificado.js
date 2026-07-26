/*
 * Motor de geração de certificados (100% no navegador).
 * Desenha a arte base (PNG 3508×2480, A4 paisagem a 300 DPI) num canvas e
 * sobrepõe o texto central (abertura + nome + corpo), exportando em PDF A4.
 *
 * Uso:
 *   await window.abenfoCert.baixarPDF({
 *     baseUrl,                       // objectURL da arte (ou null = fundo branco)
 *     textoPre: 'Certificamos que',
 *     nome: 'Maria da Silva',
 *     textoCorpo: 'participou do ...',
 *     config: { nome_size, corpo_size, pre_size, band_top, margem, cor, fonte }
 *   }, 'certificado.pdf');
 */
(function () {
  var LARGURA = 3508, ALTURA = 2480; // A4 paisagem @ 300 DPI

  var _jspdfPromise = null;
  function carregarJsPDF() {
    if (window.jspdf && window.jspdf.jsPDF) return Promise.resolve(window.jspdf.jsPDF);
    if (_jspdfPromise) return _jspdfPromise;
    _jspdfPromise = new Promise(function (resolve, reject) {
      var s = document.createElement('script');
      s.src = 'https://cdn.jsdelivr.net/npm/jspdf@2.5.1/dist/jspdf.umd.min.js';
      s.onload = function () {
        if (window.jspdf && window.jspdf.jsPDF) resolve(window.jspdf.jsPDF);
        else reject(new Error('jsPDF carregou mas não inicializou.'));
      };
      s.onerror = function () { reject(new Error('Falha ao baixar a biblioteca de PDF.')); };
      document.head.appendChild(s);
    });
    return _jspdfPromise;
  }

  function carregarImagem(url) {
    return new Promise(function (resolve, reject) {
      var img = new Image();
      img.crossOrigin = 'anonymous';
      img.onload = function () { resolve(img); };
      img.onerror = function () { reject(new Error('Não foi possível carregar a arte base.')); };
      img.src = url;
    });
  }

  // Substitui {{campo}} pelos valores. Campo ausente vira string vazia.
  function aplicarCampos(texto, campos) {
    return String(texto == null ? '' : texto).replace(/\{\{\s*(\w+)\s*\}\}/g, function (m, chave) {
      var v = campos && campos[chave];
      return (v == null || v === '') ? '' : String(v);
    }).replace(/\s+/g, ' ').trim();
  }

  // Quebra um parágrafo em linhas que cabem em maxLargura (px), respeitando a fonte atual do ctx.
  function quebrarLinhas(ctx, texto, maxLargura) {
    var palavras = String(texto).split(/\s+/).filter(Boolean);
    var linhas = [], atual = '';
    palavras.forEach(function (p) {
      var tentativa = atual ? atual + ' ' + p : p;
      if (atual && ctx.measureText(tentativa).width > maxLargura) {
        linhas.push(atual);
        atual = p;
      } else {
        atual = tentativa;
      }
    });
    if (atual) linhas.push(atual);
    return linhas;
  }

  async function montarCanvas(opts) {
    var cfg = opts.config || {};
    var fonte = cfg.fonte || "Georgia, 'Times New Roman', serif";
    var cor = cfg.cor || '#1f2a23';
    var margem = cfg.margem != null ? cfg.margem : 380;
    var preSize = cfg.pre_size || 56;
    var nomeSize = cfg.nome_size || 130;
    var corpoSize = cfg.corpo_size || 64;
    var maxLargura = LARGURA - 2 * margem;
    var cx = LARGURA / 2;

    var canvas = document.createElement('canvas');
    canvas.width = LARGURA;
    canvas.height = ALTURA;
    var ctx = canvas.getContext('2d');

    ctx.fillStyle = '#ffffff';
    ctx.fillRect(0, 0, LARGURA, ALTURA);
    if (opts.baseUrl) {
      var img = await carregarImagem(opts.baseUrl);
      ctx.drawImage(img, 0, 0, LARGURA, ALTURA);
    }

    ctx.textAlign = 'center';
    ctx.textBaseline = 'alphabetic';
    ctx.fillStyle = cor;

    var y = cfg.band_top != null ? cfg.band_top : 1000;

    if (opts.textoPre) {
      ctx.font = 'normal ' + preSize + 'px ' + fonte;
      ctx.fillText(opts.textoPre, cx, y);
      // O nome é desenhado na linha de base, então "sobe" pela altura das
      // maiúsculas. O avanço precisa contar o tamanho do nome (grande), senão
      // ele encosta no "pré". Assim o nome pula uma linha de verdade.
      y += preSize * 0.6 + nomeSize * 0.85;
    }

    if (opts.nome) {
      ctx.font = 'bold ' + nomeSize + 'px ' + fonte;
      quebrarLinhas(ctx, opts.nome, maxLargura).forEach(function (ln) {
        ctx.fillText(ln, cx, y);
        y += nomeSize * 1.15;
      });
      y += nomeSize * 0.45;
    }

    if (opts.textoCorpo) {
      ctx.font = 'normal ' + corpoSize + 'px ' + fonte;
      quebrarLinhas(ctx, opts.textoCorpo, maxLargura).forEach(function (ln) {
        ctx.fillText(ln, cx, y);
        y += corpoSize * 1.5;
      });
    }

    return canvas;
  }

  async function baixarPDF(opts, nomeArquivo) {
    var canvas = await montarCanvas(opts);
    var JsPDF = await carregarJsPDF();
    var pdf = new JsPDF({ orientation: 'landscape', unit: 'mm', format: 'a4' });
    var imgData = canvas.toDataURL('image/jpeg', 0.92);
    pdf.addImage(imgData, 'JPEG', 0, 0, 297, 210);
    pdf.save(nomeArquivo || 'certificado.pdf');
  }

  // Gera UM PDF com VÁRIAS páginas (uma por item). Cada item = mesmas opções de
  // baixarPDF ({baseUrl, textoPre, nome, textoCorpo, config}). Usado nos certificados
  // de trabalho: 1 página por autor (relator + coautores) no mesmo arquivo.
  async function baixarPDFVarios(itens, nomeArquivo) {
    var lista = (itens || []).filter(Boolean);
    if (!lista.length) return;
    var JsPDF = await carregarJsPDF();
    var pdf = null;
    for (var i = 0; i < lista.length; i++) {
      var canvas = await montarCanvas(lista[i]);
      var imgData = canvas.toDataURL('image/jpeg', 0.92);
      if (!pdf) pdf = new JsPDF({ orientation: 'landscape', unit: 'mm', format: 'a4' });
      else pdf.addPage('a4', 'landscape');
      pdf.addImage(imgData, 'JPEG', 0, 0, 297, 210);
    }
    pdf.save(nomeArquivo || 'certificados.pdf');
  }

  // Monta a linha de autoria do trabalho: relator primeiro e destacado.
  // Ex.: "Fulana de Tal (relator), Beltrano e Sicrana".
  // `autores` é o array [{nome, eh_relator, ...}]; `relatorNome` é o relator
  // atual (pode ter sido editado no admin, então mandamos ele pra frente).
  function formatarAutores(autores, relatorNome) {
    var lista = Array.isArray(autores) ? autores : [];
    var nomes = lista.map(function (a) { return (a && a.nome ? String(a.nome).trim() : ''); })
      .filter(function (n) { return n; });
    var rel = (relatorNome || '').trim();
    var norm = function (s) { return String(s || '').trim().toLowerCase(); };
    // Tira o relator da lista (se estiver nela) pra recolocá-lo na frente.
    var outros = nomes.filter(function (n) { return norm(n) !== norm(rel); });
    var relatorFinal = rel || (nomes.length ? nomes[0] : '');
    if (!relatorFinal) return '';
    var ordenados = [relatorFinal + ' (relator)'].concat(outros);
    if (ordenados.length === 1) return ordenados[0];
    if (ordenados.length === 2) return ordenados[0] + ' e ' + ordenados[1];
    return ordenados.slice(0, -1).join(', ') + ' e ' + ordenados[ordenados.length - 1];
  }

  // Baixa a arte do Storage como objectURL (evita "tainted canvas" por CORS).
  async function baseUrlDeStorage(sb, bucket, path) {
    if (!path) return null;
    var r = await sb.storage.from(bucket).download(path);
    if (r.error || !r.data) throw new Error('Não foi possível baixar a arte base: ' + (r.error ? r.error.message : 'sem dados'));
    return URL.createObjectURL(r.data);
  }

  window.abenfoCert = {
    LARGURA: LARGURA,
    ALTURA: ALTURA,
    aplicarCampos: aplicarCampos,
    formatarAutores: formatarAutores,
    montarCanvas: montarCanvas,
    baixarPDF: baixarPDF,
    baixarPDFVarios: baixarPDFVarios,
    baseUrlDeStorage: baseUrlDeStorage
  };
})();
