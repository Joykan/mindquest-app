# User acceptance testing (UAT) plan

## Goal

Find out whether students:

1. can do the main things in MindQuest without help (task completion);
2. find it easy to use (System Usability Scale, SUS);
3. find Chipu, the mood check-ins, the rewards and the Kiswahili support
   useful and motivating (MindQuest statements);
4. run into bugs or confusing parts (open answers).

This is a usability and acceptance test, not a study of whether the app
improves mental health. Participants are **not** asked about their own mental
health, and nobody reads their chats or notes.

## Format: remote, 5 days

Because testing happens away from campus, it is done remotely:

| When | What |
|---|---|
| Day 0 | Send the invitation (WhatsApp). Those who agree get the APK link and the Google Form link. |
| Day 1 | Participants install the app and do tasks T1–T8 (about 20 minutes). |
| Days 1–5 | They use MindQuest as they like (check in, chat, read). One reminder message on day 3. |
| Day 5 | They fill in the Google Form (about 10 minutes). It is also linked in the app: Profile → Give feedback on MindQuest. |
| Day 6–7 | Close the form. Copy the results into the workbook. |

**First, a pilot:** run the whole thing with 2–3 friends for 2 days. Fix what
confuses them (wording of tasks or questions, install problems), then start
the real round. Pilot answers are not counted.

## Participants

- **10–20 students**, aged 18 or over (anyone under 18 is not included).
- Android phone (the app is an Android APK).
- Recruited through class or hostel WhatsApp groups and friends; taking part
  is voluntary, and stopping at any time is fine.
- Try for a mix: English and Kiswahili users, different years of study.

## Before starting (checklist)

- [ ] All system tests run; critical and major bugs fixed (`test-plan.md`).
- [ ] Chipu online for the 5 days (see "Keeping Chipu online" below).
- [ ] Verified helplines checked in the admin dashboard (call each number).
- [ ] Google Form made from the questions below; its link saved as
      `FEEDBACK_URL` in `config/dev.json`.
- [ ] Release APK built and uploaded to Google Drive ("Anyone with the link").
- [ ] Pilot done.

### Building the APK for testers

```
flutter build apk --release --split-per-abi --dart-define-from-file=config/dev.json
```

Share `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (about
20 MB; it works on almost all phones from the last 7 years). Installing it:
open the link on the phone → Download → open the file → allow "Install
unknown apps" for the browser or Files app when Android asks → Install.

### Keeping Chipu online

The chatbot's NLU model (Rasa) runs on the PC through ngrok. For a 5-day
remote test, the PC would have to stay on and connected the whole time.
Two options:

1. **Hugging Face Space (free, recommended).** `nlp/rasa/Dockerfile` builds
   and trains the model on a free Hugging Face Space:
   1. Create a free account at huggingface.co → New Space → name
      `mindquest-nlu`, SDK **Docker**, template **Blank**, hardware **CPU basic
      (free)**, visibility **Public** (the endpoint still needs the token).
   2. In the Space's Files, upload `Dockerfile`, `config.yml` and
      `data/nlu.yml` (inside a `data` folder), from `nlp/rasa`.
   3. Edit the Space's `README.md` so its first lines are:
      ```
      ---
      title: MindQuest NLU
      sdk: docker
      app_port: 7860
      ---
      ```
   4. Settings → Variables and secrets → New secret: `RASA_TOKEN` = the same
      value as in `.rasa-token`.
   5. Wait for the build (Logs tab, a few minutes; it trains the model).
      Open `https://<username>-mindquest-nlu.hf.space/status?token=<token>`:
      it should show the model file.
   6. Supabase → Edge Functions → Secrets → set `RASA_URL` to
      `https://<username>-mindquest-nlu.hf.space`. Chat in the app to check.

   Free Spaces go to sleep after 2 days without use; the first message after
   that may get "try again" while it wakes up (about a minute). During the
   test it is used every day, so it stays awake. (Not tried yet: run the
   chatbot system tests ST-10 to ST-16 after moving it.)
2. **The PC with ngrok**, as now. Free, but if the PC sleeps, loses power or
   internet, Chipu replies "try again" (mood check-ins, articles, rewards and
   the helplines keep working).

Email sign-up sends a confirmation email, and Supabase's built-in email
service only sends a few per hour. Ask testers to use **Continue anonymously**
or **Google**, so no custom email service is needed for the test.

## Safety and ethics

- MindQuest is not therapy and not an emergency service. The invitation, the
  consent text and the end of the form all say this and list the helplines.
- The app shows helplines when a message sounds like a crisis; that check
  works even offline.
- Participants are not asked about their own mental health, diagnoses or
  feelings in the form; only about using the app.
- If a participant tells you they are struggling: thank them, don't try to
  counsel them, and share Kenya Red Cross 1199 (free, 24 hours), emergency
  999 or 112, and the university counselling service.
- Data: the app stores chats and check-ins on the project's Supabase server
  so it can work. You only look at totals on the admin dashboard, never at
  messages or notes. The form collects no names or emails. Participants can
  delete everything in the app at any time (Profile → Delete my data). Test
  data is deleted when the project is marked.

## Invitation (WhatsApp)

> Hi! I'm Candy, a final-year IT student at Maseno University. For my project
> I built **MindQuest**, an app where you check in on your mood, chat with
> **Chipu** (a friendly chatbot, in English or Kiswahili) and earn XP and
> badges for looking after yourself.
>
> I'm looking for 10–20 students (18+, Android phone) to try it for 5 days
> and then fill in a 10-minute anonymous form. You don't need an account or
> your real name.
>
> MindQuest is a student project, not therapy or an emergency service. If
> you're going through a hard time, please call Kenya Red Cross on 1199
> (free, 24 hours) or 999/112 in an emergency.
>
> Interested? Reply and I'll send the link. Thank you! 🌱

