"""Send the held-out test phrases to the Dialogflow agent and score the answers.

The test phrases are the same ones used for Rasa (test_nlu.yml and
test_names.yml). Reports are written in the same layout as `rasa test nlu`
(intent_report.json, intent_errors.json), plus name_report.json for names.

    python evaluate.py --project YOUR_PROJECT_ID
    python evaluate.py --project YOUR_PROJECT_ID --all-en   # send everything as English
"""
import argparse
import json
import re
import time
import uuid
from collections import Counter, defaultdict
from pathlib import Path

from google.cloud import dialogflow as df

HERE = Path(__file__).parent
ENTITY = re.compile(r"\[([^\]]+)\]\((\w+)\)")


def intent_report(rows):
    labels = sorted({r["intent"] for r in rows})
    tp, pred_count, confused = Counter(), Counter(), defaultdict(Counter)
    for r in rows:
        pred_count[r["predicted"]] += 1
        if r["predicted"] == r["intent"]:
            tp[r["intent"]] += 1
        else:
            confused[r["intent"]][r["predicted"]] += 1
    support = Counter(r["intent"] for r in rows)
    report = {}
    for lab in labels:
        p = tp[lab] / pred_count[lab] if pred_count[lab] else 0.0
        rc = tp[lab] / support[lab]
        f1 = 2 * p * rc / (p + rc) if p + rc else 0.0
        report[lab] = {"precision": p, "recall": rc, "f1-score": f1, "support": support[lab],
                       "confused_with": dict(confused[lab].most_common(2))}
    n = len(rows)
    report["accuracy"] = sum(tp.values()) / n
    for key, weight in (("macro avg", lambda lab: 1 / len(labels)),
                        ("weighted avg", lambda lab: support[lab] / n)):
        report[key] = {m: sum(report[lab][m] * weight(lab) for lab in labels)
                       for m in ("precision", "recall", "f1-score")}
        report[key]["support"] = n
    return report


def name_report(rows):
    expected = [r for r in rows if r["expected_name"]]
    found = [r for r in rows if r["predicted_name"]]
    correct = [r for r in expected
               if r["predicted_name"].strip().lower() == r["expected_name"].lower()]
    p = len(correct) / len(found) if found else 0.0
    rc = len(correct) / len(expected) if expected else 0.0
    return {"name": {"precision": p, "recall": rc,
                     "f1-score": 2 * p * rc / (p + rc) if p + rc else 0.0,
                     "support": len(expected)}}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--project", required=True)
    ap.add_argument("--all-en", action="store_true",
                    help="send every phrase as English instead of its own language")
    args = ap.parse_args()

    tests = json.loads((HERE / "test_phrases.json").read_text(encoding="utf-8"))
    sessions = df.SessionsClient()
    suffix = "_all_en" if args.all_en else ""

    for set_name in ("test_nlu", "test_names"):
        rows = []
        for t in (x for x in tests if x["set"] == set_name):
            m = ENTITY.search(t["text"])
            text = ENTITY.sub(r"\1", t["text"])
            session = sessions.session_path(args.project, uuid.uuid4().hex)  # fresh session each time
            lang = "en" if args.all_en else t["lang"]
            res = sessions.detect_intent(request={
                "session": session,
                "query_input": {"text": {"text": text, "language_code": lang}},
            }).query_result
            intent = res.intent.display_name
            if not intent or res.intent.is_fallback:
                intent = "nlu_fallback"
            params = dict(res.parameters) if res.parameters else {}
            rows.append({"text": text, "lang": t["lang"], "intent": t["intent"], "predicted": intent,
                         "confidence": round(res.intent_detection_confidence, 3),
                         "expected_name": m.group(1) if m else "",
                         "predicted_name": str(params.get("name") or "")})
            time.sleep(0.2)

        out = HERE / "results" / f"{set_name}{suffix}"
        out.mkdir(parents=True, exist_ok=True)
        rep = intent_report(rows)
        (out / "intent_report.json").write_text(json.dumps(rep, indent=2))
        (out / "intent_errors.json").write_text(json.dumps(
            [r for r in rows if r["predicted"] != r["intent"]], indent=2, ensure_ascii=False))
        (out / "all_predictions.json").write_text(json.dumps(rows, indent=2, ensure_ascii=False))
        if any(r["expected_name"] for r in rows):
            (out / "name_report.json").write_text(json.dumps(name_report(rows), indent=2))
        print(f"{set_name}{suffix}: accuracy {rep['accuracy']:.1%}, "
              f"macro F1 {rep['macro avg']['f1-score']:.2f}  ->  {out}")


if __name__ == "__main__":
    main()
