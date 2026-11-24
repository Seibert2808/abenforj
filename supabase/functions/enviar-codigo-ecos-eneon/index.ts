// ============================================================
// Edge Function: enviar-codigo-ecos-eneon
// Manda por e-mail (Resend) o código de inscrição de uma não-sócia
// no ECOS DO ENEON. Substitui o fluxo manual (abrir rascunho no
// Gmail pelo admin) por um envio automático de verdade.
//
// Dois chamadores:
//   1) inscricao-ecos-eneon.html (anônimo) — logo depois da inscrição
//      ser criada, manda o e-mail de confirmação sozinho.
//   2) area/inscricoes-pix.html (admin logada) — botão "Reenviar
//      código por e-mail", pra quando a sócia perdeu o e-mail original.
//
// Segurança: o conteúdo do e-mail é sempre montado aqui a partir do
// registro em inscritos_externos (nunca vem do cliente), então o
// endpoint não pode ser usado como relay de e-mail arbitrário. Sem
// JWT de admin, só manda se a inscrição foi criada há menos de
// INSCRICAO_RECENTE_MIN minutos e ainda não tiver nenhum envio
// registrado — isso cobre o envio automático pós-inscrição sem abrir
// brecha pra alguém martelar o endpoint reenviando pra terceiros.
//
// Variáveis de ambiente (secrets) — as mesmas já configuradas pra
// Comunicados (ver docs/COMUNICADOS-setup.md):
//   RESEND_API_KEY, COMUNICADOS_FROM, COMUNICADOS_REPLY_TO, SITE_URL
// (SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY são injetadas automaticamente.)
// ============================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import { lerEnv } from "../_shared/envio.ts";
import { enviarEmailCodigo } from "../_shared/codigoEcosEneon.ts";

const INSCRICAO_RECENTE_MIN = 15;

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
    const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
    const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const env = lerEnv();
    if (!env.RESEND_API_KEY) return json({ erro: "RESEND_API_KEY não configurada no servidor." }, 500);

    const body = await req.json().catch(() => ({}));
    const inscritoId = (body.inscrito_id ?? "").toString().trim();
    if (!inscritoId) return json({ erro: "Informe inscrito_id." }, 400);

    const admin = createClient(SUPABASE_URL, SERVICE_KEY);

    // ---- Quem está chamando: admin autenticada ou anônimo? ----
    let chamadorAdmin = false;
    let uidAdmin: string | null = null;
    const authHeader = req.headers.get("Authorization");
    if (authHeader) {
      const userClient = createClient(SUPABASE_URL, ANON_KEY, {
        global: { headers: { Authorization: authHeader } },
      });
      const { data: userData } = await userClient.auth.getUser();
      if (userData?.user) {
        const { data: perfil } = await admin
          .from("profiles").select("is_admin").eq("id", userData.user.id).single();
        if (perfil?.is_admin) {
          chamadorAdmin = true;
          uidAdmin = userData.user.id;
        }
      }
    }

    const { data: inscrito, error: insErr } = await admin
      .from("inscritos_externos")
      .select("id, nome, email, doity_id, pago_confirmado, created_at")
      .eq("id", inscritoId)
      .single();
    if (insErr || !inscrito) return json({ erro: "Inscrição não encontrada." }, 404);

    // ---- Chamada anônima: só deixa passar se for logo após a inscrição
    // e ainda sem nenhum envio — fecha a porta pra reenvio sem ser admin. ----
    if (!chamadorAdmin) {
      const criadoHaMin = (Date.now() - new Date(inscrito.created_at).getTime()) / 60000;
      if (criadoHaMin > INSCRICAO_RECENTE_MIN) {
        return json({ erro: "Use a página \"Esqueci meu código\" para receber de novo." }, 403);
      }
      const { count } = await admin
        .from("emails_enviados")
        .select("id", { count: "exact", head: true })
        .eq("inscrito_externo_id", inscritoId);
      if ((count ?? 0) > 0) {
        return json({ erro: "Já enviamos esse código antes. Use a página \"Esqueci meu código\" para receber de novo." }, 403);
      }
    }

    const envio = await enviarEmailCodigo(env, inscrito as any);
    if (!envio.ok) return json({ erro: envio.erro }, 502);

    await admin.from("emails_enviados").insert({
      inscrito_externo_id: inscritoId,
      enviado_por: uidAdmin,
    });

    return json({ ok: true });
  } catch (e) {
    return json({ erro: "Erro inesperado: " + (e?.message ?? String(e)) }, 500);
  }
});
