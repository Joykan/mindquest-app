// Picks the bot's reply from the Rasa result. Kept free of network and
// database code so it can be unit tested (logic_test.ts).

import { type Lang, REPLIES } from "./replies.ts";

/** Same cut-off as the FallbackClassifier in nlp/rasa/config.yml. */
export const THRESHOLD = 0.5;

/** Names that are also feeling words. Checked first only if the message doesn't introduce a name. */
export const EMOTION_NAMES = new Set([
  "joy",
  "hope",
  "grace",
  "faith",
  "peace",
  "mercy",
  "love",
  "happy",
  "blessing",
  "precious",
  "patience",
  "charity",
  "furaha",
  "amani",
  "neema",
  "imani",
  "baraka",
  "faraja",
  "tumaini",
  "zawadi",
  "rehema",
  "wema",
  "upendo",
]);

/**
 * Words that show the user is introducing themselves ("my name is", "naitwa",
 * "call me", "I'm"...). With one of these, a name is used straight away.
 */
const NAME_CUES =
  /\b(name|names|named|called|call me|go by|i m|im|i am|this is|here|naitwa|jina|niite|kuniita|wananiita|mimi ni|ni mimi|hapa)\b/;

/** True if the message reads like an introduction rather than a feeling. */
export function introducesName(text: string): boolean {
  const t = text.toLowerCase().replace(/['’`]/g, " ").replace(/[^\p{L}\p{N}]+/gu, " ");
  return NAME_CUES.test(t);
}

/** Happy feeling words, in both languages. */
const HAPPY_WORDS = /\b(joy|joyful|happy|glad|peace|peaceful|furaha|nimefurahi|amani)\b/;

/**
 * Rule 3: Rasa said "name" but found no name, and the message has a happy
 * feeling word ("I feel joy today"). Read it as feeling good.
 */
export function soundsHappy(text: string): boolean {
  const t = text.toLowerCase().replace(/['’`]/g, " ").replace(/[^\p{L}\p{N}]+/gu, " ");
  return HAPPY_WORDS.test(t);
}

/** Replies after which a yes/no answer means something specific. */
const OFFERS_BREATHING = new Set(["feel_stressed", "feel_anxious"]);

export interface RasaParse {
  intent: { name: string; confidence: number };
  entities?: { entity: string; value: string }[];
  intent_ranking?: { name: string; confidence: number }[];
}

export interface Resolved {
  intent: string; // an intent name, or "fallback"
  confidence: number;
  name?: string;
}

export interface Decision {
  intent: string | null; // what the user's message was read as (null if Rasa was unreachable)
  confidence: number | null;
  replyKey: string; // stored with the bot message; used to read the next yes/no
  text: string;
}

/** Tidy a name from the model: letters only, first letter capital, at most 30 characters. */
export function cleanName(raw: string): string | null {
  const v = raw.trim();
  if (!/^[\p{L}][\p{L}'-]{0,29}$/u.test(v)) return null;
  return v[0].toUpperCase() + v.slice(1).toLowerCase();
}

/**
 * Applies the threshold and the name rule to the raw Rasa result. The backup
 * model (backup_nlu.ts) uses its own, lower threshold.
 */
export function resolve(parse: RasaParse, threshold = THRESHOLD): Resolved {
  const top = parse.intent;
  if (top.name === "nlu_fallback" || top.confidence < threshold) {
    return { intent: "fallback", confidence: top.confidence };
  }
  if (top.name === "tell_name") {
    const raw = parse.entities?.find((e) => e.entity === "name")?.value;
    const name = raw ? cleanName(raw) : null;
    if (name) return { intent: "tell_name", confidence: top.confidence, name };
    // Rule 1: no name extracted, so it wasn't really a name. Use the next intent.
    const next = (parse.intent_ranking ?? []).find(
      (r) => r.name !== "tell_name" && r.name !== "nlu_fallback",
    );
    if (next && next.confidence >= threshold) {
      return { intent: next.name, confidence: next.confidence };
    }
    return { intent: "fallback", confidence: top.confidence };
  }
  return { intent: top.name, confidence: top.confidence };
}

function pick(key: string, lang: Lang, rng: () => number, name?: string): string {
  const options = REPLIES[key]?.[lang] ?? REPLIES.fallback[lang];
  const text = options[Math.floor(rng() * options.length)];
  return name ? text.replaceAll("{name}", name) : text;
}

/**
 * Decides the reply. `previousReplyKey` is the reply key of the bot's last
 * message in this session, so "yes" and "no" can be read in context.
 * `parse` is null when no model could read the message. `threshold` is the
 * confidence cut-off of the model that read it.
 */
export function decide(
  parse: RasaParse | null,
  previousReplyKey: string | null,
  lang: Lang,
  rng: () => number = Math.random,
  text = "",
  threshold = THRESHOLD,
): Decision {
  if (!parse) {
    return { intent: null, confidence: null, replyKey: "unavailable", text: pick("unavailable", lang, rng) };
  }
  let r = resolve(parse, threshold);
  if (r.intent === "fallback" && parse.intent.name === "tell_name" && soundsHappy(text)) {
    r = { intent: "feel_good", confidence: parse.intent.confidence };
  }
  const out = (replyKey: string, textKey = replyKey, name?: string): Decision => ({
    intent: r.intent,
    confidence: r.confidence,
    replyKey,
    text: pick(textKey, lang, rng, name),
  });

  // Answers to the bot's last question.
  if (previousReplyKey?.startsWith("confirm_name:")) {
    const name = previousReplyKey.slice("confirm_name:".length);
    if (r.intent === "affirm") return out("nice_to_meet", "nice_to_meet", name);
    if (r.intent === "deny") return out("name_declined");
  }
  if (previousReplyKey && OFFERS_BREATHING.has(previousReplyKey)) {
    if (r.intent === "affirm") return out("breathing");
    if (r.intent === "deny") return out("declined_breathing");
  }

  switch (r.intent) {
    case "tell_name":
      // Rule 2: "my name is Joy" is used straight away. Only a feeling-word
      // name in a message that doesn't introduce anyone ("I feel joy") is checked.
      if (EMOTION_NAMES.has(r.name!.toLowerCase()) && !introducesName(text)) {
        return out(`confirm_name:${r.name}`, "confirm_name", r.name);
      }
      return out("nice_to_meet", "nice_to_meet", r.name);
    case "ask_breathing":
      return out("breathing");
    default:
      return out(r.intent in REPLIES ? r.intent : "fallback");
  }
}
