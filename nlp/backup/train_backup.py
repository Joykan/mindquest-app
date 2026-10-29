"""Backup NLU model for when the Rasa server can't be reached.

Trains a small linear classifier (logistic regression on hashed word and
character n-grams) from the same training data as Rasa (nlp/rasa/data/nlu.yml)
and writes it as a TypeScript module the chat Edge Function imports:
supabase/functions/chat/backup_model.ts.

The features are computed exactly as in supabase/functions/chat/backup_nlu.ts
(same text clean-up, same n-grams, same FNV-1a hash), so the function gives
the same answers as this script.

Run from the project folder:
    python nlp/backup/train_backup.py            train, test and write the model
    python nlp/backup/train_backup.py --eval     only print the test results
Needs: pip install scikit-learn pyyaml numpy
"""

import base64
import json
import re
import sys
import unicodedata
from pathlib import Path

import numpy as np
import yaml
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, f1_score
from sklearn.model_selection import StratifiedKFold

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / 'nlp/rasa/data/nlu.yml'
TESTS = {'test_nlu (48)': ROOT / 'nlp/rasa/tests/test_nlu.yml',
         'test_names (12)': ROOT / 'nlp/rasa/tests/test_names.yml'}
OUT = ROOT / 'supabase/functions/chat/backup_model.ts'

DIM = 2048          # hash buckets (small, so the model is only ~35 KB)
C = 32.0            # inverse regularisation strength (chosen by cross-validation)
SEED = 42


def load(path):
    """(text, intent) pairs; entity markup like [Joy](name) becomes Joy."""
    doc = yaml.safe_load(path.read_text(encoding='utf-8'))
    pairs = []
    for block in doc['nlu']:
        if 'intent' not in block:
            continue
        for line in block['examples'].splitlines():
            line = line.strip()
            if not line.startswith('- '):
                continue
            text = re.sub(r'\[([^\]]+)\]\([^)]+\)', r'\1', line[2:])
            pairs.append((text, block['intent']))
    return pairs


def clean(text):
    """Lower case, letters and digits only, single spaces (as in backup_nlu.ts)."""
    t = unicodedata.normalize('NFC', text.lower())
    t = re.sub(r"['’`]", '', t)
    t = re.sub(r'[^\w]+|_', ' ', t)
    return ' '.join(t.split())


def features(text):
    words = clean(text).split()
    out = []
    for w in words:
        out.append('w:' + w)
        padded = '<' + w + '>'
        for n in (3, 4, 5):
            for i in range(len(padded) - n + 1):
                out.append('c:' + padded[i:i + n])
    for a, b in zip(words, words[1:]):
        out.append('b:' + a + ' ' + b)
    return out


def fnv1a(s):
    h = 0x811C9DC5
    for byte in s.encode('utf-8'):
        h ^= byte
        h = (h * 0x01000193) & 0xFFFFFFFF
    return h


def vector(text):
    v = np.zeros(DIM, dtype=np.float64)
    for f in set(features(text)):
        v[fnv1a(f) % DIM] = 1.0
    n = np.linalg.norm(v)
    return v / n if n else v


def matrix(texts):
    return np.vstack([vector(t) for t in texts])


def train(pairs):
    texts, labels = zip(*pairs)
    model = LogisticRegression(C=C, max_iter=5000, random_state=SEED)
    model.fit(matrix(texts), labels)
    return model


def score(model, pairs):
    texts, labels = zip(*pairs)
    pred = model.predict(matrix(texts))
    return accuracy_score(labels, pred), f1_score(labels, pred, average='macro'), pred


def main():
    data = load(DATA)
    print(f'{len(data)} training phrases, {len({i for _, i in data})} intents')

    # 5-fold cross-validation on the training data (as for Rasa).
    texts = np.array([t for t, _ in data], dtype=object)
    labels = np.array([i for _, i in data])
    accs, f1s = [], []
    for tr, te in StratifiedKFold(5, shuffle=True, random_state=SEED).split(texts, labels):
        m = train(list(zip(texts[tr], labels[tr])))
        a, f, _ = score(m, list(zip(texts[te], labels[te])))
        accs.append(a)
        f1s.append(f)
    print(f'5-fold cross-validation: accuracy {np.mean(accs):.1%}, macro F1 {np.mean(f1s):.2f}')

    model = train(data)
    for name, path in TESTS.items():
        pairs = load(path)
        a, f, pred = score(model, pairs)
        print(f'{name}: accuracy {a:.1%}, macro F1 {f:.2f}')
        for (t, gold), p in zip(pairs, pred):
            if gold != p:
                print(f'    "{t}": {gold} read as {p}')

    if '--eval' in sys.argv:
        return

    # Write the model for the Edge Function. The weights are stored as
    # 8-bit numbers (one scale for all), which changes no prediction on the
    # test sets (checked below), as base64 text.
    intents = list(model.classes_)
    scale = float(np.abs(model.coef_).max()) / 127
    q = np.clip(np.round(model.coef_ / scale), -127, 127).astype(np.int8)
    b = np.round(model.intercept_, 4)
    for name, path in TESTS.items():
        x = matrix([t for t, _ in load(path)])
        assert (np.array(intents)[(x @ (q * scale).T + b).argmax(1)] == model.predict(x)).all()
    body = {
        'dim': DIM,
        'intents': intents,
        'bias': b.tolist(),
        'scale': scale,
        # intents x dim signed bytes, row by row.
        'weights': base64.b64encode(q.tobytes()).decode('ascii'),
    }
    OUT.write_text(
        '// Generated by nlp/backup/train_backup.py from nlp/rasa/data/nlu.yml.\n'
        '// Do not edit by hand: change the training data and run the script again.\n'
        '// deno-fmt-ignore-file\n'
        'export const BACKUP_MODEL: {\n'
        '  dim: number; intents: string[]; bias: number[]; scale: number; weights: string;\n'
        '} = ' + json.dumps(body) + ';\n',
        encoding='utf-8')
    print(f'Wrote {OUT.relative_to(ROOT)} ({OUT.stat().st_size // 1024} KB)')

    # Examples for the TypeScript test (backup_nlu_test.ts): the same phrases
    # must get the same intent there.
    sample = [t for path in TESTS.values() for t, _ in load(path)]
    x = matrix(sample)
    z = x @ (q * scale).T + b
    probs = np.exp(z - z.max(1, keepdims=True))
    probs /= probs.sum(1, keepdims=True)
    expected = [{'text': t, 'intent': intents[int(p.argmax())], 'confidence': round(float(p.max()), 2)}
                for t, p in zip(sample, probs)]
    (ROOT / 'supabase/functions/chat/backup_expected.json').write_text(
        json.dumps(expected, ensure_ascii=False, indent=1) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
