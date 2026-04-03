# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

vox-machina is a single-file Bash CLI (`vox-machina.sh`) that plays random audio clips in response to Claude Code hook events (SessionStart, Stop, Notification, PostToolUseFailure). Users install themed "voice packs" (e.g., GLaDOS, Overmind, Wheatley) and the tool picks a random clip from the matching hook folder.

## Architecture

- **`vox-machina.sh`** — The entire CLI. All commands live here as `cmd_*` functions dispatched by a `case` block at the bottom. Uses `python3 -c` inline for JSON manipulation (config read/write, Claude Code settings modification, and TTS audio generation).
- **`install.sh`** — Downloads `vox-machina.sh` to `~/.vox-machina/` and symlinks to `~/.local/bin/vox-machina`.
- **Voice packs** — Directories of audio files organized as `<voice>/<HookName>/*.{wav,aiff,mp3}`. Distributed as zip files via GitHub Releases. Stored at `~/.vox-machina/voices/`.
- **Config** — `~/.vox-machina/config.json` stores `active_voice` and `muted` state. Read/written via `config_get`/`config_set` helpers.
- **Hooks integration** — `cmd_hooks_install` injects `vox-machina play <event>` commands into `~/.claude/settings.json`.
- **Personality system** — `cmd_personality_install` writes a voice-themed personality prompt into `~/.claude/CLAUDE.md` (wrapped in HTML comment markers for clean replacement). Built-in personalities exist for GLaDOS, Wheatley, and Overmind. Voice packs can bundle a custom `personality.md` file.

## Key Details

- No build step, no dependencies beyond bash/python3/curl/unzip and an audio player.
- Audio playback is platform-aware: `afplay` on macOS, cascading fallback (`paplay` > `aplay` > `mpv` > `ffplay`) on Linux.
- TTS generation (`cmd_generate`) supports four engines: `say` (macOS), `espeak` (Linux), `piper` (Linux), `glados` (API).
- Voice packs are gitignored — they're built separately and attached to GitHub Releases.
- `VOX_MACHINA_HOME` env var overrides the default `~/.vox-machina` location.

## Testing

No test framework. Manual testing:

```bash
# Test the CLI directly
bash vox-machina.sh help
bash vox-machina.sh init test-voice
bash vox-machina.sh play Stop
```
