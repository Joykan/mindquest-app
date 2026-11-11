// Chat Edge Function (UC-01 Conduct AI chat session).
//
// POST { "text": "...", "session_id": "..." (optional) }
// with the signed-in user's access token in the Authorization header.
//
// POST { "action": "opening" } when the app opens a new chat: if the user
// told Chipu about a worry on one of the last three days (not today), Chipu
// starts the chat by checking in on it ("Last time you told me school was
// weighing on you..."). Only the saved label (cause_school) is used, never
// the user's words, and each worry is checked in on once.
//
// POST { "text": "...", "mode": "vent" | "comfort" | "guide" } picks how Chipu
// answers (logic.ts); guide, practical help, is the default. When there is no
// worry to check in on, "opening" may instead ask gently whether feeling numb,
// lonely or disconnected on several days has been getting harder.
//
// A message that hints at distress without the crisis phrases ("what's the
// point") makes Chipu ask directly about safety (distress.ts); "yes" or "not
// sure" shows the helplines.
//
// Replies that ask something come with tappable answers ("options"). A tapped
// answer is read without the model (chipParse), so it always means what it says.
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
import { isIndirectDistress, safetyAnswer } from "./distress.ts";
import {
  chipParse,
  decide,
  distinctDays,
  followUp,
  nickname,
  optionsFor,
  parseMode,
  PATTERN_DAYS,
  PATTERN_WINDOW_DAYS,
  patternAsk,
  pick,
  type RasaParse,
  THRESHOLD,
} from "./logic.ts";
import { type Lang, REPLIES } from "./replies.ts";

const MAX_LENGTH = 1000;
/** How many days back (not counting today) Chipu checks in on a worry. */
const FOLLOW_UP_DAYS = 3;
const NAIROBI_OFFSET_MS = 3 * 60 * 60 * 1000;

/** Midnight in Nairobi, `daysBack` days before today, as a UTC timestamp. */
function nairobiMidnight(daysBack: number): string {
  const local = new Date(Date.now() + NAIROBI_OFFSET_MS);
  const midnight = Date.UTC(local.getUTCFullYear(), local.getUTCMonth(), local.getUTCDate() - daysBack);
  return new Date(midnight - NAIROBI_OFFSET_MS).toISOString();
}
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
  let body: { text?: unknown; session_id?: unknown; action?: unknown; mode?: unknown };
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid JSON" }, 400);
  }
  if (body.action === "opening") return await opening(userId);
  const text = typeof body.text === "string" ? body.text.trim() : "";
  if (!text) return json({ error: "text is required" }, 400);
  if (text.length > MAX_LENGTH) return json({ error: `text is longer than ${MAX_LENGTH} characters` }, 400);

  const { data: profile } = await db.from("profiles").select("language, username").eq("id", userId).single();
  const lang: Lang = profile?.language === "sw" ? "sw" : "en";

  // Use the given session if it is theirs and still open, otherwise start one.
  // The mode (vent, comfort or guide) is kept on the session.
  const mode = parseMode(body.mode);
  let sessionId: string | null = null;
  if (typeof body.session_id === "string") {
    const { data: s } = await db.from("chat_sessions").select("id, mode")
      .eq("id", body.session_id).eq("user_id", userId).is("ended_at", null).maybeSingle();
    sessionId = s?.id ?? null;
    if (s && s.mode !== mode) await db.from("chat_sessions").update({ mode }).eq("id", s.id);
  }
  if (!sessionId) {
    const { data: s, error } = await db.from("chat_sessions").insert({ user_id: userId, mode }).select("id")
      .single();
    if (error) return json({ error: "could not start a session" }, 500);
    sessionId = s.id;
  }

  // What Chipu said last, so a short answer can be read in context.
  const { data: last } = await db.from("messages").select("reply_key")
    .eq("session_id", sessionId).eq("sender", "bot")
    .order("created_at", { ascending: false }).limit(1).maybeSingle();
  const previousKey: string | null = last?.reply_key ?? null;
  const nick = nickname(profile?.username);

  // 1. Crisis check, before the model.
  if (isCrisis(text)) return await crisisResponse(userId, sessionId!, text, lang, elapsed);

  // 1b. Indirect distress ("what's the point"): Chipu asks directly about
  // safety. "Yes" or "not sure" gets the helplines; "no" gets support.
  if (previousKey === "ask_safety") {
    const answer = safetyAnswer(text);
    if (answer === "yes" || answer === "unsure" || (answer === null && isIndirectDistress(text))) {
      return await crisisResponse(userId, sessionId!, text, lang, elapsed);
    }
    if (answer === "no") {
      return await quickReply(sessionId!, text, "safety_no", "safety_ok", lang, nick, elapsed);
    }
  } else if (isIndirectDistress(text)) {
    return await quickReply(sessionId!, text, "distress_indirect", "ask_safety", lang, nick, elapsed);
  }

  // 2. Ask Rasa and pick the reply, using the bot's last message for context.
  const nluStarted = performance.now();
  // A tapped answer needs no model.
  const tapped = chipParse(text, previousKey);
  const fromRasa = tapped ? null : await askRasa(text);
  const nluSource = tapped ? "tap" : fromRasa ? "rasa" : "backup";
  const parse = tapped ?? fromRasa ?? backupParse(text);
  const nluMs = Math.round(performance.now() - nluStarted);
  const decision = decide(
    parse,
    previousKey,
    lang,
    Math.random,
    text,
    tapped ? 0 : fromRasa ? THRESHOLD : BACKUP_THRESHOLD,
    nick,
    mode,
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
    options: optionsFor(decision.replyKey, lang),
  });
});

