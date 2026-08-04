#!/usr/bin/env bash
# susurro-say.sh — turn text into speech via the Susurro gateway and play it on this box.
#
# Usage:
#   susurro-say.sh "texto a decir"
#   echo "texto largo" | susurro-say.sh -
#   susurro-say.sh --no-play "solo genera el mp3"
#
# Env overrides:
#   SUSURRO_TOKEN_FILE  (default ~/.secrets/susurro-token.txt)
#   SUSURRO_VOICE       (default onyx)
#   SUSURRO_OUT_DIR     (default $TEMP/susurro)
#
# Exit codes: 0 ok · 2 usage · 3 token problem · 4 gateway error · 5 playback error
set -uo pipefail

GATEWAY="https://sus.bernarduriza.com"
TOKEN_FILE="${SUSURRO_TOKEN_FILE:-$HOME/.secrets/susurro-token.txt}"
VOICE="${SUSURRO_VOICE:-onyx}"
OUT_DIR="${SUSURRO_OUT_DIR:-${TEMP:-/tmp}/susurro}"
PLAY=1

while [ $# -gt 0 ]; do
  case "$1" in
    --no-play) PLAY=0; shift ;;
    --voice)   VOICE="$2"; shift 2 ;;
    --) shift; break ;;
    *) break ;;
  esac
done

TEXT="${1-}"
if [ "$TEXT" = "-" ] || [ -z "$TEXT" ]; then
  TEXT="$(cat)"
fi
if [ -z "${TEXT//[[:space:]]/}" ]; then
  echo "usage: susurro-say.sh [--no-play] [--voice <name>] <text|->" >&2
  exit 2
fi

# --- token -------------------------------------------------------------------
# The secrets file carries prose + a URL; only the value after SUSURRO_TOKEN= /
# SUSURRO_KEY= is the key. Never echo it.
if [ ! -f "$TOKEN_FILE" ]; then
  echo "SUSURRO: no token file at $TOKEN_FILE — run /susurramelo claim <claim-code>" >&2
  exit 3
fi
TOKEN="$(grep -oE '^SUSURRO_(TOKEN|KEY)=.*' "$TOKEN_FILE" | head -1 | cut -d= -f2- | tr -d '\r\n ')"
case "$TOKEN" in
  sk-susurro-*) : ;;
  *) echo "SUSURRO: token in $TOKEN_FILE is missing or malformed (must start with sk-susurro-)" >&2; exit 3 ;;
esac

# --- body --------------------------------------------------------------------
# Two Windows traps this avoids, both verified 2026-08-04:
#  1. Inline -d '{"input":"..."}' reaches the gateway with the single quotes
#     intact -> HTTP 400 "Body is not valid JSON". Always POST a file (-d @).
#  2. Accents die on cp1252 stdout. json.dumps(ensure_ascii=True) escapes them
#     to \uXXXX so the payload is pure ASCII and survives any codepage.
mkdir -p "$OUT_DIR" || { echo "SUSURRO: cannot create $OUT_DIR" >&2; exit 4; }
STAMP="$(date +%Y%m%d-%H%M%S)"
BODY="$OUT_DIR/body-$STAMP.json"
MP3="$OUT_DIR/say-$STAMP.mp3"

# NOTE: export, not an inline prefix — in `A=1 printf ... | python`, the
# assignment binds to printf and python never sees it.
export BODY_PATH="$BODY" VOICE
printf '%s' "$TEXT" | python -c '
import json, os, sys
text = sys.stdin.buffer.read().decode("utf-8", "replace")
payload = {"input": text, "voice": os.environ["VOICE"], "format": "mp3"}
with open(os.environ["BODY_PATH"], "w", encoding="ascii") as fh:
    fh.write(json.dumps(payload, ensure_ascii=True))
' || { echo "SUSURRO: failed to build request body" >&2; exit 4; }

# --- call --------------------------------------------------------------------
CODE="$(curl -s -m 120 -o "$MP3" -w '%{http_code}' -X POST "$GATEWAY/v1/tts" \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d @"$BODY")"

rm -f "$BODY"

if [ "$CODE" != "200" ]; then
  echo "SUSURRO: gateway returned HTTP $CODE" >&2
  head -c 400 "$MP3" >&2; echo >&2
  case "$CODE" in
    401|403) echo "SUSURRO: token rejected — mint a new one at $GATEWAY/admin, then /susurramelo claim <code>" >&2 ;;
    429)     echo "SUSURRO: rate limited (onboarding tier = 50 req/day). Bernard can mint an unlimited project key at $GATEWAY/admin" >&2 ;;
  esac
  rm -f "$MP3"
  exit 4
fi

# An MPEG frame starts with 0xFF 0xFB/0xF3/0xF2, an ID3 tag with "ID3".
MAGIC="$(head -c 3 "$MP3" | od -An -tx1 | tr -d ' \n')"
BYTES="$(wc -c < "$MP3" | tr -d ' ')"
case "$MAGIC" in
  fff*|494433) : ;;
  *) echo "SUSURRO: HTTP 200 but body is not mp3 (magic=$MAGIC, ${BYTES}B)" >&2; exit 4 ;;
esac

echo "mp3=$MP3 bytes=$BYTES voice=$VOICE"

# --- play --------------------------------------------------------------------
if [ "$PLAY" = "1" ]; then
  PS1_PATH="$HOME/.claude/scripts/susurro-play.ps1"
  if [ ! -f "$PS1_PATH" ]; then
    echo "SUSURRO: playback script missing at $PS1_PATH (mp3 kept)" >&2
    exit 5
  fi
  WIN_MP3="$(cygpath -w "$MP3" 2>/dev/null || echo "$MP3")"
  WIN_PS1="$(cygpath -w "$PS1_PATH" 2>/dev/null || echo "$PS1_PATH")"
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$WIN_PS1" -Path "$WIN_MP3" || {
    echo "SUSURRO: playback failed (mp3 kept at $MP3)" >&2
    exit 5
  }
fi
