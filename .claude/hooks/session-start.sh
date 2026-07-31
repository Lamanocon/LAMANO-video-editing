#!/bin/bash
# SessionStart hook — provision the video editing toolchain.
#
# Remote/web sessions start from a fresh container with no ffmpeg and no Python
# deps, so the video-use skill would fail on its first real command. This runs
# scripts/setup.sh to fix that before the session begins.
#
# Local sessions are skipped on purpose: installing ffmpeg via brew/apt on
# someone's own machine should be their call. Run ./scripts/setup.sh by hand.
set -uo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/../..}" || exit 0

# Never fail the session over provisioning. setup.sh reports what's missing and
# the skill surfaces a clear error if a real command needs a tool that's absent.
bash scripts/setup.sh || true

# Make the key visible to helpers invoked from any working directory.
if [ -n "${CLAUDE_ENV_FILE:-}" ] && [ -f .env ]; then
  KEY="$(sed -n 's/^ELEVENLABS_API_KEY=//p' .env | head -1)"
  [ -n "$KEY" ] && echo "export ELEVENLABS_API_KEY=$KEY" >> "$CLAUDE_ENV_FILE"
fi

exit 0
