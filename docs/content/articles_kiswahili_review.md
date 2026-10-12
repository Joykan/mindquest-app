# Learn articles: Kiswahili review

The Learn screen has 12 short articles, three per topic, in English and Kiswahili
(`supabase/migrations/20261007100100_seed_reference_data.sql` and
`20261010153348_more_articles.sql`). A fluent Kiswahili speaker should check
the Kiswahili text before user testing. Corrections can be made in the
Supabase Table Editor (`resources.title_sw`, `resources.body_sw`) or sent back
for a new migration.

| Topic | English title | Kiswahili title | Checked |
|---|---|---|---|
| Stress | Understanding stress | Kuelewa msongo wa mawazo | ✅ |
| Stress | Exam stress: a survival plan | Msongo wa mitihani: mpango wa kukabiliana | ✅ |
| Stress | Sleep and your mood | Usingizi na hisia zako | ✅ |
| Anxiety | Calming anxiety: 5-4-3-2-1 grounding | Kutuliza wasiwasi: mbinu ya 5-4-3-2-1 | ✅ |
| Anxiety | What anxiety feels like in the body | Wasiwasi unavyohisiwa mwilini | ✅ |
| Anxiety | Box breathing for a racing mind | Kupumua kwa mraba kutuliza akili | ✅ |
| Mindfulness | One-minute mindful breathing | Kupumua kwa utulivu kwa dakika moja | ✅ |
| Mindfulness | A five-minute body scan | Kuchunguza mwili kwa dakika tano | ✅ |
| Mindfulness | Three good things | Mambo matatu mazuri | ✅ |
| Support | Talking to someone you trust | Kuzungumza na mtu unayemwamini | ✅ |
| Support | Helping a friend who is struggling | Kumsaidia rafiki anayepitia magumu | ✅ |
| Support | Where to get help in Kenya | Mahali pa kupata msaada Kenya | ✅ |

Things to check: natural wording for young Kenyans, correct health terms, and
that the helpline numbers match the Helplines table (1199, +254 722 178 177,
116; emergency 999 or 112).

Content rules: general information only, no diagnosis, every article points
to real help (a counsellor, health worker or helpline) when things are serious.

## Review result (12 Oct 2026)

Reviewed by Rajula Bonum (`nlp/review/MindQuest_Kiswahili_review_reviewed_2026-10-12.xlsx`).

| Part | Result |
|---|---|
| Chatbot phrases | 302 of 303 approved. One test phrase ("hali yako je") marked; suggested "Hali yako vipi?". The test set is kept unchanged so the reported v3 results stay reproducible; the suggestion goes into the next evaluation round. |
| Chatbot replies | 19 of 25 approved; 6 corrected (goodbye, anxious, 2 sad, deny, crisis). Chat function v8 deployed 12 Oct. |
| Crisis phrases | All 16 approved; reviewer added "nimefika kikomo", "ntajitia kitanzi", "maisha yamenichosha" (also added the standard forms "nitajitia kitanzi", "kujitia kitanzi"). |
| Articles | 54 of 57 parts approved; 2 corrected (migration `20261012125349_kiswahili_review_articles.sql`); "Box breathing", paragraph 2 marked N with no suggestion, to follow up. |
| App words | All 27 approved. |

Small edits made when applying: "kinaweza" changed to "kunaweza" (agrees with "kuongea"),
"kwakunielezea" written as "kwa kunielezea", the crisis reply keeps its closing colon
because the helpline list follows, and the exam paragraph keeps its last two sentences
(the suggestion replaced only the first).
