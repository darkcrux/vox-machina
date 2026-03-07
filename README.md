# vox-machina

Playful AI voice packs for [Claude Code](https://claude.com/claude-code) hooks. Get snarky GLaDOS commentary, commanding Overmind directives, or create your own custom voice packs.

## What it does

vox-machina plays random audio clips at key moments in your Claude Code session:

- **SessionStart** — When you begin a conversation
- **Stop** — When Claude finishes and it's your turn
- **Notification** — When Claude needs your attention
- **PostToolUseFailure** — When something goes wrong

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/darkcrux/vox-machina/main/install.sh | bash
```

This installs the script to `~/.vox-machina/` and symlinks `vox-machina` into `~/.local/bin/`. If `~/.local/bin` isn't in your PATH, the installer will show you how to add it.

## Quick Start

```bash
# Install a voice pack
vox-machina install glados

# Set it as active
vox-machina use glados

# Hook into Claude Code
vox-machina hooks install

# Test it
vox-machina play Stop
```

## Available Voice Packs

| Voice | Description |
|-------|-------------|
| `glados` | The passive-aggressive AI from Portal |
| `overmind` | The commanding Zerg consciousness from StarCraft |

## Commands

```
vox-machina init <name>            Create a voice definition template
vox-machina install <voice|path>   Install a voice pack (from release or local folder)
vox-machina uninstall <voice>      Remove a voice pack
vox-machina use <voice>            Set the active voice
vox-machina list                   List installed voice packs
vox-machina play <hook>            Play a random clip for a hook
vox-machina generate <voice.json>  Generate audio from a voice definition
vox-machina mute                   Silence all voice playback
vox-machina unmute                 Re-enable voice playback
vox-machina status                 Show current voice and mute state
vox-machina hooks install          Add hooks to Claude Code settings
vox-machina hooks uninstall        Remove hooks from Claude Code settings
```

## Create Your Own Voice Pack

### Option 1: Generate from a voice definition

```bash
# Create a template
vox-machina init my-voice

# Edit my-voice.json with your phrases and TTS settings
# Then generate the audio files
vox-machina generate my-voice.json

# Install the generated voice pack
vox-machina install ./my-voice
```

#### Supported engines

| Engine | Platform | Settings |
|--------|----------|----------|
| `say` | macOS | `say_voice`, `say_rate` |
| `espeak` | Linux | `espeak_voice`, `espeak_pitch`, `espeak_speed` |
| `piper` | Linux | `piper_model` |
| `glados` | Any | `api_url` (defaults to glados.c-net.org) |

If no engine is specified, it auto-detects: `say` on macOS, `espeak` on Linux.

#### Available macOS voices

Run `say -v '?'` to see all available voices. Some good ones:

| Voice | Style |
|-------|-------|
| `Daniel` | British, authoritative |
| `Samantha` | Default Siri-like |
| `Fred` | Classic deep male |
| `Whisper` | Whispery |
| `Zarvox` | Robotic alien |

### Option 2: Bring your own audio files

Create a folder with audio files organized by hook event:

```
my-voice/
├── SessionStart/
│   ├── 01.wav
│   └── 02.mp3
├── Stop/
│   └── something-witty.wav
├── Notification/
│   └── hey-listen.mp3
└── PostToolUseFailure/
    └── oops.wav
```

Install it:

```bash
vox-machina install ./my-voice
```

You only need folders for the hooks you want — missing folders are silently skipped.

## Platform Support

| Platform | Audio Player |
|----------|-------------|
| macOS | `afplay` (built-in) |
| Linux | `paplay`, `aplay`, `mpv`, or `ffplay` (first available) |

On Linux, install one of: `pulseaudio-utils`, `alsa-utils`, `mpv`, or `ffmpeg`.

## Requirements

- [Claude Code](https://claude.com/claude-code)
- `bash`, `curl`, `unzip`, `python3`
- An audio player (see platform support above)

## License

MIT