/** The crisis reply: logs a crisis event (no text), returns the verified helplines. */
async function crisisResponse(
  userId: string,
  sessionId: string,
  text: string,
  lang: Lang,
  elapsed: () => number,
): Promise<Response> {
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

/** A fixed reply that needs no model (the safety question and its "no"). */
async function quickReply(
  sessionId: string,
  text: string,
  intent: string,
  replyKey: string,
  lang: Lang,
  nick: string | null,
  elapsed: () => number,
): Promise<Response> {
  const reply = pick(replyKey, lang, Math.random, undefined, nick);
  await db.from("messages").insert({ session_id: sessionId, sender: "user", content: text, intent });
  await db.from("messages").insert({
    session_id: sessionId,
    sender: "bot",
    content: reply,
    reply_key: replyKey,
    response_ms: elapsed(),
  });
  return json({
    session_id: sessionId,
    reply,
    crisis: false,
    intent,
    confidence: null,
    options: optionsFor(replyKey, lang),
  });
}

/**
 * Chipu's check-in on the latest worry from the last few days, in a new
 * session. Returns no reply when there is nothing to check in on: the
 * latest worry is from today, is older, is "other"/"unsure", or was already
 * checked in on.
 */
async function opening(userId: string): Promise<Response> {
  const none = json({ session_id: null, reply: null, crisis: false, options: [] });
  const { data: profile } = await db.from("profiles").select("language, username").eq("id", userId).single();
  const lang: Lang = profile?.language === "sw" ? "sw" : "en";
  const nick = nickname(profile?.username);

  const check = (await worryCheckIn(userId, lang, nick)) ?? (await patternCheckIn(userId, lang, nick));
  if (!check) return none;

  const { data: s, error } = await db.from("chat_sessions").insert({ user_id: userId }).select("id").single();
  if (error) return none;
  await db.from("messages").insert({
    session_id: s.id,
    sender: "bot",
    content: check.text,
    reply_key: check.replyKey,
  });
  return json({ session_id: s.id, reply: check.text, crisis: false, options: check.options });
}

type CheckIn = { replyKey: string; text: string; options: string[] };

/** The check-in on the latest worry from the last few days, or null. */
async function worryCheckIn(userId: string, lang: Lang, nick: string | null): Promise<CheckIn | null> {
  const { data: latest } = await db.from("messages")
    .select("intent, created_at, chat_sessions!inner(user_id)")
    .eq("chat_sessions.user_id", userId).eq("sender", "user").like("intent", "cause_%")
    .gte("created_at", nairobiMidnight(FOLLOW_UP_DAYS))
    .order("created_at", { ascending: false }).limit(1).maybeSingle();
  if (!latest || new Date(latest.created_at) >= new Date(nairobiMidnight(0))) return null;

  const { count } = await db.from("messages")
    .select("id, chat_sessions!inner(user_id)", { count: "exact", head: true })
    .eq("chat_sessions.user_id", userId).eq("sender", "bot").like("reply_key", "follow_up:%")
    .gt("created_at", latest.created_at);
  if ((count ?? 0) > 0) return null;
  return followUp(latest.intent, lang, Math.random, nick);
}

/**
 * A gentle question when numbness, loneliness or feeling disconnected has come
 * up on several different days in the last two weeks (from the saved intent
 * labels and the "disconnected" check-in tag, never the user's words). Asked at
 * most once every two weeks.
 */
async function patternCheckIn(userId: string, lang: Lang, nick: string | null): Promise<CheckIn | null> {
  const since = nairobiMidnight(PATTERN_WINDOW_DAYS);
  const { count: asked } = await db.from("messages")
    .select("id, chat_sessions!inner(user_id)", { count: "exact", head: true })
    .eq("chat_sessions.user_id", userId).eq("sender", "bot").eq("reply_key", "pattern")
    .gte("created_at", since);
  if ((asked ?? 0) > 0) return null;

  const { data: said } = await db.from("messages")
    .select("created_at, chat_sessions!inner(user_id)")
    .eq("chat_sessions.user_id", userId).eq("sender", "user")
    .in("intent", ["feel_numb", "feel_lonely"]).gte("created_at", since);
  const { data: tagged } = await db.from("mood_logs").select("created_at")
    .eq("user_id", userId).contains("tags", ["disconnected"]).gte("created_at", since);
  const days = distinctDays([...(said ?? []), ...(tagged ?? [])].map((r) => r.created_at as string));
  if (days < PATTERN_DAYS) return null;
  return patternAsk(lang, Math.random, nick);
}
