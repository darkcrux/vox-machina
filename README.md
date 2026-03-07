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

Add to your PATH:

```bash
export PATH="$HOME/.vox-machina:$PATH"
```

## Quick Start

```bash
# Install a voice pack
vox-machina.sh install glados

# Set it as active
vox-machina.sh use glados

# Hook into Claude Code
vox-machina.sh hooks install

# Test it
vox-machina.sh play Stop
```

## Available Voice Packs

| Voice | Description |
|-------|-------------|
| `glados` | The passive-aggressive AI from Portal |
| `overmind` | The commanding Zerg consciousness from StarCraft |

## Commands

```
vox-machina.sh install <voice|path>   Install a voice pack (from release or local folder)
vox-machina.sh uninstall <voice>      Remove a voice pack
vox-machina.sh use <voice>            Set the active voice
vox-machina.sh list                   List installed voice packs
vox-machina.sh play <hook>            Play a random clip for a hook
vox-machina.sh hooks install          Add hooks to Claude Code settings
vox-machina.sh hooks uninstall        Remove hooks from Claude Code settings
```

## Create Your Own Voice Pack

Just create a folder with audio files organized by hook event:

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
vox-machina.sh install ./my-voice
```

Any audio format supported by macOS `afplay` works (wav, mp3, aiff, m4a).

## Requirements

- macOS (uses `afplay` for audio playback)
- [Claude Code](https://claude.com/claude-code)
- python3 (for config management)

## License

MIT
