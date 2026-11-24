// ============================================================
// Edge Function: esqueci-codigo-ecos-eneon
// Autoatendimento pra quem perdeu o código de inscrição do ECOS DO
// ENEON: a pessoa informa o e-mail usado na inscrição e recebe o
// código de volta, sem precisar escrever pra diretoria.
//
// Segurança:
//   - Resposta SEMPRE genérica (não diz se o e-mail existe ou não),
//     pra não virar ferramenta de descobrir quem está inscrito.
//   - Cooldown de COOLDOWN_MIN entre reenvios pro mesmo registro,
//     pra impedir que alguém martele o formulário mandando e-mails
//     repetidos pra um terceiro.
//
// Variáveis de ambiente: as mesmas do enviar-codigo-ecos-eneon
// (RESEND_API_KEY, COMUNICADOS_FROM, COMUNICADOS_REPLY_TO).
// ============================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import { emailValido, lerEnv } from "../_shared/envio.ts";
import { enviarEmailCodigo } from "../_shared/codigoEcosEneon.ts";

const COOLDOWN_MIN = 2;

Deno.serve(async (req) => {
  const origin = req.headers.get("Origin");
  const cors = corsHeaders(origin);

  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status, headers: { ...cors, "Content-Type": "application/json" },
    });

  if (req.method !== "POST") return json({ erro: "Método não permitido" }, 405);

  // Resposta igual em todo caminho "não deu pra enviar por causa do
  // e-mail informado" — quem pergunta não descobre se o e-mail está
  // cadastrado ou não.
  const MENSAGEM_GENERICA = {
    ok: true,
    mensagem: "Se encontrarmos uma inscrição com esse e-mail no ECOS DO ENEON, vamos reenviar o código agora.",
  };

  try {
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
    const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const env = lerEnv();
    if (!env.RESEND_API_KEY) return json({ erro: "RESEND_API_KEY não configurada no servidor." }, 500);

    const body = await req.json().catch(() => ({}));
    const email = (body.email ?? "").toString().trim().toLowerCase();
    if (!email || !emailValido(email)) return json({ erro: "Informe um e-mail válido." }, 400);

    const admin = createClient(SUPABASE_URL, SERVICE_KEY);

    const { data: eventoId } = await admin.rpc("evento_ecos_eneon_id");
    if (!eventoId) return json(MENSAGEM_GENERICA);

    const { data: inscrito } = await admin
      .from("inscritos_externos")
      .select("id, nome, email, doity_id, pago_confirmado")
      .eq("evento_id", eventoId)
      .eq("email", email)
      .maybeSingle();
    if (!inscrito) return json(MENSAGEM_GENERICA);

    // Cooldown: olha o envio mais recente pra esse inscrito.
    const { data: ultimoEnvio } = await admin
      .from("emails_enviados")
      .select("enviado_em")
      .eq("inscrito_externo_id", inscrito.id)
      .order("enviado_em", { ascending: false })
      .limit(1)
      .maybeSingle();
    if (ultimoEnvio) {
      const minDesdeUltimo = (Date.now() - new Date(ultimoEnvio.enviado_em).getTime()) / 60000;
      if (minDesdeUltimo < COOLDOWN_MIN) return json(MENSAGEM_GENERICA);
    }

    const envio = await enviarEmailCodigo(env, inscrito as any);
    if (!envio.ok) {
      // Erro do Resend não é culpa de quem pediu — loga pro admin investigar,
      // mas devolve a mesma mensagem genérica pra não revelar nada.
      console.error("esqueci-codigo-ecos-eneon: falha no envio:", envio.erro);
      return json(MENSAGEM_GENERICA);
    }

    await admin.from("emails_enviados").insert({ inscrito_externo_id: inscrito.id });

    return json(MENSAGEM_GENERICA);
  } catch (e) {
    console.error("esqueci-codigo-ecos-eneon: erro inesperado:", e);
    return json(MENSAGEM_GENERICA);
  }
});
