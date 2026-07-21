// ============================================================
// Edge Function: enviar-comunicado
// Envia um e-mail em massa aos associados ativos via Resend.
//
// Segurança: só executa se o chamador for admin (profiles.is_admin).
// O JWT do admin chega no header Authorization (o cliente Supabase
// do admin.html envia automaticamente ao usar sb.functions.invoke).
//
// Variáveis de ambiente (secrets) necessárias — ver docs/COMUNICADOS-setup.md:
//   RESEND_API_KEY        chave da API do Resend
//   COMUNICADOS_FROM      remetente, ex: "ABENFO-RJ <comunicados@abenforj.org.br>"
//   COMUNICADOS_REPLY_TO  ex: "abenforio@gmail.com"
//   UNSUB_SECRET          segredo p/ assinar o link de descadastro
//   SITE_URL              ex: "https://abenforj.org.br"
// (SUPABASE_URL, SUPABASE_ANON_KEY e SUPABASE_SERVICE_ROLE_KEY são injetadas automaticamente.)
// ============================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

const TAMANHO_LOTE = 100;        // Resend: máx. 100 e-mails por chamada batch
const PAUSA_ENTRE_LOTES_MS = 600; // respeita o limite de ~2 req/s

const enc = new TextEncoder();

function b64url(bytes: ArrayBuffer): string {
  const b = btoa(String.fromCharCode(...new Uint8Array(bytes)));
  return b.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function assinarEmail(email: string, secret: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw", enc.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, enc.encode(email.toLowerCase()));
  return b64url(sig);
}

function emailValido(e: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e);
}

// Injeta o rodapé de descadastro (obrigatório p/ LGPD/anti-spam) antes de </body>.
function comRodapeDescadastro(html: string, unsubUrl: string): string {
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

Deno.serve(async (req) => {
  const origin = req.headers.get("Origin");
  const cors = corsHeaders(origin);

  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ erro: "Método não permitido" }), {
      status: 405, headers: { ...cors, "Content-Type": "application/json" },
    });
  }

  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status, headers: { ...cors, "Content-Type": "application/json" },
    });

  try {
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
    const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
    const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");
    const FROM = Deno.env.get("COMUNICADOS_FROM") ?? "ABENFO-RJ <onboarding@resend.dev>";
    const REPLY_TO = Deno.env.get("COMUNICADOS_REPLY_TO") ?? "abenforio@gmail.com";
    const UNSUB_SECRET = Deno.env.get("UNSUB_SECRET") ?? "troque-este-segredo";
    const SITE_URL = Deno.env.get("SITE_URL") ?? "https://abenforj.org.br";

    if (!RESEND_API_KEY) return json({ erro: "RESEND_API_KEY não configurada no servidor." }, 500);

    // ---- 1) Autenticação: quem está chamando? ----
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ erro: "Não autenticado." }, 401);

    const userClient = createClient(SUPABASE_URL, ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userErr } = await userClient.auth.getUser();
    if (userErr || !userData?.user) return json({ erro: "Sessão inválida." }, 401);
    const uid = userData.user.id;

    // ---- 2) Autorização: é admin? (checado com service role) ----
    const admin = createClient(SUPABASE_URL, SERVICE_KEY);
    const { data: perfil, error: perfilErr } = await admin
      .from("profiles").select("is_admin").eq("id", uid).single();
    if (perfilErr || !perfil?.is_admin) {
      return json({ erro: "Acesso restrito a administradores." }, 403);
    }

    // ---- 3) Payload ----
    const body = await req.json().catch(() => ({}));
    const assunto = (body.assunto ?? "").toString().trim();
    const corpoHtml = (body.corpo_html ?? "").toString();
    const teste = body.teste ? body.teste.toString().trim() : null; // e-mail único p/ prévia

    if (!assunto) return json({ erro: "Informe o assunto." }, 400);
    if (!corpoHtml || corpoHtml.length < 20) return json({ erro: "Corpo do e-mail vazio." }, 400);

    // ---- 4) Monta a lista de destinatários ----
    let destinatarios: { email: string; nome: string }[] = [];

    if (teste) {
      if (!emailValido(teste)) return json({ erro: "E-mail de teste inválido." }, 400);
      destinatarios = [{ email: teste, nome: "Teste" }];
    } else {
      const { data: socias, error: socErr } = await admin
        .from("profiles")
        .select("email, nome_completo, nome_social")
        .eq("status", "ativo")
        .not("email", "is", null);
      if (socErr) return json({ erro: "Erro ao carregar associadas: " + socErr.message }, 500);

      const { data: optOut } = await admin.from("descadastros").select("email");
      const bloqueados = new Set((optOut ?? []).map((d) => (d.email || "").toLowerCase()));

      const vistos = new Set<string>();
      for (const s of socias ?? []) {
        const email = (s.email || "").trim().toLowerCase();
        if (!emailValido(email) || bloqueados.has(email) || vistos.has(email)) continue;
        vistos.add(email);
        destinatarios.push({ email, nome: (s.nome_social || s.nome_completo || "").trim() });
      }
    }

    if (destinatarios.length === 0) return json({ erro: "Nenhum destinatário válido." }, 400);

    // ---- 5) Envio em lotes via Resend (batch) ----
    let enviados = 0;
    const falhas: { email: string; erro: string }[] = [];

    for (let i = 0; i < destinatarios.length; i += TAMANHO_LOTE) {
      const lote = destinatarios.slice(i, i + TAMANHO_LOTE);

      const payload = await Promise.all(lote.map(async (d) => {
        const sig = await assinarEmail(d.email, UNSUB_SECRET);
        const unsubUrl = `${SITE_URL}/descadastrar.html?email=${encodeURIComponent(d.email)}&sig=${sig}`;
        return {
          from: FROM,
          to: [d.email],
          reply_to: REPLY_TO,
          subject: assunto,
          html: comRodapeDescadastro(corpoHtml, unsubUrl),
          headers: {
            "List-Unsubscribe": `<${unsubUrl}>, <mailto:${REPLY_TO}?subject=Descadastrar>`,
          },
        };
      }));

      const resp = await fetch("https://api.resend.com/emails/batch", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${RESEND_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(payload),
      });

      if (resp.ok) {
        const r = await resp.json().catch(() => ({}));
        const qtd = Array.isArray(r?.data) ? r.data.length : lote.length;
        enviados += qtd;
      } else {
        const txt = await resp.text().catch(() => resp.statusText);
        lote.forEach((d) => falhas.push({ email: d.email, erro: `HTTP ${resp.status}: ${txt.slice(0, 200)}` }));
      }

      if (i + TAMANHO_LOTE < destinatarios.length) {
        await new Promise((r) => setTimeout(r, PAUSA_ENTRE_LOTES_MS));
      }
    }

    // ---- 6) Registra no histórico ----
    await admin.from("comunicados").insert({
      assunto,
      corpo_html: corpoHtml,
      enviado_por: uid,
      total_destinatarios: destinatarios.length,
      total_enviados: enviados,
      total_falhas: falhas.length,
      falhas,
      status: teste ? "teste" : (falhas.length && !enviados ? "erro" : "enviado"),
    });

    return json({
      ok: true,
      teste: !!teste,
      total_destinatarios: destinatarios.length,
      enviados,
      falhas: falhas.length,
      detalhe_falhas: falhas.slice(0, 20),
    });
  } catch (e) {
    return json({ erro: "Erro inesperado: " + (e?.message ?? String(e)) }, 500);
  }
});
