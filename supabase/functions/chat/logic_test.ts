import { deepStrictEqual as assertEquals, ok as assert } from "node:assert";
import { isCrisis, normalize } from "./crisis.ts";
import {
  cleanName,
  decide,
  findCause,
  introducesName,
  nickname,
  type RasaParse,
  resolve,
  soundsHappy,
  THRESHOLD,
} from "./logic.ts";

const first = () => 0; // always pick the first reply variant

function parse(name: string, confidence: number, extra: Partial<RasaParse> = {}): RasaParse {
  return { intent: { name, confidence }, entities: [], intent_ranking: [{ name, confidence }], ...extra };
}

// --- crisis check -----------------------------------------------------------

Deno.test("crisis phrases are caught in English, Kiswahili and Sheng", () => {
  for (
    const t of [
      "I want to kill myself",
      "I don't want to live anymore",
      "sometimes I think about suicide",
      "nataka kujiua",
      "sitaki kuishi tena",
      "nimechoka kuishi",
      "nataka kujimaliza bana",
      "I want to END IT ALL!!!",
      "nimefika kikomo, siwezi tena",
      "ntajitia kitanzi leo",
      "maisha yamenichosha kabisa",
    ]
  ) assert(isCrisis(t), t);
});

Deno.test("ordinary messages are not crisis", () => {
  for (
    const t of [
      "I'm stressed about exams",
      "this assignment is killing me",
      "nina huzuni leo",
      "I'm dying to see my friends",
      "maisha ni magumu sana",
      "skill myself up", // must match whole words only
    ]
  ) assert(!isCrisis(t), t);
});

Deno.test("normalize drops apostrophes and punctuation", () => {
  assertEquals(normalize("Don't  want, to-live!"), " dont want to live ");
});

// --- names ------------------------------------------------------------------

Deno.test("cleanName tidies valid names and rejects odd values", () => {
  assertEquals(cleanName("joy"), "Joy");
  assertEquals(cleanName(" WANJIRU "), "Wanjiru");
  assertEquals(cleanName("joy today"), null);
  assertEquals(cleanName("123"), null);
});

Deno.test("rule 1: tell_name without an extracted name uses the next intent", () => {
  const p: RasaParse = {
    intent: { name: "tell_name", confidence: 0.7 },
    entities: [],
    intent_ranking: [{ name: "tell_name", confidence: 0.7 }, { name: "feel_good", confidence: 0.6 }],
  };
  assertEquals(resolve(p).intent, "feel_good");
});

Deno.test("rule 1: tell_name without a name and no strong second intent falls back", () => {
  const p: RasaParse = {
    intent: { name: "tell_name", confidence: 0.7 },
    entities: [],
    intent_ranking: [{ name: "tell_name", confidence: 0.7 }, { name: "feel_good", confidence: 0.2 }],
  };
  assertEquals(resolve(p).intent, "fallback");
});

Deno.test("rule 2: an introduced name is used straight away, even Joy", () => {
  const joy = parse("tell_name", 0.95, { entities: [{ entity: "name", value: "joy" }] });
  for (
    const t of ["my name is Joy", "I'm Joy", "naitwa Joy", "jina langu ni Joy", "call me joy", "Joy here"]
  ) {
    const d = decide(joy, null, "en", first, t);
    assertEquals(d.text, "Nice to meet you, Joy! How are you feeling today?", t);
  }
});

Deno.test("rule 2: a feeling word read as a name without an introduction is checked first", () => {
  const joy = parse("tell_name", 0.8, { entities: [{ entity: "name", value: "joy" }] });
  const d = decide(joy, null, "en", first, "I feel joy");
  assertEquals(d.replyKey, "confirm_name:Joy");
  assertEquals(d.text, "Just to check: is Joy your name?");
});

Deno.test("introducesName spots introductions in both languages", () => {
  for (const t of ["My name's Faith", "im hope", "mimi ni Grace", "niite Imani", "ni Faraja hapa"]) {
    assert(introducesName(t), t);
  }
  for (const t of ["I feel joy", "so much joy today", "nimejaa furaha", "nina amani"]) {
    assert(!introducesName(t), t);
  }
});

Deno.test("yes after a name check greets by name; no asks again", () => {
  const yes = decide(parse("affirm", 0.9), "confirm_name:Joy", "en", first);
  assertEquals(yes.text, "Nice to meet you, Joy! How are you feeling today?");
  const no = decide(parse("deny", 0.9), "confirm_name:Joy", "sw", first);
  assertEquals(no.replyKey, "name_declined");
});

Deno.test("an ordinary name is used straight away", () => {
  const d = decide(
    parse("tell_name", 0.9, { entities: [{ entity: "name", value: "Wanjiru" }] }),
    null,
    "sw",
    first,
  );
  assertEquals(d.text, "Nafurahi kukufahamu, Wanjiru! Unajisikiaje leo?");
});

// --- conversation flow ------------------------------------------------------