## Google Form

Settings: don't collect email addresses; limit to one response is optional
(it needs sign-in, so leave it off); show progress bar on.

### Section 1: About this study

Description (paste):

> Thank you for trying MindQuest. This form takes about 10 minutes.
>
> **What this is:** a final-year project at Maseno University (CIT 409). The
> form asks how easy and useful the app was. It does not ask about your own
> mental health.
>
> **Your answers are anonymous.** Don't write your name. Answers are only
> used for the project report, as totals and short quotes without names.
>
> **Your data in the app:** your check-ins and chats are stored on the
> project's server so the app works. The student researcher only sees totals
> (for example "12 check-ins today"), never your messages or notes. You can
> delete everything in the app: Profile → Delete my data. All test data is
> deleted after the project.
>
> **Taking part is voluntary.** You can stop at any time.
>
> MindQuest is not therapy or an emergency service. If you need help now,
> call Kenya Red Cross 1199 (free, 24 hours) or 999 / 112.

Question (required, multiple choice):
**I am 18 or older, I have read the information above, and I agree to take
part.**
- Yes, I agree → continue
- No → submit form (Section "Thank you")

### Section 2: About you

1. Age: 18–20 / 21–23 / 24–26 / 27 or older
2. Year of study: 1 / 2 / 3 / 4 / 5 or more / Not a student
3. Which language did you mostly use in MindQuest? English / Kiswahili / Both
4. On how many days did you open MindQuest? 1 / 2–3 / 4–5 / 6 or more
5. Phone brand (optional, short answer), e.g. Tecno, Samsung, vivo

### Section 3: Tasks

Multiple-choice grid: **How did these go?**
Columns: Done easily / Done with some difficulty / Couldn't do it / Didn't try

| Row | Task |
|---|---|
| T1 | Installing MindQuest and getting started |
| T2 | Checking in my mood with a tag |
| T3 | Chatting with Chipu and getting a breathing exercise |
| T4 | Reading an article and marking it as read |
| T5 | Finding my level, badges and weekly quest |
| T6 | Finding where to get help quickly |
| T7 | Switching the app's language |
| T8 | Turning on the daily reminder |

(The task list with what counts as done is in the workbook, sheet UAT tasks.)

### Section 4: Using MindQuest (SUS)

Multiple-choice grid, columns 1 Strongly disagree / 2 / 3 / 4 / 5 Strongly
agree; require a response in each row; keep this order:

1. I think that I would like to use MindQuest frequently.
2. I found MindQuest unnecessarily complex.
3. I thought MindQuest was easy to use.
4. I think that I would need the support of a technical person to be able to use MindQuest.
5. I found the various functions in MindQuest were well integrated.
6. I thought there was too much inconsistency in MindQuest.
7. I would imagine that most people would learn to use MindQuest very quickly.
8. I found MindQuest very cumbersome to use.
9. I felt very confident using MindQuest.
10. I needed to learn a lot of things before I could get going with MindQuest.

(System Usability Scale, Brooke 1996. Keep the wording and order so scores
compare with other studies.)

### Section 5: MindQuest's features

Multiple-choice grid, columns 1 Strongly disagree / 2 / 3 / 4 / 5 Strongly
agree / Not applicable:

| | Statement |
|---|---|
| L1 | Chipu understood what I wrote. |
| L2 | Chipu's replies felt kind and supportive. |
| L3 | Chatting in Kiswahili or Sheng worked well. |
| L4 | Earning XP, levels and badges made me want to come back. |
| L5 | The daily quests and streak encouraged me to check in. |
| L6 | Chipu's mood insights helped me notice something about my moods. |
| L7 | The articles were useful to me. |
| L8 | I know where in the app to find help in a crisis. |
| L9 | I trust MindQuest to keep my information private. |
| L10 | I would recommend MindQuest to a friend. |

Then: **Would you keep using MindQuest after this test?** Yes / Maybe / No

### Section 6: Your thoughts (all optional, paragraph answers)

1. What did you like most about MindQuest?
2. What was confusing, annoying or hard to use?
3. Did anything go wrong (an error, a crash, something that didn't work)?
   What were you doing?
4. Did any Kiswahili text sound wrong or strange? Which one?
5. What would you add or change?

### Section: Thank you

> Thank you for helping with MindQuest! 🌱 You can keep using the app, or
> delete your data in Profile → Delete my data.
>
> If you're going through a hard time, you don't have to face it alone: Kenya
> Red Cross 1199 (free, 24 hours), emergency 999 or 112, or your university's
> counselling service.

## Analysis

Download the responses (Responses → Download CSV) and fill in the workbook
`MindQuest_testing.xlsx`:

| Measure | Sheet | Target |
|---|---|---|
| Task completion per task | UAT tasks | 78% or more per task |
| SUS score (mean, median, SD) | SUS | above 68 (average); 80+ is good |
| Agreement per statement (% choosing 4 or 5) | Likert | 70% or more agree |
| Usage during the test (active students, check-ins, chats, % understood, crisis responses) | Admin dashboard, period covering the test | For the report, totals only |
| Problems found | Bugs | All critical and major fixed |

Open answers: group them into themes (e.g. "chatbot understanding", "rewards",
"Kiswahili", "bugs") and count how many people mention each; pick a few short
quotes (no names) for the report.

Report the numbers honestly with the group size (for example "SUS 74.5,
n = 14"); with 10–20 people the results show trends, not proof.
