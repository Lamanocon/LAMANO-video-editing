# LAMANO video editing

A video editing workspace driven by conversation. Drop raw footage in
`footage/`, tell the agent what you want, get a finished cut back.

Built on [browser-use/video-use](https://github.com/browser-use/video-use) (MIT),
vendored as a submodule at `.claude/skills/video-use`.

## Quick start

```bash
git clone --recurse-submodules <this repo>
cd LAMANO-video-editing
cp .env.example .env          # add your ElevenLabs API key
./scripts/setup.sh            # installs ffmpeg + Python deps
```

Then put footage in a folder under `footage/`, start Claude Code in the repo
root, and say what you want:

> edit footage/launch-video into a 90-second launch video

The agent inventories the sources, proposes a strategy, waits for your
approval, then renders. Output lands in `footage/<project>/edit/final.mp4`.

## What it can do

- **Cut on transcript** — removes filler words and dead space
- **Color grade** — per-clip auto correction, or named creative presets
- **Clean audio** — 30ms fades at every cut so joins don't pop
- **Subtitles** — burned in, styling configurable
- **Animated overlays** — via HyperFrames, Remotion, Manim, or PIL
- **Self-review** — inspects its own render before handing it over

The interesting design choice is that it's *transcript-first*. Editing
decisions are made against word-level timestamps from ElevenLabs Scribe rather
than by looking at frames; visual composites get rendered only when a decision
genuinely needs eyes on it. That's what keeps it affordable on long footage.

## Requirements

| | |
|---|---|
| ffmpeg + ffprobe | required — `setup.sh` installs it |
| ElevenLabs API key | required for transcription — [get one](https://elevenlabs.io/app/settings/api-keys) |
| yt-dlp | optional, only to pull sources from URLs |
| Node 22+ / Manim | optional, only for animation overlays (installed on demand) |

Check your setup at any time:

```bash
./scripts/setup.sh --check
```

## Layout

```
footage/                     raw sources (gitignored) — one folder per project
  <project>/edit/            everything the skill produces, incl. final.mp4
scripts/setup.sh             idempotent provisioning
.claude/
  skills/video-use/          the skill, as a git submodule
  hooks/session-start.sh     auto-provisions remote sessions
  settings.json              hook registration
```

Media and renders are gitignored — this repo holds the *setup*, not the
footage. Keep masters wherever LAMANO keeps masters.

## Cost note

Transcription bills against your ElevenLabs quota per minute of audio
processed. Results are cached in `edit/transcripts/`, so re-running an edit on
footage you've already transcribed is free. Deleting that folder means paying
to transcribe again.

## Updating the skill

```bash
git submodule update --remote .claude/skills/video-use
./scripts/setup.sh            # in case dependencies changed
git commit -am "Update video-use"
```