Deno.test("stress offers breathing; yes gives the exercise, no gives alternatives", () => {
  // Already talking about it (after a cause was asked): the breathing offer.
  assertEquals(decide(parse("feel_stressed", 0.9), "offer_breathing", "en", first).replyKey, "feel_stressed");
  assertEquals(decide(parse("affirm", 0.9), "feel_stressed", "en", first).replyKey, "breathing");
  assertEquals(decide(parse("deny", 0.9), "feel_anxious", "en", first).replyKey, "declined_breathing");
});

Deno.test("yes with nothing to agree to gets a neutral reply", () => {
  assertEquals(decide(parse("affirm", 0.9), "greet", "en", first).replyKey, "affirm");
});

Deno.test("asking for breathing goes straight to the exercise", () => {
  assertEquals(decide(parse("ask_breathing", 0.8), null, "sw", first).replyKey, "breathing");
});

Deno.test("asking for ideas gives ideas of things to do in both languages", () => {
  const en = decide(parse("ask_ideas", 0.8), null, "en", first);
  assertEquals(en.replyKey, "ask_ideas");
  assert(en.text.includes("walk"));
  assert(decide(parse("ask_ideas", 0.8), null, "sw", first).text.includes("tembea"));
});

Deno.test("low confidence and nlu_fallback give the fallback reply", () => {
  assertEquals(decide(parse("feel_sad", 0.4), null, "en", first).replyKey, "fallback");
  assertEquals(decide(parse("nlu_fallback", 0.9), null, "en", first).replyKey, "fallback");
});

Deno.test("Rasa unreachable gives the 'try again' reply", () => {
  const d = decide(null, null, "en", first);
  assertEquals(d.replyKey, "unavailable");
  assertEquals(d.intent, null);
});

Deno.test("every intent the model knows has a reply in both languages", async () => {
  const { REPLIES } = await import("./replies.ts");
  const intents = [
    "greet",
    "goodbye",
    "thank",
    "affirm",
    "deny",
    "feel_stressed",
    "feel_anxious",
    "feel_sad",
    "feel_good",
    "ask_about_bot",
    "ask_ideas",
  ];
  for (
    const key of [
      ...intents,
      "breathing",
      "nice_to_meet",
      "confirm_name",
      "fallback",
      "unavailable",
      "crisis",
    ]
  ) {
    assert(REPLIES[key]?.en?.length && REPLIES[key]?.sw?.length, key);
  }
  // Every reply key the feeling flow can give.
  for (const key of Object.keys(REPLIES).filter((k) => /^(ask_cause_|cause_|offer_)/.test(k))) {
    assertEquals(REPLIES[key].en.length > 0 && REPLIES[key].sw.length > 0, true, key);
  }
  for (const f of ["stress", "anxious", "sad", "numb", "lonely", "tired"]) {
    assert(REPLIES[`ask_cause_${f}`], f);
  }
  for (
    const k of [
      "school",
      "money",
      "family",
      "friends",
      "health",
      "exhausted",
      "overwhelmed",
      "empty",
      "other",
      "unsure",
    ]
  ) {
    assert(REPLIES[`cause_${k}`], k);
  }
  for (const k of ["rest_tips", "with_you", "offer_breathing", "offer_ideas", "offer_rest"]) {
    assert(REPLIES[k], k);
  }
});

Deno.test("numb, lonely and tired: asked about, then the right help", () => {
  const numb = decide(
    parse("feel_numb", 0.9),
    null,
    "en",
    first,
    "I feel stressed and emotionless",
    THRESHOLD,
    "Candy",
  );
  assertEquals(numb.replyKey, "ask_cause_numb");
  assert(numb.text.startsWith("I'm sorry, Candy."));
  assert(numb.text.includes("exhausted, overwhelmed, empty"));
  const after = decide(parse("nlu_fallback", 0.3), "ask_cause_numb", "en", first, "just exhausted honestly");
  assertEquals(after.intent, "cause_exhausted");
  assertEquals(after.replyKey, "offer_ideas");
  assertEquals(decide(parse("affirm", 0.9), "offer_ideas", "en", first).replyKey, "ask_ideas");

  // Loneliness is always asked about, with its own wording afterwards.
  assertEquals(
    decide(parse("feel_lonely", 0.9), null, "sw", first, "niko peke yangu shuleni").replyKey,
    "ask_cause_lonely",
  );
  const lonely = decide(
    parse("feel_lonely", 0.8),
    "ask_cause_lonely",
    "en",
    first,
    "I feel left out by my friends",
  );
  assertEquals(lonely.intent, "cause_friends");
  assert(lonely.text.startsWith("Feeling left out really hurts."));

  // "I'm so tired" doesn't count as the cause of being tired.
  assertEquals(
    decide(parse("feel_tired", 0.9), null, "en", first, "I'm so tired").replyKey,
    "ask_cause_tired",
  );
  const rest = decide(parse("nlu_fallback", 0.2), "ask_cause_tired", "en", first, "I can't sleep at night");
  assertEquals(rest.intent, "cause_health");
  assertEquals(rest.replyKey, "offer_rest");
  assertEquals(decide(parse("affirm", 0.9), "offer_rest", "en", first).replyKey, "rest_tips");
  assertEquals(decide(parse("deny", 0.9), "offer_rest", "en", first).replyKey, "deny");
});

