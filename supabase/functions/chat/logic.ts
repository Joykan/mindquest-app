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
 * Feelings Chipu asks about first ("What's been weighing on you?") before
 * offering help: the question's reply key (the next message is read as the
 * answer) and the help offered afterwards.
 */
const FEELINGS: Record<string, { ask: string; offer: string }> = {
  feel_stressed: { ask: "ask_cause_stress", offer: "offer_breathing" },
  feel_anxious: { ask: "ask_cause_anxious", offer: "offer_breathing" },
  feel_sad: { ask: "ask_cause_sad", offer: "offer_ideas" },
  feel_numb: { ask: "ask_cause_numb", offer: "offer_ideas" },
  feel_lonely: { ask: "ask_cause_lonely", offer: "offer_ideas" },
  feel_tired: { ask: "ask_cause_tired", offer: "offer_rest" },
};

/**
 * A cause that only repeats the feeling ("I'm so tired" is not a cause of
 * feeling tired), so Chipu still asks. Loneliness is always asked about.
 */
const feelingWord: Record<string, string> = {
  feel_tired: "exhausted",
  feel_numb: "empty",
};

/** The feeling a question was about (ask_cause_stress → feel_stressed). */
const ASKED: Record<string, string> = Object.fromEntries(
  Object.entries(FEELINGS).map(([feeling, f]) => [f.ask, feeling]),
);

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
    /\b(exams?|tests?|cats?|school|schools|class(es)?|assignments?|homework|revision|grades?|results|marks|campus|university|uni|college|lectures?|units?|kcse|supp|mtihani|mitihani|shule|darasa|masomo|kusoma|matokeo|chuo|shuleni|darasani)\b/,
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
    /\b(friends?|boyfriend|girlfriend|bf|gf|partner|relationships?|break ?up|broke up|crush|lonely|alone|left out|rafiki|marafiki|mpenzi|uhusiano|dem|msupa|boychild|upweke|peke yangu|nimetengwa|kutengwa)\b/,
  ],
  [
    "health",
    /\b(sick|ill|illness|health|pain|sleep|sleeping|insomnia|hospital|doctor|mgonjwa|ugonjwa|afya|maumivu|usingizi|hospitali|daktari)\b/,
  ],
  [
    "exhausted",
    /\b(exhausted|tired|drained|burnt out|burned out|worn out|no energy|nimechoka|uchovu|sina nguvu|sina energy)\b/,
  ],
  [
    "overwhelmed",
    /\b(overwhelmed|too much|so much going on|everything at once|nimelemewa|mengi sana|kila kitu kwa wakati mmoja)\b/,
  ],
  [
    "empty",
    /\b(empty|nothing matters|hollow|numb|mtupu|tupu|sina hisia)\b/,
  ],
];

/**
 * Tappable answers shown under some of Chipu's questions, in the user's
 * language. Tapping one sends its text, which is read without the NLU model
 * (chipParse), so a tap always means what it says.
 */
const OPTIONS: Record<string, Record<Lang, string[]>> = {
  causes: {
    en: ["School", "Money", "Family", "Friends", "Something else", "I don't know"],
    sw: ["Masomo", "Pesa", "Familia", "Marafiki", "Jambo lingine", "Sijui"],
  },
  ask_cause_numb: {
    en: ["Exhausted", "Overwhelmed", "Empty", "Something happened", "I don't know"],
    sw: ["Nimechoka", "Nimelemewa", "Najihisi mtupu", "Kuna jambo lilitokea", "Sijui"],
  },
  ask_cause_lonely: {
    en: ["I miss my family", "I feel left out", "At school", "Something else"],
    sw: ["Nawakumbuka familia yangu", "Nahisi nimetengwa", "Shuleni", "Jambo lingine"],
  },
  ask_cause_tired: {
    en: ["Not sleeping well", "Too much going on", "Both"],
    sw: ["Sipati usingizi", "Mambo mengi sana", "Vyote viwili"],
  },
  yes_no: { en: ["Yes, please", "No, thanks"], sw: ["Ndiyo, tafadhali", "Hapana, asante"] },
  confirm: { en: ["Yes", "No"], sw: ["Ndiyo", "Hapana"] },
  follow_up: {
    en: ["Better 🙂", "About the same", "Worse"],
    sw: ["Vizuri zaidi 🙂", "Bado vile vile", "Mbaya zaidi"],
  },
};

