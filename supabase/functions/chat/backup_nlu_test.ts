import { deepStrictEqual as assertEquals, ok as assert } from "node:assert";
import { BACKUP_THRESHOLD, backupParse, clean, findName, fnv1a } from "./backup_nlu.ts";
import { decide } from "./logic.ts";
import expected from "./backup_expected.json" with { type: "json" };

Deno.test("hash is the same as in train_backup.py", () => {
  // FNV-1a test values.
  assertEquals(fnv1a(""), 0x811c9dc5);
  assertEquals(fnv1a("a"), 0xe40c292c);
  assertEquals(fnv1a("foobar"), 0xbf9cf968);
});

Deno.test("text clean-up", () => {
  assertEquals(clean("  I'm SO stressed!!  "), "im so stressed");
  assertEquals(clean("Nina stress ya mitihani 😩"), "nina stress ya mitihani");
});

Deno.test("same answers as the Python model on all 60 test phrases", () => {
  for (const e of expected as { text: string; intent: string; confidence: number }[]) {
    const p = backupParse(e.text);
    assertEquals(p.intent.name, e.intent, e.text);
    assert(Math.abs(p.intent.confidence - e.confidence) < 0.02, `${e.text}: ${p.intent.confidence}`);
  }
});

Deno.test("reads common messages in both languages", () => {
  assertEquals(backupParse("hello").intent.name, "greet");
  assertEquals(backupParse("nina stress sana kuhusu mitihani").intent.name, "feel_stressed");
  assertEquals(backupParse("asante sana").intent.name, "thank");
});

Deno.test("finds the name in an introduction", () => {
  assertEquals(findName("my name is Amani"), "Amani");
  assertEquals(findName("naitwa Furaha"), "Furaha");
  assertEquals(findName("Hope here"), "Hope");
  assertEquals(findName("I feel tired"), null);
  const p = backupParse("my name is Wanjiru");
  assertEquals(p.intent.name, "tell_name");
  assertEquals(p.entities, [{ entity: "name", value: "Wanjiru" }]);
});

Deno.test("Chipu answers with the backup model", () => {
  const d = decide(
    backupParse("niko na wasiwasi mwingi"),
    null,
    "sw",
    () => 0,
    "niko na wasiwasi mwingi",
    BACKUP_THRESHOLD,
  );
  assertEquals(d.intent, "feel_anxious");
  assert(d.replyKey !== "unavailable");
  // Nonsense gets the "didn't understand" reply, not a guess.
  const n = decide(backupParse("qwerty zxcv"), null, "en", () => 0, "qwerty zxcv", BACKUP_THRESHOLD);
  assertEquals(n.intent, "fallback");
});
