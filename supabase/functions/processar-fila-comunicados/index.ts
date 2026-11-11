// ============================================================
// Edge Function: processar-fila-comunicados
// Envia o lote do dia dos comunicados que ainda têm gente na fila.
//
// Roda de duas formas:
//   1. Automática, todo dia, pelo Cron do Supabase (pg_cron + pg_net).
//      Autentica pelo header x-fila-secret, comparado ao secret FILA_SECRET.
//   2. Manual, pelo botão "Enviar o próximo lote agora" no painel admin.
//      Autentica pelo JWT da admin, como as outras funções.
//
// Nunca ultrapassa a cota diária: o que já saiu hoje é descontado antes.
// Rodar duas vezes no mesmo dia não envia nada duplicado.
//
// Variáveis: as mesmas do enviar-comunicado, mais FILA_SECRET.
// ============================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import { cotaDiaria, enviadosHoje, lerEnv, processarComunicado } from "../_shared/envio.ts";

// Comparação em tempo constante, para não vazar o segredo por timing.
function segredoConfere(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let dif = 0;
  for (let i = 0; i < a.length; i++) dif |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return dif === 0;
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
    const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
    const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const FILA_SECRET = Deno.env.get("FILA_SECRET") ?? "";
    const env = lerEnv();

    if (!env.RESEND_API_KEY) return json({ erro: "RESEND_API_KEY não configurada no servidor." }, 500);

    const admin = createClient(SUPABASE_URL, SERVICE_KEY);

    // ---- Autorização: o agendador (secret) ou uma admin logada (JWT) ----
    const segredoRecebido = req.headers.get("x-fila-secret") ?? "";
    const veioDoCron = FILA_SECRET.length > 0 && segredoConfere(segredoRecebido, FILA_SECRET);

    if (!veioDoCron) {
      const authHeader = req.headers.get("Authorization");
      if (!authHeader) return json({ erro: "Não autenticado." }, 401);

      const userClient = createClient(SUPABASE_URL, ANON_KEY, {
        global: { headers: { Authorization: authHeader } },
      });
      const { data: userData, error: userErr } = await userClient.auth.getUser();
      if (userErr || !userData?.user) return json({ erro: "Sessão inválida." }, 401);

      const { data: perfil } = await admin
        .from("profiles").select("is_admin").eq("id", userData.user.id).single();
      if (!perfil?.is_admin) return json({ erro: "Acesso restrito a administradores." }, 403);
    }

    // ---- Quanto ainda cabe hoje ----
    const jaHoje = await enviadosHoje(admin);
    let orcamento = Math.max(0, cotaDiaria() - jaHoje);

    if (orcamento === 0) {
      return json({
        ok: true, enviados: 0, ja_enviados_hoje: jaHoje,
        aviso: "A cota de hoje já foi usada. O próximo lote sai amanhã.",
      });
    }

    // ---- Comunicados que ainda têm gente na fila, do mais antigo ao mais novo ----
    const { data: abertos, error: abertosErr } = await admin
      .from("comunicados")
      .select("id, assunto")
      .in("status", ["na_fila", "em_andamento"])
      .order("enviado_em", { ascending: true });
    if (abertosErr) return json({ erro: "Erro ao ler a fila: " + abertosErr.message }, 500);

    if (!abertos || abertos.length === 0) {
      return json({ ok: true, enviados: 0, aviso: "Nenhum comunicado pendente na fila." });
    }

    const relatorio: any[] = [];
    let totalEnviados = 0;
    let totalFalhas = 0;

    for (const c of abertos) {
      if (orcamento <= 0) break;
      const r = await processarComunicado(admin, c.id, orcamento);
      totalEnviados += r.enviados;
      totalFalhas += r.falhas;
      orcamento -= (r.enviados + r.falhas);
      relatorio.push({
        comunicado_id: c.id, assunto: c.assunto,
        enviados: r.enviados, falhas: r.falhas,
        restantes: r.restantes, concluido: r.concluido, motivo: r.motivo,
      });
      // Erro transitório (Resend fora do ar, cota estourada): para a rodada.
      if (r.motivo) break;
    }

    return json({
      ok: true,
      ja_enviados_hoje: jaHoje,
      enviados: totalEnviados,
      falhas: totalFalhas,
      sobra_da_cota: Math.max(0, orcamento),
      comunicados: relatorio,
    });
  } catch (e) {
    return json({ erro: "Erro inesperado: " + (e?.message ?? String(e)) }, 500);
  }
});