const YES_NO_AFTER = new Set([
  "offer_breathing",
  "offer_ideas",
  "offer_rest",
  "feel_stressed",
  "feel_anxious",
]);

/** The tappable answers for a reply (empty when there are none). */
export function optionsFor(replyKey: string | null, lang: Lang): string[] {
  if (!replyKey) return [];
  if (replyKey === "ask_cause_stress" || replyKey === "ask_cause_anxious" || replyKey === "ask_cause_sad") {
    return OPTIONS.causes[lang];
  }
  if (replyKey in OPTIONS) return OPTIONS[replyKey][lang];
  if (YES_NO_AFTER.has(replyKey)) return OPTIONS.yes_no[lang];
  if (replyKey.startsWith("confirm_name:")) return OPTIONS.confirm[lang];
  if (replyKey.startsWith("follow_up:")) return OPTIONS.follow_up[lang];
  return [];
}

/**
 * A tapped answer, read without the model: yes/no as affirm/deny, the
 * check-in answers as follow_better/same/worse, and a "what's behind it"
 * answer as no particular intent (the words say what it is about). Null if
 * the text isn't one of the answers shown.
 */
export function chipParse(text: string, previousReplyKey: string | null): RasaParse | null {
  const t = words(text);
  for (const lang of ["en", "sw"] as Lang[]) {
    const options = optionsFor(previousReplyKey, lang);
    const i = options.findIndex((o) => words(o) === t);
    if (i < 0) continue;
    let name = "nlu_fallback";
    if (options === OPTIONS.yes_no[lang] || options === OPTIONS.confirm[lang]) {
      name = i === 0 ? "affirm" : "deny";
    } else if (options === OPTIONS.follow_up[lang]) {
      name = ["follow_better", "follow_same", "follow_worse"][i];
    }
    return { intent: { name, confidence: 1 }, entities: [] };
  }
  return null;
}

/** "I don't know", "nothing", "sijui", "sitaki kuongea". */
const UNSURE =
  /\b(i don t know|i dont know|dont know|don t know|idk|not sure|no idea|nothing|nothing really|rather not|sijui|sielewi|hakuna kitu|sitaki)\b/;

