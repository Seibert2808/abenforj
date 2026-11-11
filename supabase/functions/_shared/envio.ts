// ============================================================
// Lógica de envio dos comunicados, compartilhada por:
//   enviar-comunicado            (enfileira e manda o primeiro lote)
//   processar-fila-comunicados   (manda os lotes dos dias seguintes)
//
// A cota do Resend é diária. Cada rodada calcula quanto ainda cabe hoje
// antes de enviar, então nenhum e-mail é recusado por estouro de limite.
// ============================================================

// Máximo aceito pelo endpoint /emails/batch do Resend numa chamada.
const LOTE_RESEND = 100;
// Respeita o limite de ~2 requisições por segundo.
const PAUSA_ENTRE_LOTES_MS = 600;
// Depois disso a destinatária vira 'falha' e para de ser tentada.
const MAX_TENTATIVAS = 5;

const enc = new TextEncoder();

export interface ResultadoRodada {
  enviados: number;
  falhas: number;
  restantes: number;
  concluido: boolean;
  motivo?: string;
}

// Quantos e-mails ainda cabem hoje. O padrão de 95 (e não 100) deixa uma
// folga para os envios de teste, que consomem a mesma cota do Resend.
export function cotaDiaria(): number {
  const n = Number(Deno.env.get("LIMITE_DIARIO") ?? "95");
  return Number.isFinite(n) && n > 0 ? Math.floor(n) : 95;
}

// A cota do Resend zera à meia-noite UTC, então a contagem segue o mesmo corte.
export async function enviadosHoje(admin: any): Promise<number> {
  const inicioDoDia = new Date();
  inicioDoDia.setUTCHours(0, 0, 0, 0);
  const { count } = await admin
    .from("comunicado_destinatarios")
    .select("id", { count: "exact", head: true })
    .eq("status", "enviado")
    .gte("enviado_em", inicioDoDia.toISOString());
  return count ?? 0;
}

function b64url(bytes: ArrayBuffer): string {
  const b = btoa(String.fromCharCode(...new Uint8Array(bytes)));
  return b.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

export async function assinarEmail(email: string, secret: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw", enc.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, enc.encode(email.toLowerCase()));
  return b64url(sig);
}

export function emailValido(e: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e);
}

// Injeta o rodapé de descadastro (obrigatório p/ LGPD/anti-spam) antes de </body>.
export function comRodapeDescadastro(html: string, unsubUrl: string): string {
  const rodape = `
  <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="margin-top:8px;">
    <tr><td align="center" style="padding:16px;font-family:'Helvetica Neue',Arial,sans-serif;font-size:11px;color:#8a8f8b;line-height:1.5;">
      Você recebe este e-mail por ser associada da ABENFO-RJ.<br>
      <a href="${unsubUrl}" style="color:#8a8f8b;text-decoration:underline;">Não quero mais receber comunicados</a>
    </td></tr>
  </table>`;
  if (html.includes("</body>")) return html.replace("</body>", rodape + "\n</body>");
  return html + rodape;
}

interface Env {
  RESEND_API_KEY: string;
  FROM: string;
  REPLY_TO: string;
  UNSUB_SECRET: string;
  SITE_URL: string;
}

export function lerEnv(): Env {
  return {
    RESEND_API_KEY: Deno.env.get("RESEND_API_KEY") ?? "",
    FROM: Deno.env.get("COMUNICADOS_FROM") ?? "ABENFO-RJ <onboarding@resend.dev>",
    REPLY_TO: Deno.env.get("COMUNICADOS_REPLY_TO") ?? "abenforio@gmail.com",
    UNSUB_SECRET: Deno.env.get("UNSUB_SECRET") ?? "troque-este-segredo",
    SITE_URL: Deno.env.get("SITE_URL") ?? "https://abenforj.org.br",
  };
}

// Monta o payload de um lote e entrega ao Resend.
// Devolve 'ok', 'transitorio' (tenta de novo depois) ou 'permanente'.
async function entregarLote(
  env: Env,
  assunto: string,
  corpoHtml: string,
  lote: { email: string; nome: string | null }[],
): Promise<{ tipo: "ok" | "transitorio" | "permanente"; erro?: string }> {
  const payload = await Promise.all(lote.map(async (d) => {
    const sig = await assinarEmail(d.email, env.UNSUB_SECRET);
    const unsubUrl = `${env.SITE_URL}/descadastrar.html?email=${encodeURIComponent(d.email)}&sig=${sig}`;
    return {
      from: env.FROM,
      to: [d.email],
      reply_to: env.REPLY_TO,
      subject: assunto,
      html: comRodapeDescadastro(corpoHtml, unsubUrl),
      headers: {
        "List-Unsubscribe": `<${unsubUrl}>, <mailto:${env.REPLY_TO}?subject=Descadastrar>`,
      },
    };
  }));

  let resp: Response;
  try {
    resp = await fetch("https://api.resend.com/emails/batch", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${env.RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    });
  } catch (e) {
    // Rede falhou: ninguém foi entregue, tenta de novo no próximo lote.
    return { tipo: "transitorio", erro: "Falha de rede: " + (e?.message ?? String(e)) };
  }

  if (resp.ok) return { tipo: "ok" };

  const txt = (await resp.text().catch(() => resp.statusText)).slice(0, 300);
  // 429 = cota/rate limit, 5xx = problema do Resend. Nos dois casos vale insistir.
  const transitorio = resp.status === 429 || resp.status >= 500;
  return { tipo: transitorio ? "transitorio" : "permanente", erro: `HTTP ${resp.status}: ${txt}` };
}

