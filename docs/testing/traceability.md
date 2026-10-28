# Requirements traceability (approved proposal → system → tests)

Every requirement in the approved CIT 409 proposal, where it is in the
system, and how it is tested. Test IDs: **ST-xx** are the manual system tests
in `MindQuest_testing.xlsx`; file names are automated tests (run by CI);
**UAT** is the user acceptance test (`uat-plan.md`).

Status: **Done** = built and tested; **To measure** = built, needs the phone
tests or UAT to show it meets the target; **Deviation** = met in a different
way than the proposal describes (reason given).

## Functional requirements (proposal 4.1.2)

| FR | Requirement | In the system | Tested by | Status |
|---|---|---|---|---|
| FR 1 | Interactive AI-driven chat sessions for emotional wellness support | Chat with Chipu: Rasa NLU (13 intents, EN/SW/Sheng), reply rules, breathing exercise, ideas, new chat, past chats | `chat_screen_test`, `logic_test.ts`, NLU evaluation (`nlp/README.md`), ST-10–ST-20, UAT T3 | Done |
| FR 2 | Record, monitor and visualise mood trends | Mood check-in (5 emojis, note, tags), summary, week strip, 7-day chart, 30-day history, insights | `home_mood_test`, `mood_insights_test`, ST-21–ST-24, UAT T2 | Done |
| FR 3 | Gamification: badges, challenges, streaks | XP, 6 levels, 13 badges, daily quests, weekly quest, 4 themed 7-day challenges, streak with one rest day a week, Chipu's outfits unlocked by level; pop-up and notification for every new badge (`docs/fun-features.md`) | Database tests (step 4, 10, fun features), `learn_rewards_test`, `badge_watcher_test`, `fun_test`, ST-25–ST-28, ST-53–ST-61, UAT T5, T9, T10 + L4, L5, L11, L12 | Done |
| FR 4 | Educational resources on stress, anxiety and mindfulness | Learn: 12 articles EN/SW in 4 topics (stress, anxiety, mindfulness, getting support), recommendations; admins edit them | `learn_rewards_test`, ST-29, ST-43, UAT T4 + L7 | Done |
| FR 5 | Detect distress inputs and recommend helplines | Crisis phrase check on every message (server, and on the phone when offline), crisis sheet with Call buttons, Support page; admins verify helplines | `logic_test.ts`, `chat_screen_test`, `offline_test`, ST-15, ST-16, ST-30, ST-31, ST-34, ST-44, UAT T6 + L8 | Done |
| FR 6 | Bilingual communication in English and Swahili | Every screen, date and message in both languages; Chipu replies in the user's language; Kiswahili reviewed by a fluent speaker | `kiswahili_test`, ST-09, ST-12, ST-13, ST-16, UAT T7 + L3 | Done |
| FR 7 | Administrative dashboard for monitoring and analytics | Admin web app: Overview (totals, charts, reply time, system health, copy report), Articles, Helplines, Team | `admin_test`, ST-41–ST-45, ST-50, ST-51 | Done |

## Detailed specifications (proposal 4.3.4)

| Spec | Requirement | In the system | Tested by | Status |
|---|---|---|---|---|
| FR-SPEC-01 | 5 predefined emojis, optional 200-character note, timestamped, saved immediately on confirmation | 5 faces; note limited to 200 characters (also enforced by the database); `logged_at` time stamp; saved at once, or on the phone first when offline and sent later | `home_mood_test`, database tests, ST-21, ST-33 | Done |
| FR-SPEC-02 | Scan all messages for high-distress keywords; if detected with negative sentiment, immediately show helplines | Every message is checked before the NLU model; on a match the helplines show at once | `logic_test.ts`, `offline_test`, ST-15, ST-16, ST-34 | Deviation: the keyword match alone shows the helplines, without a separate sentiment test. A sentiment step could miss a real crisis written calmly ("I want to end it all"), so the safer choice is to always show help. |
| NFR-SPEC-01 | Reply in under 2 seconds for 95% of interactions under normal load | The chat function records each reply's server time; the dashboard shows the median, the 95th percentile and the share within 2 s. End-to-end time on the phone is timed in ST-20 | `admin_test`, ST-20, Overview during UAT | To measure |
| NFR-SPEC-02 | 99.5% uptime per month | Supabase (database, auth, functions) is a managed cloud service. The NLU server is the weak point (on the PC, or a free Hugging Face Space). The System health card checks it, and the Overview counts replies where it was unreachable | ST-50, Overview "unavailable" count over the UAT month | To measure (see limitations) |

## Non-functional requirements (proposal 4.1.2)

