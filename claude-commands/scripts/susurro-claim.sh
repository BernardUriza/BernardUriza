#!/usr/bin/env bash
# susurro-claim.sh — redeem a Susurro claim code and store the minted token.
#
#   susurro-claim.sh claim-xxxxxxxx
#   susurro-claim.sh https://sus.bernarduriza.com/claim#claim-xxxxxxxx
#
# A claim code burns on first use. The previous secrets file is kept as .bak.
# The token is NEVER printed — only length and prefix.

set -euo pipefail

GATEWAY="${SUSURRO_GATEWAY:-https://sus.bernarduriza.com}"
STORE="$HOME/.secrets/susurro-token.txt"
NAME="${SUSURRO_CLAIM_NAME:-$(hostname -s)-claude}"

die() { printf 'susurro-claim: %s\n' "$1" >&2; exit 1; }

[ "$#" -ge 1 ] || die 'usage: susurro-claim.sh <claim-code|claim-url>'

RAW="$1"
CODE="${RAW##*#}"
CODE="${CODE##*/}"
case "$CODE" in
  claim-*) : ;;
  *) die "not a claim code: expected claim-xxxx, got '${CODE}'" ;;
esac

WORK=$(mktemp -d "${TMPDIR:-/tmp}/susurro-claim.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

SUSURRO_CODE="$CODE" SUSURRO_NAME="$NAME" python3 - "$WORK/body.json" <<'PY'
import json, os, sys
open(sys.argv[1], "w").write(json.dumps({
    "claim_code": os.environ["SUSURRO_CODE"],
    "name": os.environ["SUSURRO_NAME"],
}, ensure_ascii=True))
PY

HTTP=$(curl -sS -o "$WORK/resp.json" -w '%{http_code}' -m 60 -X POST "$GATEWAY/v1/claim" \
  -H 'Content-Type: application/json' -d @"$WORK/body.json")
[ "$HTTP" = "200" ] || die "gateway returned HTTP $HTTP — $(head -c 300 "$WORK/resp.json")"

TOKEN=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("token",""))' "$WORK/resp.json")
APP=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("name",""))' "$WORK/resp.json")
[ -n "$TOKEN" ] || die "response had no token — $(head -c 300 "$WORK/resp.json")"

mkdir -p "$HOME/.secrets"
[ -f "$STORE" ] && cp "$STORE" "$STORE.bak"
umask 077
{
  printf 'Created: %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')"
  printf 'Service: Susurro gateway token (minted via /v1/claim)\n'
  printf 'Name:    %s\n' "$APP"
  printf 'Endpoint: %s\n' "$GATEWAY"
  printf 'SUSURRO_TOKEN=%s\n' "$TOKEN"
} > "$STORE"
chmod 600 "$STORE"

printf 'stored=%s app=%s token_len=%s prefix=%s\n' \
  "$STORE" "$APP" "${#TOKEN}" "$(printf '%s' "$TOKEN" | cut -c1-11)"
