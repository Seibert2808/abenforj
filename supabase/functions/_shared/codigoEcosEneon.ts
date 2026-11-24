// ============================================================
// Montagem e envio (via Resend) do e-mail com o código de inscrição
// do ECOS DO ENEON. Compartilhado por:
//   enviar-codigo-ecos-eneon    (envio direto por inscrito_id)
//   esqueci-codigo-ecos-eneon   (autoatendimento: busca por e-mail)
// ============================================================

interface EnvResend {
  RESEND_API_KEY: string;
  FROM: string;
  REPLY_TO: string;
}

export interface InscritoCodigo {
  nome: string;
  email: string;
  doity_id: string;
  pago_confirmado: boolean;
}

function escapeHtml(s: string): string {
  return String(s ?? "").replace(/[&<>"']/g, (c) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c] as string));
}

function corpoEmailCodigo(i: InscritoCodigo): string {
  const statusPagamento = i.pago_confirmado
    ? "Seu pagamento já foi confirmado."
    : "Ainda estamos conferindo o comprovante de pagamento e confirmaremos em breve.";
  return `
  <div style="font-family:'Helvetica Neue',Arial,sans-serif;font-size:15px;color:#2d2d2d;line-height:1.6;">
    <p>Olá, ${escapeHtml(i.nome)}!</p>
    <p>Este é o seu código de inscrição no ECOS DO ENEON 2026 (não-sócia):</p>
    <p style="font-size:1.3rem;font-weight:700;letter-spacing:0.05em;background:#eef6f0;border:1px solid #cfe3d4;border-radius:8px;padding:0.6rem 1rem;display:inline-block;">
      ${escapeHtml(i.doity_id)}
    </p>
    <p>Guarde este código com cuidado — junto com o e-mail <strong>${escapeHtml(i.email)}</strong>, ele é usado para acessar o sistema, submeter trabalhos científicos e, depois do evento, emitir cursos e declarações.</p>
    <p>${statusPagamento}</p>
    <p>Em caso de dúvidas, escreva para <a href="mailto:abenforio@gmail.com">abenforio@gmail.com</a>.</p>
    <p>Atenciosamente,<br>Comissão Executiva — ECOS DO ENEON 2026<br>ABENFO-RJ</p>
  </div>`;
}

export async function enviarEmailCodigo(
  env: EnvResend,
  inscrito: InscritoCodigo,
): Promise<{ ok: true } | { ok: false; erro: string }> {
  const resp = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${env.RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: env.FROM,
      to: [inscrito.email],
      reply_to: env.REPLY_TO,
      subject: "ECOS DO ENEON 2026 — seu código de inscrição",
      html: corpoEmailCodigo(inscrito),
    }),
  });

  if (!resp.ok) {
    const txt = (await resp.text().catch(() => resp.statusText)).slice(0, 300);
    return { ok: false, erro: `O Resend recusou o envio. HTTP ${resp.status}: ${txt}` };
  }
  return { ok: true };
}
