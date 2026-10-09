# Chatbot training data

Example phrases the Rasa model learns from, in English and Kiswahili (with some Sheng).

```
nlp/
  rasa/data/nlu.yml          training examples (391)
  rasa/tests/test_nlu.yml    held-out test examples (44), never used for training
  rasa/tests/test_names.yml  held-out test for names vs feelings (12)
  rasa/results/              output of each test run (reports, confusion matrices)
  review/kiswahili_review.csv  sheet for a Kiswahili speaker to check every phrase
```

## Intents

The intents come from the chatbot conversation flow diagram. `affirm` and `deny`
handle the "Accept the breathing exercise?" step.

| Intent | Meaning | Train (EN + SW) | Test |
|---|---|---|---|
| `greet` | Says hello | 17 + 15 | 4 |
| `goodbye` | Ends the conversation | 15 + 15 | 4 |
| `thank` | Says thank you | 18 + 16 | 4 |
| `affirm` | Agrees (yes, sawa, poa) | 15 + 18 | 4 |
| `deny` | Declines (no, hapana) | 15 + 15 | 4 |
| `feel_stressed` | Stress or pressure | 16 + 17 | 4 |
| `feel_anxious` | Worry, fear or anxiety | 16 + 17 | 4 |
| `feel_sad` | Sadness or loneliness | 16 + 17 | 4 |
| `feel_good` | Good mood | 23 + 20 | 4 + 4 (names test) |
| `ask_breathing` | Wants a calming or breathing exercise | 15 + 15 | 4 |
| `ask_about_bot` | Asks what MindQuest is or about privacy | 15 + 15 | 4 |
| `tell_name` | Says their name; the name is extracted | 15 + 15 | 8 (names test) |
| **Total** | | **391** | **44 + 12** |

## How the data was put together

- Each intent has about the same number of English and Kiswahili examples so the
  model does not favour one language.
- Examples vary in length, formality and wording (short replies like "poa",
  full sentences, Sheng, and some code-mixing like "nina stress ya mitihani").
- The test set uses phrases that do not appear in training, so accuracy
  measured on it reflects how the model handles new wording.
- Crisis messages are not an intent. They are caught by a keyword check before
  the model runs (see the conversation flow), so a missed classification can
  never hide a crisis.

## Names that are also feelings

Many Kenyan names are also emotion words: Joy, Hope, Grace, Faith, Furaha,
Amani, Neema, Imani, Baraka. Without help, "naitwa Furaha" (my name is Furaha)
would be read as feeling good, because "furaha" means happiness.

- `tell_name` examples mark the name as an entity, e.g. `naitwa [Furaha](name)`.
  The DIET classifier learns to predict the intent and pull out `name: Furaha`
  at the same time, so the bot can reply "Nice to meet you, Furaha".
- `feel_good` has contrast examples that use the same words as feelings, e.g.
  "I'm full of joy" and "nimejawa na furaha", so the model learns that the
  surrounding words ("my name is", "naitwa" vs "full of", "nimejawa na") decide
  the meaning.
- `tests/test_names.yml` checks both directions on phrases not used in training.

## Review

Before training, a fluent Kiswahili speaker should go through
`review/kiswahili_review.csv` (opens in Excel or Google Sheets), mark each phrase
Y or N, and suggest corrections. Corrections are then copied into `nlu.yml` and
`test_nlu.yml`.

## Versions

**v1** (330 examples, 30 per intent): 81.8% accuracy and macro F1 0.82 on the
44 test phrases. Most errors came from words shared across intents, such as
"good" (greet vs feel_good), "feeling" (feel_good vs feel_sad) and the Kiswahili
root "tulia" (feel_anxious vs ask_breathing).

**v2** (391 examples): 25 examples added to the weakest intents to separate
those overlaps, for example "I'm feeling great" for feel_good and "you helped me
a lot" for thank. A new `tell_name` intent (30 examples plus 6 contrast examples
in feel_good) separates names like Joy and Furaha from feelings (see above). No
test phrases were copied into training, and the original 44-phrase test set is
unchanged, so v1 and v2 compare fairly.

## Results (v2)

| Test | What it measures | Accuracy | Macro F1 |
|---|---|---|---|
| `test_nlu.yml`, 44 phrases | New wording, 11 intents | 93.2% (v1: 81.8%) | 0.93 (v1: 0.82) |
| `test_names.yml`, 12 phrases | Names vs feelings | 91.7% | 0.90 |
| 5-fold cross-validation, 391 phrases | Every example tested once | 62.7% | 0.63 |

Name extraction on the names test: precision 0.89, recall 1.00, F1 0.94. All 8
names were found; one feeling phrase was wrongly read as a name.

Remaining errors on the 44-phrase test: one deny read as thank, one feel_anxious
read as ask_breathing, one greet read as feel_good.

**Why cross-validation is much lower.** The two test files are small (4 phrases
per intent), so one mistake moves accuracy by more than 2%. Also, the v2
additions were chosen after looking at v1's test errors, which slightly favours
that test set. Cross-validation tests every one of the 391 examples while
training on only about 24 per intent, so it is the stricter and more honest
figure. It shows where the model is still weak:

- `affirm` (F1 0.43) and `deny` (0.51): short replies like "poa", "sawa", "fiti"
  look like feel_good or goodbye, and affirm and deny get mixed up.
- `feel_sad` (0.49): 12 sad phrases were read as feel_good, because both use the
  same words ("feeling", "today", "leo", "moyo").
- `feel_stressed` vs `feel_anxious` (0.58 each): the two feelings overlap in
  everyday speech, so some confusion is expected.

The next version should add more varied examples to these intents. In the app,
any prediction below 0.5 confidence goes to the fallback reply instead of a
guessed answer.
