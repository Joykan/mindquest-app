# Chatbot training data

Example phrases the Rasa model learns from, in English and Kiswahili (with some Sheng).

```
nlp/
  rasa/data/nlu.yml          training examples (391)
  rasa/tests/test_nlu.yml    held-out test examples (44), never used for training
  rasa/tests/test_names.yml  held-out test for names vs feelings (12)
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

**v2** (355 examples): 25 examples added to the weakest intents to separate
those overlaps, for example "I'm feeling great" for feel_good and "you helped me
a lot" for thank. A new `tell_name` intent separates names like Joy and Furaha
from feelings (see above). No test phrases were copied into training, and the
original 44-phrase test set is unchanged, so v1 and v2 compare fairly.