Deno.test("the nickname is used when there is one", () => {
  assertEquals(
    decide(parse("greet", 0.9), null, "en", first, "hey", THRESHOLD, "Candy").text,
    "Hey Candy! 😊 I'm here. How are you feeling today?",
  );
  assertEquals(
    decide(parse("greet", 0.9), null, "en", first, "hey").text,
    "Hey! 😊 I'm here. How are you feeling today?",
  );
  assertEquals(
    decide(parse("greet", 0.9), null, "sw", first, "mambo", THRESHOLD, "Amani").text,
    "Mambo Amani! 😊 Niko hapa. Unajisikiaje leo?",
  );
  assertEquals(nickname("Friend"), null);
  assertEquals(nickname("  Candy "), "Candy");
  assertEquals(nickname(""), null);
});

Deno.test("rule 3: a name with no name found, plus a happy word, is read as feeling good", () => {
  const p: RasaParse = {
    intent: { name: "tell_name", confidence: 0.85 },
    entities: [],
    intent_ranking: [{ name: "tell_name", confidence: 0.85 }, { name: "feel_good", confidence: 0.1 }],
  };
  assertEquals(decide(p, null, "en", first, "I feel joy today").replyKey, "feel_good");
  assertEquals(decide(p, null, "sw", first, "nina furaha leo").replyKey, "feel_good");
  // Without a happy word it still falls back.
  assertEquals(decide(p, null, "en", first, "whatever").replyKey, "fallback");
});

Deno.test("soundsHappy only matches whole happy words", () => {
  assert(soundsHappy("so much JOY today"));
  assert(soundsHappy("nimefurahi sana"));
  assert(!soundsHappy("joyce is here"));
  assert(!soundsHappy("I feel low"));
});

Deno.test("a feeling: Chipu first asks what's behind it", () => {
  const d = decide(parse("feel_stressed", 0.9), null, "en", first, "I'm stressed");
  assertEquals(d.replyKey, "ask_cause_stress");
  assert(d.text.includes("What's been weighing on you?"));
  assertEquals(
    decide(parse("feel_anxious", 0.9), "greet", "sw", first, "nina wasiwasi").replyKey,
    "ask_cause_anxious",
  );
  assertEquals(decide(parse("feel_sad", 0.9), null, "en", first, "I feel low").replyKey, "ask_cause_sad");
});

Deno.test("the answer gets an understanding reply about it and an offer", () => {
  const d = decide(parse("nlu_fallback", 0.3), "ask_cause_stress", "en", first, "my exams next week");
  assertEquals(d.intent, "cause_school");
  assertEquals(d.replyKey, "offer_breathing");
  assert(d.text.startsWith("Exams and schoolwork"));
  assert(d.text.includes("breathing exercise"));
  // Then "yes" gives the exercise.
  assertEquals(decide(parse("affirm", 0.9), "offer_breathing", "en", first).replyKey, "breathing");

  const sw = decide(parse("feel_sad", 0.8), "ask_cause_sad", "sw", first, "wazazi wangu wanagombana");
  assertEquals(sw.intent, "cause_family");
  assertEquals(sw.replyKey, "offer_ideas");
  assert(sw.text.startsWith("Mambo ya nyumbani"));
  assertEquals(decide(parse("affirm", 0.9), "offer_ideas", "en", first).replyKey, "ask_ideas");
  assertEquals(decide(parse("deny", 0.9), "offer_ideas", "en", first).replyKey, "deny");
});

Deno.test("causes in English, Kiswahili and Sheng", () => {
  assertEquals(findCause("fees haijalipwa"), "money");
  assertEquals(findCause("sina doo"), "money");
  assertEquals(findCause("my girlfriend left me"), "friends");
  assertEquals(findCause("siwezi kulala, usingizi hakuna"), "health");
  assertEquals(findCause("matokeo ya mtihani"), "school");
  assertEquals(findCause("everything"), "other");
});

Deno.test("a cause in the first message skips the question", () => {
  const d = decide(parse("feel_stressed", 0.9), null, "en", first, "I'm so stressed about money");
  assertEquals(d.intent, "feel_stressed");
  assertEquals(d.replyKey, "offer_breathing");
  assert(d.text.startsWith("Money worries"));
});

Deno.test("not knowing, or changing the subject, is fine", () => {
  const d = decide(parse("deny", 0.9), "ask_cause_anxious", "en", first, "I don't know");
  assertEquals(d.replyKey, "offer_breathing");
  assert(d.text.startsWith("That's okay"));
  assertEquals(
    decide(parse("ask_breathing", 0.9), "ask_cause_stress", "en", first, "help me breathe").replyKey,
    "breathing",
  );
  assertEquals(decide(parse("thank", 0.9), "ask_cause_stress", "en", first, "thanks").replyKey, "thank");
});
