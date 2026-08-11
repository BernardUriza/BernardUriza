#!/usr/bin/env bash
# susurro-say.sh — TTS via the Susurro gateway, then play it on this machine.
#
#   printf '%s' "texto" | susurro-say.sh -
#   susurro-say.sh "texto"
#
# Prints, on success:
#   mp3=<path> bytes=<n> voice=<voice>
#   played_s=<seconds> duration_s=<seconds>
#
# The token is NEVER printed. Diagnostics report length and prefix only.

set -euo pipefail

GATEWAY="${SUSURRO_GATEWAY:-https://sus.bernarduriza.com}"
VOICE="${SUSURRO_VOICE:-onyx}"
FORMAT="${SUSURRO_FORMAT:-mp3}"

die() { printf 'susurro-say: %s\n' "$1" >&2; exit 1; }

read_text() {
  if [ "$#" -eq 0 ]; then
    die 'no text — pass a string or "-" to read stdin'
  elif [ "$1" = "-" ]; then
    cat
  else
    printf '%s' "$*"
  fi
}

resolve_token() {
  if [ -n "${SUSURRO_TOKEN:-}" ]; then printf '%s' "$SUSURRO_TOKEN"; return; fi
  local f
  for f in "$HOME/.secrets/susurro-token.txt" "$HOME/.secrets/susurro-gateway-key.txt"; do
    [ -f "$f" ] || continue
    local v
    v=$(grep -m1 -E '^SUSURRO_(TOKEN|KEY)=' "$f" 2>/dev/null | cut -d= -f2- | tr -d '\r\n' || true)
    if [ -n "$v" ]; then printf '%s' "$v"; return; fi
  done
  die "no token — set SUSURRO_TOKEN or add SUSURRO_TOKEN=/SUSURRO_KEY= to ~/.secrets/susurro-token.txt"
}

play() {
  local f="$1"
  if command -v afplay >/dev/null 2>&1; then afplay "$f"
  elif command -v ffplay >/dev/null 2>&1; then ffplay -nodisp -autoexit -loglevel error "$f"
  elif command -v mpg123 >/dev/null 2>&1; then mpg123 -q "$f"
  else return 127
  fi
}

TEXT=$(read_text "$@")
[ -n "${TEXT//[[:space:]]/}" ] || die 'empty text'

TOKEN=$(resolve_token)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/susurro.XXXXXX")
trap 'rm -f "$WORK/body.json"' EXIT
MP3="$WORK/say.$FORMAT"

# Body goes through a FILE, never inline -d: inline single quotes reach some
# shells literally and the gateway answers 400 "Body is not valid JSON".
# ensure_ascii keeps accents as \uXXXX so no codepage can corrupt the payload.
SUSURRO_TEXT="$TEXT" SUSURRO_VOICE_OUT="$VOICE" SUSURRO_FORMAT_OUT="$FORMAT" \
python3 - "$WORK/body.json" <<'PY'
import json, os, sys
open(sys.argv[1], "w").write(json.dumps({
    "input": os.environ["SUSURRO_TEXT"],
    "voice": os.environ["SUSURRO_VOICE_OUT"],
    "format": os.environ["SUSURRO_FORMAT_OUT"],
}, ensure_ascii=True))
PY

CODE=$(curl -sS -o "$MP3" -w '%{http_code}' -m 120 -X POST "$GATEWAY/v1/tts" \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d @"$WORK/body.json")

if [ "$CODE" = "429" ]; then
  die "429 rate limited — onboarding tier is 50 req/day. Mint a project key in /admin instead of retrying."
fi
[ "$CODE" = "200" ] || die "gateway returned HTTP $CODE — $(head -c 300 "$MP3" 2>/dev/null | tr -d '\0')"

BYTES=$(wc -c < "$MP3" | tr -d ' ')
[ "$BYTES" -gt 1024 ] || die "response too small (${BYTES}B) to be audio — $(head -c 300 "$MP3")"
case "$(head -c 3 "$MP3")" in
  ID3|$'\xff\xfb'*) : ;;
  *) file "$MP3" | grep -qiE 'audio|mpeg' || die "response is not audio: $(file -b "$MP3")" ;;
esac

DURATION=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$MP3" 2>/dev/null || echo '?')
printf 'mp3=%s bytes=%s voice=%s\n' "$MP3" "$BYTES" "$VOICE"

START=$(date +%s)
if play "$MP3"; then
  END=$(date +%s)
  printf 'played_s=%s duration_s=%s\n' "$((END - START))" "$DURATION"
else
  die "mp3 generated at $MP3 but no player found (afplay/ffplay/mpg123) — playback FAILED"
fi
