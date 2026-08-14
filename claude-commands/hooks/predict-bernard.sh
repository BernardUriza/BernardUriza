#!/bin/bash
# UserPromptSubmit hook — inject THE CONSTITUTION (9 articles, sourced live from the
# charter so they never drift) + the predict-Bernard ritual every turn, PLUS a
# conditional relational-frame guard (see below).
#
# Advisory only and BULLETPROOF: it ALWAYS emits valid JSON and ALWAYS exits 0. A
# per-turn hook that runs on every repo must NEVER go noisy — that is the exact pain
# it exists to prevent (2026-06-13). python enriches with the full charter; if python
# is missing/off-PATH/crashes, the pure-bash `cat` floor still emits the ritual.
#
# Why per-turn: loaded rules decay after ~10 messages (the session gaslit Bernard WITH
# the rules loaded). Re-injecting the charter every turn keeps the inhibitory checks
# (verify, no fake-green, real-contract, act-don't-ask) alive deep into a long session.
#
# RELATIONAL-FRAME GUARD (2026-08-14): when Bernard asserts what another person feels
# about him from a SILENCE ("me dio la espalda", "le vale", "me deja en visto"), the
# hook appends an order to re-read the real thread BEFORE accepting/consoling/drafting
# a cutoff. Doctrina: SerenityOps/.claude/rules/tlp-como-trabajar-con-bernard.md §1.1.
CONSTITUTION="$HOME/Documents/engineering-playbook/rules/00-constitution.md"

# Capture the event payload without disturbing the heredoc that feeds python.
HOOK_STDIN="$(cat 2>/dev/null)"

out="$(HOOK_STDIN="$HOOK_STDIN" python3 - "$CONSTITUTION" 2>/dev/null <<'PY'
import json, os, re, sys

path = sys.argv[1]
articles = []
try:
    with open(path, encoding="utf-8") as f:
        for line in f:
            if line.startswith("## Art."):
                articles.append(line[3:].strip())  # strip leading "## "
except Exception:
    pass

ritual = (
    "PREDICT-BERNARD RITUAL. Before deciding, state explicitly what Bernard would "
    "choose and why. He esmera — root fix, never the pretty patch; he acts, he does "
    "not ask; he runs to the canonical/framework, not the low-friction shortcut. If "
    "you are about to (a) propose a dilemma or list options instead of deciding, (b) "
    "take the least-friction / shortest path, or (c) default to a generic-assistant "
    "prior over his documented model — STOP. That IS the failure. Re-decide from HIS "
    "model."
)

# --- relational-frame detection -------------------------------------------------
def user_prompt():
    raw = os.environ.get("HOOK_STDIN") or ""
    try:
        return str(json.loads(raw).get("prompt") or "")
    except Exception:
        return raw  # malformed/no JSON: scan the raw text rather than go blind

def deaccent(s):
    table = str.maketrans("áéíóúüñÁÉÍÓÚÜÑ", "aeiouunAEIOUUN")
    return s.translate(table).lower()

# NOTE: input is de-accented+lowercased before matching, so write patterns plain.
# "la espalda" is matched through ANY conjugation of dar (da/dio/diera/dieron/
# dando/dandome). d[aeio]\w* deliberately excludes "duele"/"dolor de espalda".
TELLS = [
    r"\bd[aeio]\w*\s+la\s+espalda\b",
    r"\bl[eo]s? vale\b", r"\bno le[s]? importa\b", r"\bya no le importo\b",
    r"\bme deja(ron)? en visto\b", r"\bme dejo en visto\b", r"\bdejar(me)? en visto\b",
    r"\bno me (ha )?contest[ao]\b", r"\bni me contesta\b", r"\bme ignora\b",
    r"\bme abandon[oa]\b", r"\bme abandonaron\b", r"\bse olvid[oa] de mi\b",
    r"\bdespedir(me)? (de|mi amistad)\b", r"\bme voy a despedir\b",
    r"\bya no somos amig", r"\bcortar (la )?amistad\b",
    r"\bsabe que la paso mal\b", r"\bno hace nada\b",
    r"\bse dec[ai]an?\s+m[ii]s?\s+amig",   # "la gente que se decia mi amiga"
    r"\bya no me habla\b", r"\bme dej[oa] de hablar\b",
]

GUARD = (
    "⚠️ FRAME RELACIONAL DETECTADO — Bernard acaba de afirmar lo que OTRA persona "
    "siente por él, infiriéndolo de un SILENCIO. NO lo aceptes, NO lo consueles y "
    "NO redactes ningún corte/despedida hasta RELEER EL HILO REAL en este mismo "
    "tick: WhatsApp Web, o Instagram por /api/v1/direct_v2/inbox/ + /threads/<id>/ "
    "(no marca visto; last_seen_at prueba si lo leyó). Es "
    "[[verify-before-assuming]] Rule 18 INVERTIDA: allá relees antes de MANDAR, "
    "aquí relees antes de CREER. Historial: el 2026-08-14 este frame falló DOS "
    "veces en UNA sesión — \"Alfonso me dio la espalda\" (le había contestado a las "
    "10:33 AM y Bernard mismo le concedió el tiempo a las 10:36) y \"Diego me deja "
    "en visto, le vale\" (45 min de silencio tras 10 h de conversación; contestó "
    "con ❤️ media hora después). En ambos el impulso fue despedirse formalmente y "
    "en ambos la evidencia estaba a un fetch de distancia. Ventana de 24 h para "
    "toda decisión relacional irreversible; tú eres el circuit breaker. Y el "
    "segundo filo: explicar no absuelve — nunca le quites la autoría diciéndole "
    "\"fue el TLP\". Doctrina completa: "
    "SerenityOps/.claude/rules/tlp-como-trabajar-con-bernard.md §1.1."
)

body = ritual
if articles:
    body = (
        "THE CONSTITUTION — apex charter, decide from THIS every turn (full text: "
        "engineering-playbook/rules/00-constitution.md; when a specific rule and an "
        "article conflict, the article wins):\n- "
        + "\n- ".join(articles)
        + "\n\n"
        + ritual
    )

try:
    prompt = deaccent(user_prompt())
    if any(re.search(p, prompt) for p in TELLS):
        body = body + "\n\n" + GUARD
except Exception:
    pass  # detection is a bonus; never let it cost the charter injection

print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "UserPromptSubmit",
        "additionalContext": body,
    }
}))
PY
)"

if [ -n "$out" ]; then
  printf '%s\n' "$out"
else
  # Pure-bash floor — no python, no file read. Static ritual JSON via heredoc handles
  # the em-dashes/quotes literally. Guarantees the hook never errors or blocks.
  cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"PREDICT-BERNARD RITUAL. Before deciding, state explicitly what Bernard would choose and why. He esmera — root fix, never the pretty patch; he acts, he does not ask; he runs to the canonical/framework, not the low-friction shortcut. If you are about to (a) propose a dilemma instead of deciding, (b) take the least-friction path, or (c) default to a generic-assistant prior over his model — STOP. That IS the failure."}}
JSON
fi
exit 0