| NFR | Requirement | In the system | Tested by | Status |
|---|---|---|---|---|
| NFR 1 | Response time below 2 seconds | See NFR-SPEC-01 | ST-20 | To measure |
| NFR 2 | Data confidentiality through encryption and anonymisation | HTTPS (TLS) for all traffic; Supabase encrypts stored data (AES-256); row-level security on every table; anonymous accounts by default, age as a range only; crisis events stored without text; dashboard shows totals only and hides averages from fewer than 5 check-ins; Delete my data | Database security tests, Supabase security advisor, ST-08, ST-46 | Done (limitation: data saved on the phone for offline use is in the app's private storage, not separately encrypted) |
| NFR 3 | 99.5% uptime through reliable cloud hosting | See NFR-SPEC-02 | ST-50 | To measure |
| NFR 4 | Simple, mobile-optimised interface for youth | Bottom navigation with 5 tabs, large touch targets, Chipu mascot, dark mode, works with large fonts; also a website that adapts to phones and laptops | `web_test`, ST-38–ST-40, ST-62, ST-63, UAT SUS + tasks | To measure (UAT) |
| NFR 5 | Scale to high user traffic | Supabase Postgres and Edge Functions scale on the managed service; indexes on the busy tables | Not load-tested | Limitation: the single Rasa server would be the bottleneck; a load test and a larger NLU server are future work |
| NFR 6 | Efficient under low bandwidth using PWA caching | The app saves what it loads and keeps working offline; check-ins and reads are queued and sent later; small requests. The website is a PWA: a service worker keeps its files so it opens without internet, and it can be installed (`docs/web-version.md`) | `offline_test`, ST-32–ST-35, ST-49 (2G), ST-64, ST-65 | Done (Android app: offline cache and sync queue; website: the same plus PWA caching) |
| NFR 7 | Cultural and linguistic appropriateness | Kiswahili and Sheng training phrases, Kiswahili reviewed by a fluent speaker, Kenyan helplines, local examples (exams, family, money) | NLU evaluation, UAT L2, L3 | To measure (UAT) |

## Use cases (proposal Figure 4)

| Use case | Actor | In the system | Tested by |
|---|---|---|---|
| Conduct AI Chat Session (UC 1) | Adolescent user | Chat | ST-10–ST-20 |
| Log Mood Entry (UC 2) | Adolescent user | Mood check-in (also in chat) | ST-18, ST-21–ST-24 |
| Earn Badge | Adolescent user | Badges (pop-up and notification), challenge badges, streak badges | ST-26, ST-53, ST-54, ST-59 |
| View Educational Resources | Adolescent user | Learn and articles | ST-29 |
| Contact Helpline | Adolescent user | Crisis sheet, Support page, Call buttons | ST-15, ST-31 |
| Track Progress | Adolescent user | Home (streak, rest day, level, quests, challenge), Mood history, Rewards (wardrobe) | ST-23, ST-25–ST-28, ST-54–ST-58 |
| Generate Reports | Administrator | Overview, Copy report | ST-42, ST-51 |
| Monitor System Health | Administrator | System health card, reply time, unavailable count | ST-50 |
| Manage Content | Administrator | Articles and Helplines pages | ST-43, ST-44 |
| View Aggregated Analytics | Counsellor | Overview only (counsellor role) | ST-45 |

## Registration data (proposal Table 3)

"Username, age, language preference": nickname, age range (Under 15, 15–17,
18–20, 21–24, 25 or older, Prefer not to say) and language are asked at
onboarding. A range is stored instead of the age or date of birth, to keep
accounts anonymous (NFR 2). Tested by `auth_test` and ST-52.

## Testing objectives (proposal 1.3.3, testing phase)

| Objective | How it is met |
|---|---|
| i. Unit, integration and UAT for chatbot interactions in both languages | Unit: `logic_test.ts` (20), `chat_screen_test`; integration: the app talking to the live chat function and Rasa (ST-10–ST-19, in English and Kiswahili); NLU evaluation on held-out English and Kiswahili phrases; UAT T3, L1–L3 |
| ii. Gamification usability, engagement and reward accuracy | Accuracy: database tests of every XP, streak (rest days), quest, challenge and badge rule, ST-25–ST-28, ST-54–ST-61; usability: UAT T5, T9, T10; engagement: UAT L4, L5, L11, L12 and the dashboard (active students, check-ins per day) |
| iii. Offline functionality under simulated low-bandwidth conditions | `offline_test` (24), ST-32–ST-35 (aeroplane mode), ST-49 (phone set to 2G) |
| iv. Security audits for ethical data handling and privacy | Row-level security tests as a real user (steps 4, 10, 11), Supabase security advisor, admin functions refuse non-staff, averages hidden for small groups, crisis events without text, Delete my data (ST-08, ST-46) |

## Stack (proposal Table 4)

| Proposal | Used | Note |
|---|---|---|
| Flutter | Flutter (Android app, website (PWA) and web admin dashboard) | |
| Supabase Edge Functions | `chat`, `delete-account`, `health` | XP and badge rules run as database triggers, called on every user action |
| Supabase (PostgreSQL) | Yes, with row-level security | |
| Supabase Auth | Email/password, Google, anonymous | |
| Dialogflow/Rasa | Rasa (Dialogflow was built and compared; Rasa was more accurate and handles mixed languages) | `nlp/README.md` |
| flutter_local_notifications | Daily reminders and badge unlock alerts | |
| Figma, Git & GitHub | Yes | Wireframes and hi-fi screens; private repository with CI |

## Participants (proposal chapter 3: population, sampling and ethics)

The proposal's population is youth aged 15–24 in Kisumu County, with consent,
and assent plus guardian approval for minors. UAT follows this: participants
aged 15–24, consent in the form, and for 15–17-year-olds a parent or guardian
must agree first (see `uat-plan.md`).
