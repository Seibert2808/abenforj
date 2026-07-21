// CORS compartilhado pelas Edge Functions da ABENFO-RJ.
// Ajuste ORIGENS_PERMITIDAS se o domínio mudar.
const ORIGENS_PERMITIDAS = [
  "https://abenforj.org.br",
  "https://www.abenforj.org.br",
  "http://localhost:3000",
  "http://127.0.0.1:5500",
];

export function corsHeaders(origin: string | null): Record<string, string> {
  const permitida = origin && ORIGENS_PERMITIDAS.includes(origin)
    ? origin
    : ORIGENS_PERMITIDAS[0];
  return {
    "Access-Control-Allow-Origin": permitida,
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  };
}
