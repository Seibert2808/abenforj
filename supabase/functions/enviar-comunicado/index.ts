// ============================================================
// Edge Function: enviar-comunicado
// Enfileira um e-mail em massa para os associados ativos e já dispara
// o primeiro lote do dia. O restante sai nos dias seguintes, pelo
// processar-fila-comunicados (agendado no Cron do Supabase).
//
// Por que fila: o plano gratuito do Resend entrega ~100 e-mails por dia.
// Com 263 associadas, um disparo único seria recusado no meio do caminho.
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
//   LIMITE_DIARIO         opcional, padrão 95 (cota diária do Resend)
// (SUPABASE_URL, SUPABASE_ANON_KEY e SUPABASE_SERVICE_ROLE_KEY são injetadas automaticamente.)
// ============================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import {
  assinarEmail,
  comRodapeDescadastro,
  cotaDiaria,
  emailValido,
  enviadosHoje,
  lerEnv,
  processarComunicado,
} from "../_shared/envio.ts";

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

    // ---- 4) Teste: sai na hora, sem passar pela fila ----
    if (teste) {
      if (!emailValido(teste)) return json({ erro: "E-mail de teste inválido." }, 400);

      const sig = await assinarEmail(teste, env.UNSUB_SECRET);
      const unsubUrl = `${env.SITE_URL}/descadastrar.html?email=${encodeURIComponent(teste)}&sig=${sig}`;
      const resp = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${env.RESEND_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          from: env.FROM,
          to: [teste],
          reply_to: env.REPLY_TO,
          subject: assunto,
          html: comRodapeDescadastro(corpoHtml, unsubUrl),
        }),
      });

      if (!resp.ok) {
        const txt = (await resp.text().catch(() => resp.statusText)).slice(0, 300);
        return json({ erro: `O Resend recusou o teste. HTTP ${resp.status}: ${txt}` }, 502);
      }

      await admin.from("comunicados").insert({
        assunto, corpo_html: corpoHtml, enviado_por: uid,
        total_destinatarios: 1, total_enviados: 1, total_falhas: 0,
        falhas: [], status: "teste",
      });
      return json({ ok: true, teste: true, enviados: 1 });
    }

    // ---- 5) Monta a lista de destinatárias ----
    const { data: socias, error: socErr } = await admin
      .from("profiles")
      .select("email, nome_completo, nome_social")
      .eq("status", "ativo")
      .not("email", "is", null);
    if (socErr) return json({ erro: "Erro ao carregar associadas: " + socErr.message }, 500);

    const { data: optOut } = await admin.from("descadastros").select("email");
    const bloqueados = new Set((optOut ?? []).map((d: any) => (d.email || "").toLowerCase()));

    const vistos = new Set<string>();
    const destinatarios: { email: string; nome: string }[] = [];
    for (const s of socias ?? []) {
      const email = (s.email || "").trim().toLowerCase();
      if (!emailValido(email) || bloqueados.has(email) || vistos.has(email)) continue;
      vistos.add(email);
      destinatarios.push({ email, nome: (s.nome_social || s.nome_completo || "").trim() });
    }

    if (destinatarios.length === 0) return json({ erro: "Nenhum destinatário válido." }, 400);

    // ---- 6) Cria o comunicado e enfileira todo mundo ----
    const { data: novo, error: insErr } = await admin
      .from("comunicados")
      .insert({
        assunto, corpo_html: corpoHtml, enviado_por: uid,
        total_destinatarios: destinatarios.length,
        total_enviados: 0, total_falhas: 0, falhas: [],
        status: "na_fila",
      })
      .select("id")
      .single();
    if (insErr || !novo) return json({ erro: "Erro ao criar o comunicado: " + (insErr?.message ?? "") }, 500);

    const linhas = destinatarios.map((d) => ({
      comunicado_id: novo.id, email: d.email, nome: d.nome || null,
    }));
    for (let i = 0; i < linhas.length; i += 500) {
      const { error: filaErr } = await admin
        .from("comunicado_destinatarios").insert(linhas.slice(i, i + 500));
      if (filaErr) return json({ erro: "Erro ao montar a fila: " + filaErr.message }, 500);
    }

    // ---- 7) Manda o primeiro lote, respeitando o que já saiu hoje ----
    const jaHoje = await enviadosHoje(admin);
    const orcamento = Math.max(0, cotaDiaria() - jaHoje);

    if (orcamento === 0) {
      return json({
        ok: true, enfileirados: destinatarios.length, enviados: 0,
        restantes: destinatarios.length, concluido: false,
        aviso: "A cota de hoje já foi usada. O primeiro lote sai automaticamente amanhã.",
      });
    }

    const r = await processarComunicado(admin, novo.id, orcamento);
    return json({
      ok: true,
      comunicado_id: novo.id,
      enfileirados: destinatarios.length,
      enviados: r.enviados,
      falhas: r.falhas,
      restantes: r.restantes,
      concluido: r.concluido,
      dias_restantes: Math.ceil(r.restantes / cotaDiaria()),
      aviso: r.motivo,
    });
  } catch (e) {
    return json({ erro: "Erro inesperado: " + (e?.message ?? String(e)) }, 500);
  }
});
