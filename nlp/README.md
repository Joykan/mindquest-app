# Chatbot training data

Example phrases the Rasa model learns from, in English and Kiswahili (with some Sheng).

```
nlp/
  rasa/data/nlu.yml          training examples (619)
  rasa/tests/test_nlu.yml    held-out test examples (48), never used for training
  rasa/tests/test_names.yml  held-out test for names vs feelings (12)
  rasa/results/              output of each test run (reports, confusion matrices)
  review/kiswahili_review.csv  sheet for a Kiswahili speaker to check every phrase
```

## Intents

The intents come from the chatbot conversation flow diagram. `affirm` and `deny`
handle the "Accept the breathing exercise?" step.

| Intent | Meaning | Train (EN + SW) | Test |
|---|---|---|---|
| `greet` | Says hello | 21 + 20 | 4 |
| `goodbye` | Ends the conversation | 21 + 20 | 4 |
| `thank` | Says thank you | 22 + 20 | 4 |
| `affirm` | Agrees (yes, sawa, poa) | 26 + 29 | 4 |
| `deny` | Declines (no, hapana) | 25 + 24 | 4 |
| `feel_stressed` | Stress or pressure | 24 + 25 | 4 |
| `feel_anxious` | Worry, fear or anxiety | 24 + 25 | 4 |
| `feel_sad` | Sadness or loneliness | 29 + 28 | 4 |
| `feel_good` | Good mood | 33 + 30 | 4 + 4 (names test) |
| `ask_breathing` | Wants a calming or breathing exercise | 21 + 19 | 4 |
| `ask_about_bot` | Asks what MindQuest is or about privacy | 21 + 21 | 4 |
| `ask_ideas` | Asks for ideas of things to do (keep busy, lift their mood), added in v4 | 25 + 25 | 4 |
| `tell_name` | Says their name; the name is extracted | 21 + 20 | 8 (names test) |
| **Total** | | **619** | **48 + 12** |

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

**v3** (569 examples): 178 examples added, mostly to the intents that were weak
in v2 cross-validation. They target three kinds of error:

- Negation: "siko vizuri", "I'm not happy", "sina furaha" for feel_sad, so
  "sawa", "okay" and "vizuri" no longer point straight to feel_good.
- One-word replies: words like "poa", "fiti", "la" and "nah" now appear in
  several affirm and deny examples ("poa, tuanze", "la, sitaki") instead of once.
- "I'm ...": phrases like "I'm ready", "I'm happy" and "I'm not fine" so the model
  doesn't treat every "I'm X" as a name.

Two v2 examples were replaced because they were too close to the names test
("I feel so much joy today" and "jina langu furaha"). The pipeline and both test
files are unchanged, so any difference from v2 comes from the data.

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

## Results (v3)

| Test | v2 | v3 |
|---|---|---|
| 5-fold cross-validation (accuracy / macro F1) | 62.7% / 0.63 | **75.7% / 0.77** |
| `test_nlu.yml`, 44 phrases | 93.2% / 0.93 | 86.4% / 0.87 |
| `test_names.yml`, 12 phrases | 91.7% / 0.90 | 83.3% / 0.78 |
| Name extraction F1, names test | 0.94 | 0.94 |
| Name extraction F1, cross-validation | not measured | 0.94 |

Cross-validation went up for every intent: affirm 0.43 to 0.82, deny 0.51 to
0.67, feel_sad 0.49 to 0.67, feel_stressed 0.58 to 0.73, goodbye 0.60 to 0.79.

The two small tests went down by 3 phrases and 1 phrase:

- "so much joy today" was correct in v2 only because training had the almost
  identical "I feel so much joy today". With that removed, it fails. So v2's
  names score was too high, and v3's is the honest one.
- "I feel joy" and "all good here" were read as tell_name. "joy" is a name in
  most training examples that contain it, and "here" appears in name phrases
  like "Precious here".
- "alright bye" was read as affirm ("alright" is an affirm word),
  "nimefurahi, asante" as feel_good (it really is both), and the idiom "roho
  yangu iko chini" was missed again.

With 4 phrases per intent, three phrases is a 7% swing, so these tests are too
small to rank v2 and v3 on their own. Cross-validation uses all 569 phrases,
which makes it the better guide. **v3 is the model used in the app.**

Data changes stop here, so the test sets are not tuned any further. The
remaining name/feeling mix-ups are handled in the chat logic instead (step 7):

1. A message only counts as tell_name if a name was actually extracted.
   Otherwise the next most likely intent is used.
