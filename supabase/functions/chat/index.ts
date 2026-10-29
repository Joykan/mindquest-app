// Chat Edge Function (UC-01 Conduct AI chat session).
//
// POST { "text": "...", "session_id": "..." (optional) }
// with the signed-in user's access token in the Authorization header.
//
// 1. Check the message for crisis phrases. If found: log a crisis event (no
//    message text), skip the model and return the verified helplines.
// 2. Otherwise send the text to the Rasa server and pick a reply (logic.ts).
//    If Rasa can't be reached, the backup model (backup_nlu.ts) reads the
//    message instead, so Chipu still answers.
// 3. Save the user's message and the reply. Saving the user's message awards
//    chat XP through the database trigger.
//
// The reply is saved with response_ms (time from the request arriving to the
// reply being ready) and nlu_ms (time the Rasa call took), so the admin
// dashboard can check NFR-SPEC-01: replies within 2 seconds for 95% of messages.
//
// Secrets: RASA_URL (e.g. https://name.ngrok-free.app) and RASA_TOKEN (the
// --auth-token Rasa was started with). SUPABASE_URL and
// SUPABASE_SERVICE_ROLE_KEY are provided by Supabase.

import { createClient } from "@supabase/supabase-js";
import { isCrisis } from "./crisis.ts";
import { BACKUP_THRESHOLD, backupParse } from "./backup_nlu.ts";
import { decide, type RasaParse, THRESHOLD } from "./logic.ts";
import { type Lang, REPLIES } from "./replies.ts";

const MAX_LENGTH = 1000;
// Rasa normally answers in well under a second; after 3 s the backup model
// answers instead, so the student isn't kept waiting.
const RASA_TIMEOUT_MS = 3000;

/** Used only if no helpline has been verified yet. Kenya's emergency numbers. */
const EMERGENCY_FALLBACK: Record<Lang, { name: string; phone: string; description: string }[]> = {
  en: [
    { name: "Emergency services", phone: "999", description: "Police, ambulance and fire" },
    { name: "Emergency services", phone: "112", description: "Works from any mobile phone" },
  ],
  sw: [
    { name: "Huduma za dharura", phone: "999", description: "Polisi, ambulensi na zimamoto" },
    { name: "Huduma za dharura", phone: "112", description: "Inafanya kazi kutoka simu yoyote ya mkononi" },
  ],
};

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

async function askRasa(text: string): Promise<RasaParse | null> {
  const url = Deno.env.get("RASA_URL");
  const token = Deno.env.get("RASA_TOKEN");
  if (!url || !token) return null;
  try {
    const res = await fetch(
      `${url.replace(/\/$/, "")}/model/parse?token=${encodeURIComponent(token)}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json", "ngrok-skip-browser-warning": "1" },
        body: JSON.stringify({ text }),
        signal: AbortSignal.timeout(RASA_TIMEOUT_MS),
      },
    );
    if (!res.ok) {
      console.error("rasa status", res.status);
      return null;
    }
    return (await res.json()) as RasaParse;
  } catch (e) {
    console.error("rasa unreachable", (e as Error).message);
    return null;
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);
  const started = performance.now();
  const elapsed = () => Math.round(performance.now() - started);

  // Who is asking?
  const jwt = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!jwt) return json({ error: "not signed in" }, 401);
  const { data: auth, error: authError } = await db.auth.getUser(jwt);
  if (authError || !auth?.user) return json({ error: "not signed in" }, 401);
  const userId = auth.user.id;

  // What did they send?
  let body: { text?: unknown; session_id?: unknown };
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid JSON" }, 400);
  }
  const text = typeof body.text === "string" ? body.text.trim() : "";
  if (!text) return json({ error: "text is required" }, 400);
  if (text.length > MAX_LENGTH) return json({ error: `text is longer than ${MAX_LENGTH} characters` }, 400);

  const { data: profile } = await db.from("profiles").select("language").eq("id", userId).single();
  const lang: Lang = profile?.language === "sw" ? "sw" : "en";

  // Use the given session if it is theirs and still open, otherwise start one.
  let sessionId: string | null = null;
  if (typeof body.session_id === "string") {
    const { data: s } = await db.from("chat_sessions").select("id")
      .eq("id", body.session_id).eq("user_id", userId).is("ended_at", null).maybeSingle();
    sessionId = s?.id ?? null;
  }
  if (!sessionId) {
    const { data: s, error } = await db.from("chat_sessions").insert({ user_id: userId }).select("id")
      .single();
    if (error) return json({ error: "could not start a session" }, 500);
    sessionId = s.id;
  }

  // 1. Crisis check, before the model.
  if (isCrisis(text)) {
    await db.from("crisis_events").insert({ user_id: userId });
    const { data: lines } = await db.from("helplines").select("name, phone, description, description_sw")
      .eq("verified", true).order("sort_order");
    // Descriptions in the user's language (the names are the organisations' own).
    const helplines = lines && lines.length > 0
      ? lines.map((l) => ({
        name: l.name,
        phone: l.phone,
        description: lang === "sw" && l.description_sw ? l.description_sw : l.description,
      }))
      : EMERGENCY_FALLBACK[lang];
    const reply = REPLIES.crisis[lang][0];
    await db.from("messages").insert({
      session_id: sessionId,
      sender: "user",
      content: text,
      intent: "crisis",
    });
    await db.from("messages").insert({
      session_id: sessionId,
      sender: "bot",
      content: reply,
      reply_key: "crisis",
      response_ms: elapsed(),
    });
    return json({
      session_id: sessionId,
      reply,
      crisis: true,
      helplines,
      intent: "crisis",
      confidence: null,
    });
  }

  // 2. Ask Rasa and pick the reply, using the bot's last message for context.
  const { data: last } = await db.from("messages").select("reply_key")
    .eq("session_id", sessionId).eq("sender", "bot")
    .order("created_at", { ascending: false }).limit(1).maybeSingle();
  const nluStarted = performance.now();
  const fromRasa = await askRasa(text);
  const nluSource = fromRasa ? "rasa" : "backup";
  const parse = fromRasa ?? backupParse(text);
  const nluMs = Math.round(performance.now() - nluStarted);
  const decision = decide(
    parse,
    last?.reply_key ?? null,
    lang,
    Math.random,
    text,
    fromRasa ? THRESHOLD : BACKUP_THRESHOLD,
  );
  const responseMs = elapsed();

  // 3. Save both messages (two inserts so the user's comes first).
  const { error: e1 } = await db.from("messages").insert({
    session_id: sessionId,
    sender: "user",
    content: text,
    intent: decision.intent,
    confidence: decision.confidence,
  });
  const { error: e2 } = await db.from("messages").insert({
    session_id: sessionId,
    sender: "bot",
    content: decision.text,
    reply_key: decision.replyKey,
    response_ms: responseMs,
    nlu_ms: nluMs,
    nlu_source: nluSource,
  });
  if (e1 || e2) console.error("save failed", e1?.message, e2?.message);

  return json({
    session_id: sessionId,
    reply: decision.text,
    crisis: false,
    intent: decision.intent,
    confidence: decision.confidence,
  });
});
