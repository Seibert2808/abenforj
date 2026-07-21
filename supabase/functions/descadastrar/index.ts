// ============================================================
// Edge Function: descadastrar
// Registra um e-mail na tabela `descadastros` (opt-out de comunicados).
// Chamada pela página pública descadastrar.html.
// Verifica a assinatura HMAC do link para impedir que alguém
// descadastre terceiros.
//
// Variáveis: UNSUB_SECRET (mesmo valor usado em enviar-comunicado).
// (SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY são injetadas automaticamente.)
// ============================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

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

Deno.serve(async (req) => {
  const origin = req.headers.get("Origin");
  const cors = corsHeaders(origin);
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status, headers: { ...cors, "Content-Type": "application/json" },
    });

  if (req.method !== "POST") return json({ erro: "Método não permitido" }, 405);

  try {
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
    const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const UNSUB_SECRET = Deno.env.get("UNSUB_SECRET") ?? "troque-este-segredo";

    const body = await req.json().catch(() => ({}));
    const email = (body.email ?? "").toString().trim().toLowerCase();
    const sig = (body.sig ?? "").toString();
    const motivo = (body.motivo ?? "").toString().slice(0, 500) || null;

    if (!email || !sig) return json({ erro: "Dados incompletos." }, 400);

    const esperado = await assinarEmail(email, UNSUB_SECRET);
    if (sig !== esperado) return json({ erro: "Link inválido ou expirado." }, 403);

    const admin = createClient(SUPABASE_URL, SERVICE_KEY);
    const { error } = await admin
      .from("descadastros")
      .upsert({ email, motivo }, { onConflict: "email" });
    if (error) return json({ erro: "Erro ao registrar: " + error.message }, 500);

    return json({ ok: true });
  } catch (e) {
    return json({ erro: "Erro inesperado: " + (e?.message ?? String(e)) }, 500);
  }
});
