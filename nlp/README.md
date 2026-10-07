# Chatbot training data

Example phrases the Rasa model learns from, in English and Kiswahili (with some Sheng).

```
nlp/
  rasa/data/nlu.yml          training examples (330)
  rasa/tests/test_nlu.yml    held-out test examples (44), never used for training
  review/kiswahili_review.csv  sheet for a Kiswahili speaker to check every phrase
```

## Intents

The intents come from the chatbot conversation flow diagram. `affirm` and `deny`
handle the "Accept the breathing exercise?" step.

| Intent | Meaning | Train (EN + SW) | Test |
|---|---|---|---|
| `greet` | Says hello | 15 + 15 | 4 |
| `goodbye` | Ends the conversation | 15 + 15 | 4 |
| `thank` | Says thank you | 15 + 15 | 4 |
| `affirm` | Agrees (yes, sawa, poa) | 15 + 15 | 4 |
| `deny` | Declines (no, hapana) | 15 + 15 | 4 |
| `feel_stressed` | Stress or pressure | 15 + 15 | 4 |
| `feel_anxious` | Worry, fear or anxiety | 15 + 15 | 4 |
| `feel_sad` | Sadness or loneliness | 15 + 15 | 4 |
| `feel_good` | Good mood | 15 + 15 | 4 |
| `ask_breathing` | Wants a calming or breathing exercise | 15 + 15 | 4 |
| `ask_about_bot` | Asks what MindQuest is or about privacy | 15 + 15 | 4 |
| **Total** | | **330** | **44** |

## How the data was put together

- Each intent has the same number of English and Kiswahili examples so the model
  does not favour one language.
- Examples vary in length, formality and wording (short replies like "poa",
  full sentences, Sheng, and some code-mixing like "nina stress ya mitihani").
- The test set uses phrases that do not appear in training, so accuracy
  measured on it reflects how the model handles new wording.
- Crisis messages are not an intent. They are caught by a keyword check before
  the model runs (see the conversation flow), so a missed classification can
  never hide a crisis.

## Review

Before training, a fluent Kiswahili speaker should go through
`review/kiswahili_review.csv` (opens in Excel or Google Sheets), mark each phrase
Y or N, and suggest corrections. Corrections are then copied into `nlu.yml` and
`test_nlu.yml`.