// Processa um comunicado até o limite de e-mails informado.
// Não envia nada além de `orcamento`, mesmo que sobrem pendentes.
export async function processarComunicado(
  admin: any,
  comunicadoId: string,
  orcamento: number,
): Promise<ResultadoRodada> {
  const env = lerEnv();

  const { data: com, error: comErr } = await admin
    .from("comunicados")
    .select("id, assunto, corpo_html")
    .eq("id", comunicadoId)
    .single();
  if (comErr || !com) {
    return { enviados: 0, falhas: 0, restantes: 0, concluido: false, motivo: "Comunicado não encontrado." };
  }

  let enviados = 0;
  let falhas = 0;

  while (enviados + falhas < orcamento) {
    const faltaNoOrcamento = orcamento - enviados - falhas;
    const tamanho = Math.min(LOTE_RESEND, faltaNoOrcamento);

    const { data: pendentes, error: pendErr } = await admin
      .from("comunicado_destinatarios")
      .select("id, email, nome, tentativas")
      .eq("comunicado_id", comunicadoId)
      .eq("status", "pendente")
      .order("criado_em", { ascending: true })
      .limit(tamanho);
    if (pendErr) break;
    if (!pendentes || pendentes.length === 0) break;

    const ids = pendentes.map((p: any) => p.id);
    const r = await entregarLote(env, com.assunto, com.corpo_html, pendentes);

    if (r.tipo === "ok") {
      await admin.from("comunicado_destinatarios")
        .update({ status: "enviado", enviado_em: new Date().toISOString(), erro: null })
        .in("id", ids);
      enviados += pendentes.length;
    } else if (r.tipo === "permanente") {
      await admin.from("comunicado_destinatarios")
        .update({ status: "falha", erro: r.erro })
        .in("id", ids);
      falhas += pendentes.length;
    } else {
      // Transitório: incrementa a tentativa e devolve para a fila.
      // Quem estourou o teto de tentativas vira falha para não travar o resto.
      const esgotados = pendentes.filter((p: any) => (p.tentativas ?? 0) + 1 >= MAX_TENTATIVAS);
      const seguem = pendentes.filter((p: any) => (p.tentativas ?? 0) + 1 < MAX_TENTATIVAS);
      for (const p of seguem) {
        await admin.from("comunicado_destinatarios")
          .update({ tentativas: (p.tentativas ?? 0) + 1, erro: r.erro })
          .eq("id", p.id);
      }
      if (esgotados.length) {
        await admin.from("comunicado_destinatarios")
          .update({ status: "falha", erro: r.erro })
          .in("id", esgotados.map((p: any) => p.id));
        falhas += esgotados.length;
      }
      // Erro transitório interrompe a rodada: insistir agora repetiria o mesmo erro.
      await atualizarTotais(admin, comunicadoId);
      const restantes = await contarPendentes(admin, comunicadoId);
      return { enviados, falhas, restantes, concluido: false, motivo: r.erro };
    }

    if (enviados + falhas < orcamento) {
      await new Promise((res) => setTimeout(res, PAUSA_ENTRE_LOTES_MS));
    }
  }

  await atualizarTotais(admin, comunicadoId);
  const restantes = await contarPendentes(admin, comunicadoId);
  return { enviados, falhas, restantes, concluido: restantes === 0 };
}

export async function contarPendentes(admin: any, comunicadoId: string): Promise<number> {
  const { count } = await admin
    .from("comunicado_destinatarios")
    .select("id", { count: "exact", head: true })
    .eq("comunicado_id", comunicadoId)
    .eq("status", "pendente");
  return count ?? 0;
}

// Recalcula os totais a partir da fila (fonte da verdade) e ajusta o status.
async function atualizarTotais(admin: any, comunicadoId: string): Promise<void> {
  const contar = async (status: string) => {
    const { count } = await admin
      .from("comunicado_destinatarios")
      .select("id", { count: "exact", head: true })
      .eq("comunicado_id", comunicadoId)
      .eq("status", status);
    return count ?? 0;
  };

  const [enviados, falhas, pendentes] = await Promise.all([
    contar("enviado"), contar("falha"), contar("pendente"),
  ]);

  await admin.from("comunicados").update({
    total_enviados: enviados,
    total_falhas: falhas,
    ultimo_lote_em: new Date().toISOString(),
    status: pendentes > 0 ? "em_andamento" : "concluido",
  }).eq("id", comunicadoId);
}
