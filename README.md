# MindQuest

A gamified AI chatbot for mental health awareness among Kenyan youth, in English and Kiswahili.

CIT 409 individual project, Maseno University, School of Computing and Informatics.
Kandie Joy Jepkorir (CIT/00039/022).

> MindQuest offers support and information. It does not diagnose or replace professional care.

## Tech stack (proposal Table 4)

| Layer | Technology |
|---|---|
| App (Android, iOS, web) | Flutter |
| Auth | Supabase Auth (guest, email, Google) |
| Database | Supabase PostgreSQL with Row Level Security |
| Backend logic | Supabase Edge Functions and database triggers |
| NLP | Rasa (English + Kiswahili), Dialogflow ES (English) |
| Notifications | flutter_local_notifications |
| Version control and CI | Git, GitHub, GitHub Actions |

## Project structure

```
lib/
  core/        config, router, theme
  features/    one folder per module (see lib/features/README.md)
test/          widget and unit tests
supabase/      migrations and Edge Functions
nlp/           Rasa project and Dialogflow export
docs/design/   wireframes, diagrams and workshop links
.github/       CI workflow
```

## Getting started

Requirements: Flutter (stable), Supabase CLI.

```bash
git clone https://github.com/Joykan/mindquest-app.git
cd mindquest-app
flutter create . --platforms=android,web --org ke.ac.maseno --project-name mindquest
flutter pub get
cp config/dev.json.example config/dev.json   # then add your Supabase URL and anon key
flutter run --dart-define-from-file=config/dev.json
```

`config/dev.json` is git-ignored so keys are never committed.

## Continuous integration

Every push to `main` and every pull request runs formatting checks, static analysis,
tests, a web build and a debug Android APK build. The APK is downloadable from the
workflow run's artifacts.

## Implementation progress

| Step | Status |
|---|---|
| 1. Wireframes (Figma) | Done |
| 2. Detailed models (Lucidchart, Draw.io, Miro) | Done |
| 3. Project setup (repo, Flutter, Supabase, CI) | In progress |
| 4. Database | |
| 5. NLP dataset | |
| 6. Rasa training and evaluation | |
| 7. Chat back end and crisis detection | |
| 8. Core screens: sign-in, chat, mood | |
| 9. Gamification, articles, rewards | |
| 10. Offline support and notifications | |
| 11. Admin dashboard | |
| 12. Testing and UAT | |
| 13. Documentation and presentation | |
