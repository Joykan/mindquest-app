# Dialogflow comparison

The proposal compares Rasa with Dialogflow ES. To keep it fair, Dialogflow gets
exactly what Rasa got:

- the same 569 training phrases (`training_phrases.json`, exported from `rasa/data/nlu.yml`)
- the same 44 + 12 test phrases (`test_phrases.json`, from `rasa/tests/`)
- the same 0.5 confidence cut-off as the Rasa fallback
- names marked the same way, using Dialogflow's `@sys.any` entity

Dialogflow supports Kiswahili for text chat only, which is all MindQuest needs.
It has to be told which language each message is in. The app knows this from
the user's language setting. Rasa uses one model for both languages and is
never told the language.

## Setup (once)

1. Go to https://dialogflow.cloud.google.com and sign in with your Google account.
2. Create agent: name `MindQuest`, default language English, time zone
   Africa/Nairobi, and let it create a new Google project.
3. Open the agent settings (gear icon) > Languages > add Swahili > Save.
4. Note the Project ID shown on the General tab of the settings.
5. In https://console.cloud.google.com, with that project selected:
   IAM & Admin > Service Accounts > Create service account (`mindquest-eval`),
   role **Dialogflow API Admin**. Open it > Keys > Add key > JSON.
   Save the file outside the repo, e.g. `C:\Users\Joy\keys\mindquest-dialogflow-key.json`.
   Never commit it.

## Run

In a separate venv (not the Rasa one, so their packages don't clash):

```powershell
cd nlp\dialogflow
py -3.10 -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\Users\Joy\keys\mindquest-dialogflow-key.json"

python build_agent.py --project YOUR_PROJECT_ID
python evaluate.py --project YOUR_PROJECT_ID
python evaluate.py --project YOUR_PROJECT_ID --all-en
```

`build_agent.py` creates the 12 intents with English and Kiswahili phrases,
removes the built-in "Default Welcome Intent" (it would compete with greet), and
trains the agent. Running it again replaces the intents.

`evaluate.py` sends every test phrase in a fresh session and writes reports to
`results/`, in the same layout as Rasa's. The `--all-en` run sends the
Kiswahili phrases as English too, to see what happens if the language is wrong
or unknown (for example with mixed English/Kiswahili messages).

Dialogflow has no built-in cross-validation, so the two tools are compared on
the two test files only.
