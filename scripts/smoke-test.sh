#!/usr/bin/env bash
# Prove the render pipeline works, end to end, without touching ElevenLabs.
#
# Generates a synthetic clip, analyzes it, and renders a graded copy — the same
# ffmpeg + Python path a real edit uses. Costs nothing and needs no API key, so
# it isolates "is my toolchain broken?" from "is my key wrong?".
#
#   ./scripts/smoke-test.sh
#
# Transcription is deliberately NOT exercised here: Scribe bills per minute.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPERS="$REPO_ROOT/.claude/skills/video-use/helpers"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

ok()  { printf '  \033[32m✓\033[0m %s\n' "$1"; }
err() { printf '  \033[31m✗\033[0m %s\n' "$1"; }

printf '\n\033[1mSmoke test — render pipeline\033[0m\n'
FAIL=0

# 1. ffmpeg can encode -----------------------------------------------------
if ffmpeg -f lavfi -i testsrc=duration=3:size=640x360:rate=25 \
          -f lavfi -i sine=frequency=440:duration=3 \
          -c:v libx264 -c:a aac -pix_fmt yuv420p "$WORK/clip.mp4" -y \
          >/dev/null 2>&1 && [ -s "$WORK/clip.mp4" ]; then
  ok "ffmpeg encoded a 3s test clip (video + audio)"
else
  err "ffmpeg could not encode — run ./scripts/setup.sh"; exit 1
fi

# 2. ffprobe can read ------------------------------------------------------
DUR="$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$WORK/clip.mp4" 2>/dev/null)"
if [ -n "$DUR" ]; then ok "ffprobe read it back (${DUR}s)"; else err "ffprobe failed"; FAIL=1; fi

# 3. Python helpers import (proves numpy/librosa/PIL/matplotlib resolve) ---
BROKEN=""
for h in timeline_view render grade pack_transcripts transcribe; do
  python3 "$HELPERS/$h.py" --help >/dev/null 2>&1 || BROKEN="$BROKEN $h"
done
if [ -z "$BROKEN" ]; then
  ok "all 5 helpers load with their dependencies"
else
  err "helpers failed to load:$BROKEN — run ./scripts/setup.sh"; FAIL=1
fi

# 4. Real analysis + render through the grade helper -----------------------
if python3 "$HELPERS/grade.py" "$WORK/clip.mp4" -o "$WORK/graded.mp4" >/dev/null 2>&1 \
   && [ -s "$WORK/graded.mp4" ]; then
  ok "color grade analyzed and re-rendered the clip"
else
  err "grade helper failed"; FAIL=1
fi

# 5. Report on the key without spending anything ---------------------------
KEY="${ELEVENLABS_API_KEY:-}"
[ -z "$KEY" ] && [ -f "$REPO_ROOT/.env" ] && \
  KEY="$(sed -n 's/^ELEVENLABS_API_KEY=//p' "$REPO_ROOT/.env" | head -1)"
if [ -n "$KEY" ]; then
  CODE="$(curl -s -o /dev/null -m 10 -w '%{http_code}' \
    -H "xi-api-key: $KEY" https://api.elevenlabs.io/v1/user 2>/dev/null)"
  [ "$CODE" = "200" ] && ok "ElevenLabs key valid — transcription will work" \
                      || { err "ElevenLabs key rejected (HTTP $CODE)"; FAIL=1; }
else
  printf '  \033[33m!\033[0m no ElevenLabs key — rendering works, transcription will not\n'
  printf '     cp .env.example .env, then add a key from\n'
  printf '     https://elevenlabs.io/app/settings/api-keys\n'
fi

if [ "$FAIL" -eq 0 ]; then
  printf '\n\033[1mPipeline is working.\033[0m Drop footage in footage/ and describe the edit.\n\n'
else
  printf '\n\033[1mSomething is broken — see ✗ above.\033[0m\n\n'; exit 1
fi
