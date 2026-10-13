import { deepStrictEqual as assertEquals, ok as assert } from "node:assert";
import { isCrisis, normalize } from "./crisis.ts";
import { cleanName, decide, introducesName, type RasaParse, resolve, soundsHappy } from "./logic.ts";

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
  assertEquals(decide(parse("feel_stressed", 0.9), null, "en", first).replyKey, "feel_stressed");
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
