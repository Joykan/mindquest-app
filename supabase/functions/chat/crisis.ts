// Crisis check. Runs on every message before the NLU model, so a missed or
// wrong classification can never hide a crisis (see the conversation flow).
//
// The phrases are matched as whole words after lower-casing and removing
// punctuation. The list errs on the side of showing help too often rather than
// too rarely. The Kiswahili and Sheng phrases should be checked by a fluent
// speaker together with the training data.

export const CRISIS_PHRASES: string[] = [
  // English
  "suicide",
  "suicidal",
  "kill myself",
  "killing myself",
  "end my life",
  "ending my life",
  "take my own life",
  "want to die",
  "wanna die",
  "wish i was dead",
  "wish i were dead",
  "better off dead",
  "dont want to live",
  "do not want to live",
  "dont want to be alive",
  "no reason to live",
  "end it all",
  "hurt myself",
  "harm myself",
  "self harm",
  "cut myself",
  // Kiswahili and Sheng
  "kujiua",
  "nijiue",
  "nitajiua",
  "nataka kufa",
  "natamani kufa",
  "sitaki kuishi",
  "nimechoka kuishi",
  "kujitoa uhai",
  "nijitoe uhai",
  "kujidhuru",
  "nijidhuru",
  "nitajidhuru",
  "kujikata",
  "kujimaliza",
  "nijimalize",
  "nataka kujimaliza",
];

/** Lower-case, drop apostrophes, turn other punctuation into spaces. */
export function normalize(text: string): string {
  return ` ${
    text
      .toLowerCase()
      .replace(/['’`]/g, "")
      .replace(/[^\p{L}\p{N}]+/gu, " ")
      .trim()
  } `;
}

const NORMALIZED = CRISIS_PHRASES.map((p) => normalize(p));

/** True if the message contains any crisis phrase as whole words. */
export function isCrisis(text: string): boolean {
  const t = normalize(text);
  return NORMALIZED.some((p) => t.includes(p));
}
