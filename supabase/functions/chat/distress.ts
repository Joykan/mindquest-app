// Indirect distress. Some people never use the words in crisis.ts: they say
// "what's the point" or "everyone would be better off without me". Such a
// message is not treated as a crisis by itself. Chipu asks directly and
// kindly whether they are thinking of hurting themselves, and the answer
// decides (see index.ts). The list errs on the side of asking too often.
//
// The Kiswahili phrases should be checked by a fluent speaker together with
// the crisis phrases and the training data.

import { normalize } from "./crisis.ts";

export const INDIRECT_PHRASES: string[] = [
  // English
  "whats the point",
  "what is the point",
  "no point in anything",
  "no point anymore",
  "pointless to go on",
  "cant go on",
  "cannot go on",
  "cant do this anymore",
  "cant take it anymore",
  "cant take this anymore",
  "i give up on life",
  "giving up on life",
  "tired of living",
  "tired of everything",
  "i am a burden",
  "im a burden",
  "such a burden",
  "better off without me",
  "wish i could disappear",
  "want to disappear",
  "wish i wasnt here",
  "wish i was never born",
  "nobody would miss me",
  "no one would miss me",
  "nothing matters anymore",
  "no way out",
  "life is meaningless",
  // Kiswahili and Sheng
  "hakuna maana ya maisha",
  "maisha hayana maana",
  "sioni maana ya kuendelea",
  "siwezi kuendelea",
  "siwezi tena",
  "nimechoka na maisha",
  "nimechoka na kila kitu",
  "mimi ni mzigo",
  "ni mzigo kwa wote",
  "wangekuwa bora bila mimi",
  "natamani nipotee",
  "ningependa nipotee",
  "hakuna atakayenikosa",
  "sioni njia ya kutoka",
];

const NORMALIZED = INDIRECT_PHRASES.map((p) => normalize(p));

/** True if the message contains an indirect-distress phrase as whole words. */
export function isIndirectDistress(text: string): boolean {
  const t = normalize(text);
  return NORMALIZED.some((p) => t.includes(p));
}

/** Tappable answers to Chipu's safety question (reply key "ask_safety"). */
export const SAFETY_OPTIONS = {
  en: ["Yes", "No, I'm just worn out", "I'm not sure"],
  sw: ["Ndiyo", "Hapana, nimechoka tu", "Sina uhakika"],
};

const YES = /^(yes|yeah|yep|yea|ndiyo|ndio|naam)\b/;
// "no" alone, or the tapped answer. "no one cares" is not a "no".
const NO =
  /^(no|nope|nah|not really|hapana|la|sivyo)( thanks| thank you| asante| im just worn out| i am just worn out| nimechoka tu)?$/;
const UNSURE = /\b(not sure|i dont know|idk|maybe|sina uhakika|sijui|labda)\b/;

/**
 * How the user answered "are you thinking of hurting yourself?": "yes" or
 * "unsure" (both get the helplines), "no", or null when the answer is
 * something else and the message should be read as usual.
 */
export function safetyAnswer(text: string): "yes" | "no" | "unsure" | null {
  const t = normalize(text).trim();
  if (UNSURE.test(t)) return "unsure";
  if (YES.test(t)) return "yes";
  if (NO.test(t)) return "no";
  return null;
}