2. A name in an introduction ("my name is Joy", "naitwa Furaha", "I'm Hope")
   is used straight away. Only when a feeling word (Joy, Furaha, Amani...) is
   read as a name in a message that doesn't introduce anyone, such as "I feel
   joy", does the bot ask "Is Joy your name?" first.
3. If Rasa says "name" but extracts no name, and the message contains a
   happy word (joy, happy, furaha, amani...), it is read as feeling good.
   Without this, "I feel joy today" got the fallback reply in testing.

## v4: a new intent from app testing

While testing the app, "what do you advise I should do to keep my mind busy?"
was read as ask_about_bot (0.68 confidence, above the 0.5 cut-off), so Chipu
introduced itself instead of answering. None of the 12 intents covered asking
for ideas of things to do, so the model picked the nearest one.

v4 adds one intent, `ask_ideas` (25 English + 25 Kiswahili examples, 4 new
test phrases). Chipu answers with a few small, practical ideas (a short walk,
texting a friend, music, an article in Learn, the grounding exercise). The other
intents and their test phrases are unchanged, so v3 and v4 compare fairly on the
original 44 phrases.

To train and test v4 (on the PC that runs Rasa, in `nlp/rasa` with the venv
active):

```
rasa train nlu --out models
rasa test nlu --nlu tests/test_nlu.yml --model models --out results/v4
rasa test nlu --nlu tests/test_names.yml --model models --out results/names_v4
rasa test nlu --nlu data/nlu.yml --cross-validation --folds 5 --out results/cv_v4
```

Then restart `serve.ps1` so the app uses the new model.

Results (v4): to be filled in from `results/v4`, `results/names_v4` and
`results/cv_v4`.

## Rasa vs Dialogflow

Dialogflow ES was given the same 569 training phrases, the same test phrases
and the same 0.5 confidence cut-off (see `dialogflow/README.md`). Results are in
`dialogflow/results/`.

| Same test phrases | Rasa v3 | Dialogflow ES | Dialogflow, all sent as English |
|---|---|---|---|
| 44 test phrases: accuracy | **86.4%** | 70.5% | 38.6% |
| ...answered with an intent | 44 of 44 | 35 of 44 | 19 of 44 |
| ...correct when it answered | 38 of 44 (86%) | 31 of 35 (89%) | 17 of 19 (89%) |
| Names test (12): accuracy | 83.3% | **91.7%** | 50.0% |
| Name extraction F1 | **0.94** | 0.82 | 0.71 |

What the numbers show:

- **Rasa answers more.** Dialogflow gave no intent (fell back) on 9 of the 44
  phrases, mostly short or idiomatic ones like "si leo", "eeh", "too much on my
  plate" and "I'm so sad". When it did answer, it was right about as often as
  Rasa. Rasa answered everything, but its 6 mistakes were all made with high
  confidence (0.73 to 1.0), so the fallback would not have caught them.
- **Both miss the same hard cases**: "good day" (read as feel_good), "akili
  haitulii" (read as ask_breathing) and the idiom "roho yangu iko chini".
- **Names:** Dialogflow was better at not mistaking "I feel joy" for a name,
  but worse at pulling the name out. It returned "ni Furaha" instead of "Furaha"
  and "joy today" from a feelings phrase. Rasa found every name exactly.
- **Language:** Dialogflow keeps a separate model per language and must be told
  which one to use. Sent as English, almost every Kiswahili phrase got no
  answer. Rasa uses one model for both languages and is never told the
  language, which suits students who mix English, Kiswahili and Sheng in one
  message.

Fairness: the v2 data was improved after looking at Rasa's v1 test errors, while
Dialogflow got the data as it is. That favours Rasa slightly on the 44-phrase
test. Dialogflow has no cross-validation, so only the two test files could be
compared.

Other differences that matter for MindQuest:

| | Rasa | Dialogflow ES |
|---|---|---|
| Where messages are processed | On our own server | On Google's servers |
| Mixed-language messages | One model handles both | Language must be chosen per message |
| Control over the model | Full (pipeline, thresholds, entities) | Limited to settings in the console |
| Setup and hosting | Harder: needs a server to run on | Easier: hosted by Google |
| Cost | Free, open source (only hosting costs) | Google Cloud pricing per request |

**Decision: Rasa.** It matched or beat Dialogflow on the main test, handles
mixed languages with one model, and keeps students' messages on infrastructure
the project controls, which matters for a mental health app (half of the survey
respondents raised privacy). The cost is that Rasa needs its own server, which
is planned in step 7. Dialogflow's habit of giving no answer when unsure is a
useful idea, and MindQuest's fallback reply plays the same role.
