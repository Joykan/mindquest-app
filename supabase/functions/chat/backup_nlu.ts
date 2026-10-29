// Backup NLU: reads the message when the Rasa server can't be reached, so
// Chipu still answers (proposal NFR 3 / NFR-SPEC-02, availability).
//
// A small linear model trained from the same examples as Rasa
// (nlp/rasa/data/nlu.yml) by nlp/backup/train_backup.py, which also writes
// backup_model.ts. The text clean-up, the features and the hash below must
// stay exactly the same as in that script.
//
// Rasa stays the main NLU engine. Test results of both are in nlp/README.md.

import { BACKUP_MODEL } from "./backup_model.ts";
import type { RasaParse } from "./logic.ts";

/** Cut-off for the backup model, chosen by cross-validation (nlp/README.md). */
export const BACKUP_THRESHOLD = 0.35;

/** Lower case, letters and digits only, single spaces. */
export function clean(text: string): string {
  return text.toLowerCase().normalize("NFC").replace(/['’`]/g, "")
    .replace(/[^\p{L}\p{N}]+/gu, " ").trim().replace(/\s+/g, " ");
}

/** Words, word pairs and 3- to 5-letter pieces of each word. */
export function features(text: string): string[] {
  const words = clean(text).split(" ").filter((w) => w.length > 0);
  const out: string[] = [];
  for (const w of words) {
    out.push("w:" + w);
    const chars = Array.from("<" + w + ">");
    for (const n of [3, 4, 5]) {
      for (let i = 0; i + n <= chars.length; i++) out.push("c:" + chars.slice(i, i + n).join(""));
    }
  }
  for (let i = 0; i + 1 < words.length; i++) out.push("b:" + words[i] + " " + words[i + 1]);
  return out;
}

const encoder = new TextEncoder();

/** 32-bit FNV-1a hash of the UTF-8 bytes (as in train_backup.py). */
export function fnv1a(s: string): number {
  let h = 0x811c9dc5;
  for (const byte of encoder.encode(s)) {
    h ^= byte;
    h = Math.imul(h, 0x01000193) >>> 0;
  }
  return h >>> 0;
}

// The weights: one row of signed bytes per intent, times one scale.
const DIM: number = BACKUP_MODEL.dim;
const INTENTS: string[] = BACKUP_MODEL.intents;
const BYTES = Uint8Array.from(atob(BACKUP_MODEL.weights), (c) => c.charCodeAt(0));
const WEIGHTS: Float32Array[] = INTENTS.map((_, k) =>
  Float32Array.from(new Int8Array(BYTES.buffer, k * DIM, DIM), (w) => w * BACKUP_MODEL.scale)
);

/** Introductions: "my name is Joy", "naitwa Furaha", "Hope here". */
const NAME_PATTERNS: RegExp[] = [
  /\b(?:my name is|my name's|i am called|i'm called|im called|call me|i go by|they call me|naitwa|jina langu ni|jina langu|niite|wananiita|mimi ni|i am|i'm|im|this is)\s+([\p{L}][\p{L}'-]*)/iu,
  /^\s*([\p{L}][\p{L}'-]*)\s+(?:here|hapa)\b/iu,
];

export function findName(text: string): string | null {
  for (const p of NAME_PATTERNS) {
    const m = text.match(p);
    if (m) return m[1];
  }
  return null;
}

/** Reads a message like Rasa's /model/parse does. */
export function backupParse(text: string): RasaParse {
  const buckets = new Set(features(text).map((f) => fnv1a(f) % DIM));
  const norm = Math.sqrt(buckets.size) || 1;
  const scores = INTENTS.map((_, k) => {
    let z = BACKUP_MODEL.bias[k];
    for (const j of buckets) z += WEIGHTS[k][j] / norm;
    return z;
  });
  const max = Math.max(...scores);
  const exps = scores.map((z) => Math.exp(z - max));
  const sum = exps.reduce((a, b) => a + b, 0);
  const ranking = INTENTS.map((name, k) => ({ name, confidence: exps[k] / sum }))
    .sort((a, b) => b.confidence - a.confidence);
  const top = ranking[0];
  const name = top.name === "tell_name" ? findName(text) : null;
  return {
    intent: top,
    intent_ranking: ranking,
    entities: name ? [{ entity: "name", value: name }] : [],
  };
}
