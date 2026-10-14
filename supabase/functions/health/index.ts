// Health Edge Function (use case "Monitor System Health", admin dashboard).
//
// POST with an administrator's or counsellor's access token. Checks that the
// database answers and that the Rasa NLU server is reachable with its model
// loaded, and how long each took. Returns no user data.
//
// Secrets: RASA_URL and RASA_TOKEN (the same as the chat function).

import { createClient } from "@supabase/supabase-js";

const RASA_TIMEOUT_MS = 8000;

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

const db = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

type Check = { ok: boolean; ms: number; detail?: string };

async function timed(check: () => Promise<string | undefined>): Promise<Check> {
  const started = performance.now();
  try {
    const detail = await check();
    return { ok: true, ms: Math.round(performance.now() - started), detail };
  } catch (e) {
    return { ok: false, ms: Math.round(performance.now() - started), detail: (e as Error).message };
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  // Only staff may run the checks.
  const jwt = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!jwt) return json({ error: "not signed in" }, 401);
  const { data: auth, error: authError } = await db.auth.getUser(jwt);
  if (authError || !auth?.user) return json({ error: "not signed in" }, 401);
  const { data: me } = await db.from("profiles").select("role").eq("id", auth.user.id).maybeSingle();
  if (me?.role !== "admin" && me?.role !== "counsellor") {
    return json({ error: "only administrators and counsellors" }, 403);
  }

  const database = await timed(async () => {
    const { error } = await db.from("badges").select("id").limit(1);
    if (error) throw new Error(error.message);
    return undefined;
  });

  const nlu = await timed(async () => {
    const url = Deno.env.get("RASA_URL");
    const token = Deno.env.get("RASA_TOKEN");
    if (!url || !token) throw new Error("RASA_URL or RASA_TOKEN is not set");
    const res = await fetch(`${url.replace(/\/$/, "")}/status?token=${encodeURIComponent(token)}`, {
      headers: { "ngrok-skip-browser-warning": "1" },
      signal: AbortSignal.timeout(RASA_TIMEOUT_MS),
    });
    if (!res.ok) throw new Error(`status ${res.status}`);
    const body = await res.json() as { model_file?: string };
    if (!body.model_file) throw new Error("no model loaded");
    // Only the file name, e.g. mindquest.tar.gz.
    return body.model_file.split(/[\\/]/).pop();
  });

  return json({ checked_at: new Date().toISOString(), database, nlu });
});
