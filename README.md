# MindQuest

[![CI](https://github.com/Joykan/mindquest-app/actions/workflows/ci.yml/badge.svg)](https://github.com/Joykan/mindquest-app/actions/workflows/ci.yml)

MindQuest is a mobile chatbot that helps young people in Kenya check in on their mental
wellbeing. It chats in English and Kiswahili, lets you log your mood, and uses streaks,
XP and badges to make small healthy habits stick.

This is my final-year project for CIT 409 at Maseno University (BSc Information Technology).

Kandie Joy Jepkorir · CIT/00039/022

**Note:** MindQuest gives support and information only. It is not a diagnosis tool and does
not replace a counsellor or doctor.

## Built with

- Flutter for the app (Android and web for now)
- Supabase for login, the database and server functions
- Rasa for understanding messages in English and Kiswahili, with Dialogflow for comparison
- GitHub Actions to build and test every push

## Folder layout

```
lib/core/        app config, routes and theme
lib/features/    one folder per part of the app (chat, mood, learn, ...)
test/            tests
supabase/        database migrations and server functions
nlp/             chatbot training data
docs/design/     links to wireframes and diagrams
```

## Running it locally

You need Flutter (stable channel).

```bash
git clone https://github.com/Joykan/mindquest-app.git
cd mindquest-app
flutter create . --platforms=android,web --org ke.ac.maseno --project-name mindquest
flutter pub get
cp config/dev.json.example config/dev.json
flutter run --dart-define-from-file=config/dev.json
```

Put the Supabase URL and publishable key in `config/dev.json`. That file is in
`.gitignore`, so keys don't end up on GitHub.

## Progress

- [x] Wireframes
- [x] Architecture, conversation flow and gamification design
- [x] Project setup
- [x] Database
- [x] Chatbot training data
- [x] Rasa model training and evaluation (with Dialogflow comparison)
- [x] Chat backend and crisis detection
- [ ] Login, chat and mood screens
- [ ] Rewards and learning articles
- [ ] Offline mode and reminders
- [ ] Admin dashboard
- [ ] Testing with users
- [ ] Final report and presentation
