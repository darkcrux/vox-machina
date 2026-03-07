# vox-machina

> *"Voice of the machine"* — because your AI pair programmer should have personality.

Your terminal is already talking to you. Might as well make it entertaining.

vox-machina hooks into [Claude Code](https://claude.com/claude-code) and plays random voice clips when things happen — task complete, session start, errors, notifications. Ship with GLaDOS passive-aggressively judging your code, or the Zerg Overmind commanding you to obey the Swarm. Or make your own. We don't judge. (GLaDOS will, though.)

## How it works

Claude Code has [hooks](https://docs.anthropic.com/en/docs/claude-code/hooks) — events that fire at key moments. vox-machina latches onto four of them:

| Hook | When it fires | What you'll hear |
|------|--------------|------------------|
| **SessionStart** | You open a session | *"Oh, it's you. It's been a long time."* |
| **Stop** | Claude finishes, your turn | *"Task complete. Please proceed to the next test chamber."* |
| **Notification** | Claude needs your attention | *"I hate to interrupt, but actually, no, I love to interrupt."* |
| **PostToolUseFailure** | Something broke | *"Error detected. I blame you."* |

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/darkcrux/vox-machina/main/install.sh | bash
```

Installs to `~/.vox-machina/` and symlinks into `~/.local/bin/`. If that's not in your PATH, the installer will politely tell you what to do.

## Quick start

```bash
vox-machina install glados    # Download the GLaDOS voice pack
vox-machina use glados        # Set it as active
vox-machina hooks install     # Wire it into Claude Code
vox-machina play Stop         # Test it. You've earned it.
```

## Voice packs

| Pack | Vibe |
|------|------|
| `glados` | Passive-aggressive AI from Portal. Will question your life choices. |
| `overmind` | Zerg Swarm commander from StarCraft. You are the cerebrate now. |
| `wheatley` | Bumbling personality core from Portal 2. Sixty percent ready. |

Switch anytime:

```bash
vox-machina use overmind      # For the Swarm
vox-machina use glados        # For science
vox-machina use wheatley      # For chaos
```

## Too much? Too little?

```bash
vox-machina mute              # Silence. Finally.
vox-machina unmute            # You missed it, didn't you?
vox-machina status            # Check what's going on
```

## Commands

```
vox-machina init <name>            Scaffold a new voice definition
vox-machina generate <voice.json>  Generate audio from a voice definition
vox-machina install <voice|path>   Install a voice pack (from release or local folder)
vox-machina uninstall <voice>      Remove a voice pack
vox-machina use <voice>            Set the active voice
vox-machina list                   List installed voice packs
vox-machina play <hook>            Play a random clip
vox-machina mute                   Silence all playback
vox-machina unmute                 Re-enable playback
vox-machina status                 Show current voice and mute state
vox-machina hooks install          Add hooks to Claude Code
vox-machina hooks uninstall        Remove hooks from Claude Code
```

## Make your own voice pack

You have two options: generate audio from text, or bring your own files.

### Generate from text

```bash
# Scaffold a template
vox-machina init jarvis

# Edit jarvis.json — add your phrases, pick a TTS engine
# Then generate the audio
vox-machina generate jarvis.json

# Install and activate
vox-machina install ./jarvis
vox-machina use jarvis
```

The template gives you all four hooks with placeholder phrases. Fill in what you want, delete what you don't — missing hooks are silently skipped.

#### TTS engines

| Engine | Platform | Config |
|--------|----------|--------|
| `say` | macOS | `say_voice`, `say_rate` |
| `espeak` | Linux | `espeak_voice`, `espeak_pitch`, `espeak_speed` |
| `piper` | Linux | `piper_model` |
| `glados` | Any | `api_url` (defaults to glados.c-net.org) |

Auto-detects `say` on macOS, `espeak` on Linux if you don't specify.

**macOS voices worth trying** (run `say -v '?'` for the full list):

| Voice | Vibe |
|-------|------|
| `Daniel` | British. Authoritative. Judges you politely. |
| `Zarvox` | Robotic alien. Surprisingly good Overmind. |
| `Whisper` | ASMR for your terminal. |
| `Fred` | The voice your dad's GPS would have. |
| `Samantha` | Siri before Siri was Siri. |

### Bring your own audio

Drop audio files into folders named after hooks:

```
my-voice/
├── SessionStart/
│   └── hello-there.mp3
├── Stop/
│   ├── 01.wav
│   └── 02.wav
├── Notification/
│   └── hey-listen.wav
└── PostToolUseFailure/
    └── you-died.mp3
```

```bash
vox-machina install ./my-voice
```

Any format `afplay` (macOS) or your Linux audio player handles works — wav, mp3, aiff, m4a, ogg.

## Platform support

| Platform | Audio player | Notes |
|----------|-------------|-------|
| macOS | `afplay` | Built-in. You're good. |
| Linux | `paplay` / `aplay` / `mpv` / `ffplay` | First one found wins. Install one of: `pulseaudio-utils`, `alsa-utils`, `mpv`, or `ffmpeg`. |

## Requirements

- [Claude Code](https://claude.com/claude-code)
- `bash`, `curl`, `unzip`, `python3`
- Something that plays audio (see above)

## License

MIT
