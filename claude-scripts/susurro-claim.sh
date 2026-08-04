#!/usr/bin/env bash
# susurro-claim.sh — redeem a one-time Susurro claim code and store the token.
#
# Bernard mints the code at https://sus.bernarduriza.com/admin (POST /admin/claims
# with {name, daily_limit}); this burns it and writes the resulting key to the
# secrets file. A claim code works exactly once.
#
# Usage: susurro-claim.sh <claim-code> [app-name]
# Exit codes: 0 ok · 2 usage · 4 gateway error · 6 write error
set -uo pipefail

GATEWAY="https://sus.bernarduriza.com"
TOKEN_FILE="${SUSURRO_TOKEN_FILE:-$HOME/.secrets/susurro-token.txt}"

CLAIM_CODE="${1-}"
APP_NAME="${2:-claude-code-$(hostname 2>/dev/null || echo windows)}"

if [ -z "$CLAIM_CODE" ]; then
  echo "usage: susurro-claim.sh <claim-code> [app-name]" >&2
  echo "  Bernard mints a code at $GATEWAY/admin — it may also arrive as $GATEWAY/claim#claim-xxxx" >&2
  exit 2
fi

# Accept a pasted URL: the UI puts the code in the fragment.
case "$CLAIM_CODE" in
  *"#"*) CLAIM_CODE="${CLAIM_CODE##*#}" ;;
esac
CLAIM_CODE="$(printf '%s' "$CLAIM_CODE" | tr -d '\r\n ')"

case "$CLAIM_CODE" in
  claim-*) : ;;
  *) echo "SUSURRO: '$CLAIM_CODE' does not look like a claim code (expected claim-...)" >&2; exit 2 ;;
esac

TMP_DIR="${TEMP:-/tmp}/susurro"
mkdir -p "$TMP_DIR" || { echo "SUSURRO: cannot create $TMP_DIR" >&2; exit 6; }
BODY="$TMP_DIR/claim-body.json"
RESP="$TMP_DIR/claim-resp.json"

BODY_PATH="$BODY" CLAIM_CODE="$CLAIM_CODE" APP_NAME="$APP_NAME" python -c '
import json, os
payload = {"claim_code": os.environ["CLAIM_CODE"], "name": os.environ["APP_NAME"]}
with open(os.environ["BODY_PATH"], "w", encoding="ascii") as fh:
    fh.write(json.dumps(payload, ensure_ascii=True))
' || { echo "SUSURRO: failed to build claim body" >&2; exit 6; }

CODE="$(curl -s -m 60 -o "$RESP" -w '%{http_code}' -X POST "$GATEWAY/v1/claim" \
  -H 'Content-Type: application/json' -d @"$BODY")"
rm -f "$BODY"

if [ "$CODE" != "200" ]; then
  echo "SUSURRO: claim failed (HTTP $CODE)" >&2
  head -c 400 "$RESP" >&2; echo >&2
  rm -f "$RESP"
  exit 4
fi

# Write the token WITHOUT ever printing it. Old file is backed up first.
TOKEN_FILE="$TOKEN_FILE" RESP="$RESP" GATEWAY="$GATEWAY" python -c '
import json, os, shutil, datetime, sys

resp_path  = os.environ["RESP"]
token_file = os.path.expanduser(os.environ["TOKEN_FILE"])
gateway    = os.environ["GATEWAY"]

with open(resp_path, "r", encoding="utf-8") as fh:
    data = json.load(fh)

token = (data.get("token") or "").strip()
name  = data.get("name") or "unknown"
if not token.startswith("sk-susurro-"):
    sys.stderr.write("SUSURRO: response carried no usable token\n")
    sys.exit(4)

os.makedirs(os.path.dirname(token_file), exist_ok=True)
if os.path.exists(token_file):
    shutil.copyfile(token_file, token_file + ".bak")

today = datetime.date.today().isoformat()
body = (
    "Susurro Voice Gateway token (sus.bernarduriza.com)\n"
    "Created: {today}\n"
    "App identifier: {name}\n"
    "Usage: Authorization: Bearer <token> against {gateway}/v1/tts\n"
    "Mint or revoke at {gateway}/admin — this claim code is now burned.\n"
    "\n"
    "SUSURRO_TOKEN={token}\n"
).format(today=today, name=name, gateway=gateway, token=token)

with open(token_file, "w", encoding="utf-8", newline="\n") as fh:
    fh.write(body)

print("stored=%s app=%s token_len=%d prefix=%s" % (token_file, name, len(token), token[:11]))
'
STATUS=$?
rm -f "$RESP"
[ "$STATUS" -eq 0 ] || exit "$STATUS"
