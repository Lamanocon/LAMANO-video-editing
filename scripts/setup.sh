#!/usr/bin/env bash
# Provision this workspace for video editing with the video-use skill.
#
# Idempotent and safe to re-run: every step checks before it acts. Designed to
# run unattended at session start in an ephemeral container, and by hand on a
# laptop.
#
#   ./scripts/setup.sh          # provision
#   ./scripts/setup.sh --check  # report status only, change nothing

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL_DIR="$REPO_ROOT/.claude/skills/video-use"
CHECK_ONLY=0
[ "${1:-}" = "--check" ] && CHECK_ONLY=1

ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$1"; }
err()  { printf '  \033[31m✗\033[0m %s\n' "$1"; }
step() { printf '\n\033[1m%s\033[0m\n' "$1"; }

MISSING=0

# ---------------------------------------------------------------- skill files
step "video-use skill"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  ok "present at .claude/skills/video-use"
elif [ "$CHECK_ONLY" = 1 ]; then
  err "missing — run ./scripts/setup.sh"; MISSING=1
else
  # Normal path: it's a submodule and just needs initializing.
  git -C "$REPO_ROOT" submodule update --init --recursive >/dev/null 2>&1
  if [ ! -f "$SKILL_DIR/SKILL.md" ]; then
    # Fallback for environments where submodule fetch is blocked.
    rm -rf "$SKILL_DIR"
    git clone --depth 1 https://github.com/browser-use/video-use.git "$SKILL_DIR" >/dev/null 2>&1
  fi
  [ -f "$SKILL_DIR/SKILL.md" ] && ok "fetched" || { err "could not fetch video-use"; MISSING=1; }
fi

# ------------------------------------------------------------------- ffmpeg
step "ffmpeg (required)"
if command -v ffmpeg >/dev/null && command -v ffprobe >/dev/null; then
  ok "$(ffmpeg -version | head -1 | cut -d' ' -f1-3)"
elif [ "$CHECK_ONLY" = 1 ]; then
  err "missing — run ./scripts/setup.sh"; MISSING=1
else
  echo "  installing..."
  if command -v apt-get >/dev/null; then
    SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"
    $SUDO apt-get update -qq >/dev/null 2>&1
    DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y -qq ffmpeg >/dev/null 2>&1
  elif command -v brew >/dev/null; then
    brew install ffmpeg >/dev/null 2>&1
  elif command -v pacman >/dev/null; then
    sudo pacman -S --noconfirm ffmpeg >/dev/null 2>&1
  fi
  if command -v ffmpeg >/dev/null; then
    ok "$(ffmpeg -version | head -1 | cut -d' ' -f1-3)"
  else
    err "install failed — see https://ffmpeg.org/download.html"; MISSING=1
  fi
fi

# -------------------------------------------------------------- python deps
step "Python dependencies"
PY_DEPS="requests librosa matplotlib pillow numpy"
if python3 -c "import requests, librosa, matplotlib, PIL, numpy" 2>/dev/null; then
  ok "requests, librosa, matplotlib, pillow, numpy"
elif [ "$CHECK_ONLY" = 1 ]; then
  err "missing — run ./scripts/setup.sh"; MISSING=1
else
  echo "  installing..."
  # uv is faster when present; pip needs --break-system-packages on PEP 668 distros.
  if command -v uv >/dev/null; then
    uv pip install --system --quiet $PY_DEPS >/dev/null 2>&1 \
      || uv pip install --quiet $PY_DEPS >/dev/null 2>&1
  fi
  python3 -c "import requests, librosa, matplotlib, PIL, numpy" 2>/dev/null \
    || pip3 install --quiet --break-system-packages $PY_DEPS >/dev/null 2>&1 \
    || pip3 install --quiet $PY_DEPS >/dev/null 2>&1
  if python3 -c "import requests, librosa, matplotlib, PIL, numpy" 2>/dev/null; then
    ok "installed"
  else
    err "install failed — try: pip3 install $PY_DEPS"; MISSING=1
  fi
fi

# ------------------------------------------------------------------ yt-dlp
# Not strictly required, but in a remote container it's often the only way to
# get footage in at all, so install it rather than deferring. Never fatal.
step "yt-dlp (for pulling sources from URLs)"
if command -v yt-dlp >/dev/null; then
  ok "$(yt-dlp --version 2>/dev/null)"
elif [ "$CHECK_ONLY" = 1 ]; then
  warn "not installed — run ./scripts/setup.sh"
else
  echo "  installing..."
  # brew keeps it on PATH cleanly on macOS; pip is the fallback elsewhere.
  if command -v brew >/dev/null; then
    brew install yt-dlp >/dev/null 2>&1
  fi
  command -v yt-dlp >/dev/null \
    || pip3 install --quiet --break-system-packages yt-dlp >/dev/null 2>&1 \
    || pip3 install --quiet yt-dlp >/dev/null 2>&1
  if command -v yt-dlp >/dev/null; then
    ok "$(yt-dlp --version 2>/dev/null)"
  else
    warn "install failed — only needed for URL sources, continuing"
  fi
fi

# ----------------------------------------------------------- elevenlabs key
step "ElevenLabs API key"
KEY="${ELEVENLABS_API_KEY:-}"
[ -z "$KEY" ] && [ -f "$REPO_ROOT/.env" ] && \
  KEY="$(sed -n 's/^ELEVENLABS_API_KEY=//p' "$REPO_ROOT/.env" | head -1)"

if [ -n "$KEY" ]; then
  CODE="$(curl -s -o /dev/null -m 10 -w '%{http_code}' \
    -H "xi-api-key: $KEY" https://api.elevenlabs.io/v1/user 2>/dev/null)"
  case "$CODE" in
    200) ok "key valid" ;;
    401) err "key rejected (401) — check .env against https://elevenlabs.io/app/settings/api-keys"; MISSING=1 ;;
    *)   warn "key present, could not verify (HTTP ${CODE:-none}) — will confirm on first transcription" ;;
  esac
else
  warn "not set — transcription will fail until you add one"
  echo "     cp .env.example .env  &&  edit .env"
  echo "     key: https://elevenlabs.io/app/settings/api-keys"
fi

# ------------------------------------------------------------------ summary
if [ "$MISSING" -eq 0 ]; then
  step "Ready. Drop footage in footage/ and tell the agent what to make."
else
  step "Setup incomplete — see the ✗ items above."
  exit 1
fi
