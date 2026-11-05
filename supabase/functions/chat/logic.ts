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
const OFFERS_BREATHING = new Set(["feel_stressed", "feel_anxious", "offer_breathing"]);

/**
 * Feelings Chipu asks about first ("What's been stressing you out?") before
 * offering help. The reply key says which feeling, so the next message is
 * read as the answer.
 */
const ASK_CAUSE: Record<string, string> = {
  feel_stressed: "ask_cause_stress",
  feel_anxious: "ask_cause_anxious",
  feel_sad: "ask_cause_sad",
};

/** Intents that change the subject instead of answering "what's behind it". */
const CHANGES_SUBJECT = new Set([
  "greet",
  "goodbye",
  "thank",
  "ask_about_bot",
  "ask_breathing",
  "ask_ideas",
  "tell_name",
]);

/** What a worry is about, from words in English, Kiswahili and Sheng. First match wins. */
const CAUSES: [string, RegExp][] = [
  [
    "school",
    /\b(exams?|tests?|cats?|school|class(es)?|assignments?|homework|revision|grades?|results|marks|campus|university|uni|college|lectures?|units?|kcse|supp|mtihani|mitihani|shule|darasa|masomo|kusoma|matokeo|chuo)\b/,
  ],
  [
    "money",
    /\b(money|cash|fees?|rent|broke|bills?|jobs?|loans?|debts?|pesa|doo|mula|ganji|munde|karo|kodi|deni|ajira|kibarua)\b/,
  ],
  [
    "family",
    /\b(family|parents?|mum|mom|mother|dad|father|home|siblings?|brother|sister|familia|wazazi|mzazi|mama|baba|nyumbani|ndugu|kaka|dada|boma)\b/,
  ],
  [
    "friends",
    /\b(friends?|boyfriend|girlfriend|bf|gf|partner|relationships?|break ?up|broke up|crush|lonely|alone|rafiki|marafiki|mpenzi|uhusiano|dem|msupa|boychild|upweke|peke yangu)\b/,
  ],
  [
    "health",
    /\b(sick|ill|illness|health|pain|sleep|insomnia|hospital|doctor|mgonjwa|ugonjwa|afya|maumivu|usingizi|hospitali|daktari)\b/,
  ],
];

/** "I don't know", "nothing", "sijui", "sitaki kuongea". */
const UNSURE =
  /\b(i don t know|i dont know|dont know|don t know|idk|not sure|no idea|nothing|nothing really|rather not|sijui|sielewi|hakuna kitu|sitaki)\b/;

function words(text: string): string {
  return text.toLowerCase().replace(/['’`]/g, " ").replace(/[^\p{L}\p{N}]+/gu, " ").trim();
}

/** school, money, family, friends, health, or other. */
export function findCause(text: string): string {
  const t = words(text);
  for (const [cause, re] of CAUSES) {
    if (re.test(t)) return cause;
  }
  return "other";
}

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
  if (previousReplyKey === "offer_ideas") {
    if (r.intent === "affirm") return out("ask_ideas");
    if (r.intent === "deny") return out("deny");
  }

  // The answer to "What's been stressing you out?": an understanding reply
  // about that (school, money, ...) and an offer of help. The message is
  // recorded as cause_<what> (labels only, for the dashboard).
  const cause = (feeling: string, kind: string, intent: string): Decision => {
    const offer = feeling === "sad" ? "offer_ideas" : "offer_breathing";
    return {
      intent,
      confidence: r.confidence,
      replyKey: offer,
      text: `${pick(`cause_${kind}`, lang, rng)} ${pick(offer, lang, rng)}`,
    };
  };
  if (previousReplyKey?.startsWith("ask_cause_") && !CHANGES_SUBJECT.has(r.intent)) {
    const feeling = previousReplyKey.slice("ask_cause_".length);
    const kind = findCause(text);
    if (kind === "other" && (r.intent === "deny" || UNSURE.test(words(text)))) {
      return cause(feeling, "unsure", r.intent);
    }
    return cause(feeling, kind, `cause_${kind}`);
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
    case "feel_stressed":
    case "feel_anxious":
    case "feel_sad": {
      const feeling = ASK_CAUSE[r.intent].slice("ask_cause_".length);
      // "I'm stressed about exams": the cause is already there.
      const kind = findCause(text);
      if (kind !== "other") return cause(feeling, kind, r.intent);
      // Already talking about it: offer help instead of asking again.
      const inThread = previousReplyKey !== null &&
        (previousReplyKey.startsWith("ask_cause_") || previousReplyKey.startsWith("offer_") ||
          previousReplyKey in ASK_CAUSE);
      if (!inThread) return out(ASK_CAUSE[r.intent]);
      if (r.intent === "feel_sad") {
        return {
          intent: r.intent,
          confidence: r.confidence,
          replyKey: "offer_ideas",
          text: `${pick("feel_sad_again", lang, rng)} ${pick("offer_ideas", lang, rng)}`,
        };
      }
      return out(r.intent);
    }
    default:
      return out(r.intent in REPLIES ? r.intent : "fallback");
  }
}
