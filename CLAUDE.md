# Working in this repo

This is a video editing workspace. The real capability lives in the `video-use`
skill at `.claude/skills/video-use` — read its `SKILL.md` before editing
anything. It is the authority on the editing pipeline; this file only covers
conventions specific to LAMANO.

## Conventions

- **Sources live in `footage/<project>/`.** Never modify a source file in
  place. All output goes to `footage/<project>/edit/`.
- **Never commit media.** Video, audio, and render artifacts are gitignored on
  purpose. This repo holds setup, not footage.
- **Never commit `.env`.** The ElevenLabs key lives there and nowhere else.
  Don't echo it into tool output or logs.
- **Transcription costs money.** Scribe bills per minute of audio. Transcripts
  cache in `edit/transcripts/` — reuse them, and don't re-transcribe or clear
  that folder without asking first.
- **Confirm the plan before rendering.** Long renders are expensive in time.
  Propose the strategy, get a yes, then execute.

## Setup

`./scripts/setup.sh` provisions everything and is safe to re-run.
`./scripts/setup.sh --check` reports status without changing anything. Remote
sessions run it automatically via the SessionStart hook; local sessions don't,
so that installing ffmpeg stays the user's decision.

If a helper fails with a missing import or missing ffmpeg, run setup rather
than pip-installing ad hoc.

## Modifying the skill

`.claude/skills/video-use` is a git submodule tracking upstream
[browser-use/video-use](https://github.com/browser-use/video-use). Don't edit
files inside it — changes there are not tracked by this repo and will be lost
on update. If behavior needs to change, either configure it through the skill's
own options or raise it upstream.
