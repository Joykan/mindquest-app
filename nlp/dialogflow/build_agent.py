"""Load the MindQuest training phrases into a Dialogflow ES agent.

Uses the same 569 phrases as the Rasa model (training_phrases.json), so the two
can be compared fairly. Run evaluate.py afterwards.

    python build_agent.py --project YOUR_PROJECT_ID
"""
import argparse
import json
import re
import sys
import time
from pathlib import Path

from google.api_core.exceptions import GoogleAPICallError
from google.cloud import dialogflow as df

HERE = Path(__file__).parent
ENTITY = re.compile(r"\[([^\]]+)\]\((\w+)\)")  # e.g. [Joy](name)
Part = df.Intent.TrainingPhrase.Part


def to_parts(text):
    """Split 'naitwa [Furaha](name)' into plain text and an annotated name."""
    parts, pos = [], 0
    for m in ENTITY.finditer(text):
        if m.start() > pos:
            parts.append(Part(text=text[pos:m.start()]))
        parts.append(Part(text=m.group(1), entity_type="@sys.any",
                          alias=m.group(2), user_defined=True))
        pos = m.end()
    if pos < len(text):
        parts.append(Part(text=text[pos:]))
    return parts


def to_phrases(rows):
    return [df.Intent.TrainingPhrase(type_=df.Intent.TrainingPhrase.Type.EXAMPLE,
                                     parts=to_parts(r["text"])) for r in rows]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--project", required=True, help="Google Cloud project ID of the agent")
    args = ap.parse_args()
    parent = f"projects/{args.project}"
    agent_path = f"{parent}/agent"

    agents = df.AgentsClient()
    agent = agents.get_agent(parent=parent)
    if "sw" not in agent.supported_language_codes:
        sys.exit("Add Swahili to the agent first: settings (gear icon) > Languages > Swahili > Save.")

    # Same cut-off as the Rasa FallbackClassifier, and machine learning only
    # (no exact-match rules), so both tools are judged the same way.
    agent.classification_threshold = 0.5
    agent.match_mode = df.Agent.MatchMode.MATCH_MODE_ML_ONLY
    try:
        agents.set_agent(request={"agent": agent})
    except GoogleAPICallError:
        agent.match_mode = df.Agent.MatchMode.MATCH_MODE_UNSPECIFIED
        agents.set_agent(request={"agent": agent})
        print("Note: match mode could not be changed; threshold set to 0.5.")

    rows = json.loads((HERE / "training_phrases.json").read_text(encoding="utf-8"))
    names = sorted({r["intent"] for r in rows})
    intents = df.IntentsClient()

    existing = list(intents.list_intents(request={"parent": agent_path}))
    defaults = {"Default Welcome Intent", "Default Fallback Intent"}
    others = [it.display_name for it in existing
              if it.display_name not in names and it.display_name not in defaults]
    if others:
        sys.exit("This agent already has other intents (" + ", ".join(sorted(others)) + ").\n"
                 "They would compete with the MindQuest intents and spoil the comparison.\n"
                 "Use a new, empty agent for this test.")

    # Remove intents from an earlier run, and the built-in welcome intent,
    # which would compete with greet ("hi", "hello"). The fallback intent stays.
    for it in existing:
        if it.display_name in names or it.display_name == "Default Welcome Intent":
            intents.delete_intent(name=it.name)
            print("removed", it.display_name)
            time.sleep(0.5)

    for name in names:
        en = [r for r in rows if r["intent"] == name and r["lang"] == "en"]
        sw = [r for r in rows if r["intent"] == name and r["lang"] == "sw"]
        params = []
        if any(ENTITY.search(r["text"]) for r in en + sw):
            params = [df.Intent.Parameter(display_name="name", value="$name",
                                          entity_type_display_name="@sys.any")]
        created = intents.create_intent(request={
            "parent": agent_path, "language_code": "en",
            "intent": df.Intent(display_name=name, training_phrases=to_phrases(en), parameters=params),
        })
        created.training_phrases = to_phrases(sw)
        intents.update_intent(request={
            "intent": created, "language_code": "sw",
            "update_mask": {"paths": ["training_phrases"]},
        })
        print(f"{name:15} {len(en)} EN + {len(sw)} SW")
        time.sleep(1)

    print("Training the agent (a minute or two)...")
    agents.train_agent(request={"parent": parent}).result(timeout=900)
    print("Done. Now run: python evaluate.py --project", args.project)


if __name__ == "__main__":
    main()