function words(text: string): string {
  return text.toLowerCase().replace(/['’`]/g, " ").replace(/[^\p{L}\p{N}]+/gu, " ").trim();
}

/** school, money, family, friends, health, exhausted, overwhelmed, empty, or other. */
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

/**
 * One of the reply's variants. {name} is a name just given; "{ nick}" and
 * "{, nick}" put the user's nickname in ("Hey Candy!", "I'm sorry, Candy.")
 * or leave nothing when there is none.
 */
export function pick(
  key: string,
  lang: Lang,
  rng: () => number,
  name?: string,
  nick?: string | null,
): string {
  const options = REPLIES[key]?.[lang] ?? REPLIES.fallback[lang];
  let text = options[Math.floor(rng() * options.length)];
  if (name) text = text.replaceAll("{name}", name);
  return text.replaceAll("{ nick}", nick ? ` ${nick}` : "").replaceAll("{, nick}", nick ? `, ${nick}` : "");
}

/** The nickname to use in replies, or null ("Friend" is the default for no name). */
export function nickname(username: string | null | undefined): string | null {
  const n = (username ?? "").trim();
  if (!n || n.toLowerCase() === "friend" || n.length > 30) return null;
  return n;
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
  nick: string | null = null,
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
    text: pick(textKey, lang, rng, name, nick),
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
  // Answers to a check-in on a recent worry.
  if (previousReplyKey?.startsWith("follow_up:")) {
    const how = r.intent === "feel_good" ? "follow_better" : r.intent;
    if (how === "follow_better") return { ...out("follow_better"), intent: how };
    if (how === "follow_same" || how === "follow_worse") {
      return {
        intent: how,
        confidence: r.confidence,
        replyKey: "offer_breathing",
        text: `${pick(how, lang, rng, undefined, nick)} ${
          pick("offer_breathing", lang, rng, undefined, nick)
        }`,
      };
    }
  }
  if (previousReplyKey === "offer_rest") {
    if (r.intent === "affirm") return out("rest_tips");
    if (r.intent === "deny") return out("deny");
  }

  // An understanding reply about what's behind the feeling (school, money,
  // ...) and an offer of help. The answer to Chipu's question is recorded as
  // cause_<what> (labels only, for the dashboard).
  // Some feelings have their own wording (cause_family_lonely).
  const cause = (feeling: string, kind: string, intent: string): Decision => {
    const offer = FEELINGS[feeling].offer;
    const own = `cause_${kind}_${feeling.slice("feel_".length)}`;
    const key = own in REPLIES ? own : `cause_${kind}`;
    return {
      intent,
      confidence: r.confidence,
      replyKey: offer,
      text: `${pick(key, lang, rng, undefined, nick)} ${pick(offer, lang, rng, undefined, nick)}`,
    };
  };
  if (previousReplyKey && previousReplyKey in ASKED && !CHANGES_SUBJECT.has(r.intent)) {
    const feeling = ASKED[previousReplyKey];
    const kind = findCause(text);
    if (kind === "other" && (r.intent === "deny" || UNSURE.test(words(text)))) {
      return cause(feeling, "unsure", "cause_unsure");
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
    case "feel_sad":
    case "feel_numb":
    case "feel_lonely":
    case "feel_tired": {
      const f = FEELINGS[r.intent];
      // "I'm stressed about exams": the cause is already there.
      const kind = findCause(text);
      if (kind !== "other" && kind !== feelingWord[r.intent] && r.intent !== "feel_lonely") {
        return cause(r.intent, kind, r.intent);
      }
      // Already talking about it: offer help instead of asking again.
      const inThread = previousReplyKey !== null &&
        (previousReplyKey in ASKED || previousReplyKey.startsWith("offer_") ||
          previousReplyKey in FEELINGS);
      if (!inThread) return out(f.ask);
      if (f.offer === "offer_breathing") return out(r.intent);
      return {
        intent: r.intent,
        confidence: r.confidence,
        replyKey: f.offer,
        text: `${pick("with_you", lang, rng, undefined, nick)} ${pick(f.offer, lang, rng, undefined, nick)}`,
      };
    }
    default:
      return out(r.intent in REPLIES ? r.intent : "fallback");
  }
}

/** Worries Chipu can check in on later (not "other" or "unsure"). */
export const FOLLOW_UP_CAUSES = [
  "school",
  "money",
  "family",
  "friends",
  "health",
  "exhausted",
  "overwhelmed",
  "empty",
];

/**
 * The check-in that opens a new chat, from the label of the latest worry
 * the user told Chipu about (cause_school, ...), or null for none.
 */
export function followUp(
  causeIntent: string | null,
  lang: Lang,
  rng: () => number = Math.random,
  nick: string | null = null,
): { replyKey: string; text: string; options: string[] } | null {
  const kind = causeIntent?.startsWith("cause_") ? causeIntent.slice("cause_".length) : null;
  if (!kind || !FOLLOW_UP_CAUSES.includes(kind)) return null;
  const replyKey = `follow_up:${kind}`;
  return {
    replyKey,
    text: pick(`follow_up_${kind}`, lang, rng, undefined, nick),
    options: optionsFor(replyKey, lang),
  };
}
