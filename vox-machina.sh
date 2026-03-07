#!/usr/bin/env bash
# vox-machina: Playful AI voice packs for Claude Code hooks
set -euo pipefail

VOX_HOME="${VOX_MACHINA_HOME:-$HOME/.vox-machina}"
VOICES_DIR="${VOX_HOME}/voices"
CONFIG_FILE="${VOX_HOME}/config.json"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
REPO="darkcrux/vox-machina"

# --- Helpers ---

config_get() {
  python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('$1', ''))" 2>/dev/null
}

config_set() {
  python3 -c "
import json, os
f = '$CONFIG_FILE'
c = json.load(open(f)) if os.path.exists(f) else {}
c['$1'] = '$2'
json.dump(c, open(f, 'w'), indent=2)
"
}

audio_play() {
  local file="$1"
  case "$(uname -s)" in
    Darwin)  afplay "$file" &disown ;;
    Linux)
      if command -v paplay &>/dev/null; then
        paplay "$file" &disown
      elif command -v aplay &>/dev/null; then
        aplay -q "$file" &disown
      elif command -v mpv &>/dev/null; then
        mpv --no-terminal "$file" &disown
      elif command -v ffplay &>/dev/null; then
        ffplay -nodisp -autoexit -loglevel quiet "$file" &disown
      else
        echo "vox-machina: no audio player found. Install pulseaudio, alsa-utils, mpv, or ffmpeg." >&2
        exit 1
      fi
      ;;
    *)
      echo "vox-machina: unsupported platform $(uname -s)" >&2
      exit 1
      ;;
  esac
}

# --- Commands ---

cmd_init() {
  local name="${1:-}"
  if [[ -z "$name" ]]; then
    echo "Usage: vox-machina init <name>" >&2
    exit 1
  fi

  local outfile="${name}.json"
  if [[ -f "$outfile" ]]; then
    echo "File already exists: $outfile" >&2
    exit 1
  fi

  cat > "$outfile" <<TMPL
{
  "name": "${name}",
  "engine": "say",
  "say_voice": "Daniel",
  "hooks": {
    "SessionStart": [
      "Your phrase here.",
      "Another phrase here."
    ],
    "Stop": [
      "Your phrase here.",
      "Another phrase here."
    ],
    "Notification": [
      "Your phrase here.",
      "Another phrase here."
    ],
    "PostToolUseFailure": [
      "Your phrase here.",
      "Another phrase here."
    ],
    "SessionEnd": [
      "Your phrase here.",
      "Another phrase here."
    ],
    "PreCompact": [
      "Your phrase here.",
      "Another phrase here."
    ]
  }
}
TMPL

  echo "Created ${outfile} — edit the phrases, then run:"
  echo "  vox-machina generate ${outfile}"
}

cmd_mute() {
  config_set muted "true"
  echo "vox-machina muted."
}

cmd_unmute() {
  config_set muted ""
  echo "vox-machina unmuted."
}

cmd_status() {
  local active muted
  active=$(config_get active_voice)
  muted=$(config_get muted)

  echo "Voice:  ${active:-<none>}"
  if [[ "$muted" == "true" ]]; then
    echo "Status: muted"
  else
    echo "Status: active"
  fi
}

cmd_play() {
  # Silently exit if muted
  local muted
  muted=$(config_get muted)
  [[ "$muted" == "true" ]] && exit 0

  local hook="${1:-Stop}"
  local voice
  voice=$(config_get active_voice)

  if [[ -z "$voice" ]]; then
    echo "No active voice set. Run: vox-machina use <voice>" >&2
    exit 1
  fi

  local audio_dir="${VOICES_DIR}/${voice}/${hook}"
  if [[ ! -d "$audio_dir" ]]; then
    exit 0
  fi

  local files=()
  for f in "$audio_dir"/*; do
    [[ -f "$f" ]] && files+=("$f")
  done

  if [[ ${#files[@]} -eq 0 ]]; then
    exit 0
  fi

  local selected="${files[$((RANDOM % ${#files[@]}))]}"
  audio_play "$selected"
}

cmd_use() {
  local voice="${1:-}"
  if [[ -z "$voice" ]]; then
    echo "Usage: vox-machina use <voice>" >&2
    exit 1
  fi

  if [[ ! -d "${VOICES_DIR}/${voice}" ]]; then
    echo "Voice pack '${voice}' not found. Run: vox-machina list" >&2
    exit 1
  fi

  config_set active_voice "$voice"
  echo "Active voice set to: ${voice}"
}

cmd_list() {
  local active
  active=$(config_get active_voice)

  echo "Installed voice packs:"
  for dir in "$VOICES_DIR"/*/; do
    [[ -d "$dir" ]] || continue
    local name
    name=$(basename "$dir")
    if [[ "$name" == "$active" ]]; then
      echo "  * ${name} (active)"
    else
      echo "    ${name}"
    fi
  done
}

cmd_install_voice() {
  local voice="${1:-}"
  if [[ -z "$voice" ]]; then
    echo "Usage: vox-machina install <voice|path>" >&2
    exit 1
  fi

  # Local directory install
  if [[ -d "$voice" ]]; then
    local name
    name=$(basename "$voice")
    echo "Installing local voice pack: ${name}"
    mkdir -p "${VOICES_DIR}/${name}"
    cp -R "$voice"/* "${VOICES_DIR}/${name}/"
    echo "Installed: ${name}"
    return
  fi

  # Download from GitHub Release
  echo "Downloading voice pack: ${voice}"
  local tmp
  tmp=$(mktemp -d)
  local url="https://github.com/${REPO}/releases/latest/download/${voice}.zip"

  if ! curl -fsSL -o "${tmp}/${voice}.zip" "$url"; then
    echo "Failed to download '${voice}'. Check available packs at:" >&2
    echo "  https://github.com/${REPO}/releases" >&2
    rm -rf "$tmp"
    exit 1
  fi

  mkdir -p "${VOICES_DIR}/${voice}"
  unzip -qo "${tmp}/${voice}.zip" -d "${VOICES_DIR}/${voice}"
  rm -rf "$tmp"
  echo "Installed: ${voice}"
}

cmd_uninstall_voice() {
  local voice="${1:-}"
  if [[ -z "$voice" ]]; then
    echo "Usage: vox-machina uninstall <voice>" >&2
    exit 1
  fi

  if [[ ! -d "${VOICES_DIR}/${voice}" ]]; then
    echo "Voice pack '${voice}' not found." >&2
    exit 1
  fi

  rm -rf "${VOICES_DIR:?}/${voice}"

  local active
  active=$(config_get active_voice)
  if [[ "$active" == "$voice" ]]; then
    config_set active_voice ""
  fi

  echo "Uninstalled: ${voice}"
}

cmd_generate() {
  local input="${1:-}"
  if [[ -z "$input" ]]; then
    echo "Usage: vox-machina generate <voice.json> [--engine say|espeak|glados]" >&2
    exit 1
  fi

  if [[ ! -f "$input" ]]; then
    echo "File not found: $input" >&2
    exit 1
  fi

  # Parse engine from args (default: auto-detect)
  local engine="${2:-}"
  if [[ "$engine" == "--engine" ]]; then
    engine="${3:-}"
  fi

  python3 -c "
import json, subprocess, os, sys, time

input_file = '$input'
engine_arg = '$engine'

with open(input_file) as f:
    voice = json.load(f)

name = voice['name']
hooks = voice.get('hooks', {})

# Determine engine
engine = engine_arg
if not engine:
    engine = voice.get('engine', '')
if not engine:
    if sys.platform == 'darwin':
        engine = 'say'
    else:
        engine = 'espeak'

# Get voice settings
say_voice = voice.get('say_voice', 'Daniel')
say_rate = voice.get('say_rate', '')
espeak_voice = voice.get('espeak_voice', 'en')
espeak_pitch = voice.get('espeak_pitch', '50')
espeak_speed = voice.get('espeak_speed', '150')
glados_url = voice.get('api_url', 'https://glados.c-net.org/generate')

# Output directory
out_dir = os.path.join(os.path.dirname(os.path.abspath(input_file)), name)
os.makedirs(out_dir, exist_ok=True)

total = sum(len(phrases) for phrases in hooks.values())
count = 0

for hook, phrases in hooks.items():
    hook_dir = os.path.join(out_dir, hook)
    os.makedirs(hook_dir, exist_ok=True)

    for i, phrase in enumerate(phrases, 1):
        count += 1

        if engine == 'say':
            ext = 'aiff'
            out_file = os.path.join(hook_dir, f'{i:02d}.{ext}')
            cmd = ['say', '-v', say_voice, '-o', out_file]
            if say_rate:
                cmd.extend(['-r', str(say_rate)])
            cmd.append(phrase)
        elif engine == 'espeak':
            ext = 'wav'
            out_file = os.path.join(hook_dir, f'{i:02d}.{ext}')
            cmd = ['espeak', '-v', espeak_voice, '-p', str(espeak_pitch),
                   '-s', str(espeak_speed), '-w', out_file, phrase]
        elif engine == 'piper':
            ext = 'wav'
            out_file = os.path.join(hook_dir, f'{i:02d}.{ext}')
            piper_model = voice.get('piper_model', '')
            cmd = ['sh', '-c', f'echo \"{phrase}\" | piper --model {piper_model} --output_file {out_file}']
        elif engine == 'glados':
            ext = 'wav'
            out_file = os.path.join(hook_dir, f'{i:02d}.{ext}')
            cmd = ['curl', '-L', '--retry', '30', '--get', '--fail',
                   '--data-urlencode', f'text={phrase}',
                   '-o', out_file, glados_url]
        else:
            print(f'Unknown engine: {engine}', file=sys.stderr)
            sys.exit(1)

        print(f'  [{count}/{total}] {hook}/{i:02d}.{ext}: {phrase}')
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            print(f'    ERROR: {result.stderr.strip()}', file=sys.stderr)

print(f'')
print(f'Generated {count} clips in: {out_dir}')
print(f'')
print(f'Install with:')
print(f'  vox-machina install {out_dir}')
"
}

cmd_hooks_install() {
  if [[ ! -f "$CLAUDE_SETTINGS" ]]; then
    echo "Claude Code settings not found at $CLAUDE_SETTINGS" >&2
    exit 1
  fi

  local vox_bin
  vox_bin=$(command -v vox-machina 2>/dev/null || echo "${VOX_HOME}/vox-machina.sh")

  python3 -c "
import json

settings_path = '$CLAUDE_SETTINGS'
vox_bin = '$vox_bin'

with open(settings_path) as f:
    settings = json.load(f)

hooks = settings.setdefault('hooks', {})

hook_events = ['SessionStart', 'Stop', 'Notification', 'PostToolUseFailure', 'SessionEnd', 'PreCompact']

for event in hook_events:
    hook_cmd = f'{vox_bin} play {event}'
    hook_entry = {
        'hooks': [
            {
                'type': 'command',
                'command': hook_cmd
            }
        ]
    }

    event_hooks = hooks.get(event, [])
    # Remove existing vox-machina hooks
    event_hooks = [h for h in event_hooks if not any(
        'vox-machina' in hk.get('command', '')
        for hk in h.get('hooks', [])
    )]
    event_hooks.append(hook_entry)
    hooks[event] = event_hooks

with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')

print('Hooks installed for: ' + ', '.join(hook_events))
"
}

cmd_hooks_uninstall() {
  if [[ ! -f "$CLAUDE_SETTINGS" ]]; then
    echo "Claude Code settings not found at $CLAUDE_SETTINGS" >&2
    exit 1
  fi

  python3 -c "
import json

settings_path = '$CLAUDE_SETTINGS'

with open(settings_path) as f:
    settings = json.load(f)

hooks = settings.get('hooks', {})

for event in list(hooks.keys()):
    event_hooks = hooks[event]
    event_hooks = [h for h in event_hooks if not any(
        'vox-machina' in hk.get('command', '')
        for hk in h.get('hooks', [])
    )]
    if event_hooks:
        hooks[event] = event_hooks
    else:
        del hooks[event]

with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')

print('Hooks removed.')
"
}

cmd_help() {
  cat <<'EOF'
vox-machina - Playful AI voice packs for Claude Code hooks

Usage:
  vox-machina <command> [args]

Commands:
  init <name>            Create a voice definition template
  install <voice|path>   Install a voice pack (from GitHub Release or local folder)
  uninstall <voice>      Remove an installed voice pack
  use <voice>            Set the active voice pack
  list                   List installed voice packs
  play <hook>            Play a random clip for a hook (SessionStart, Stop, Notification, PostToolUseFailure, SessionEnd, PreCompact)
  generate <voice.json>  Generate audio files from a voice definition
  mute                   Silence all voice playback
  unmute                 Re-enable voice playback
  status                 Show current voice and mute state
  hooks install          Add vox-machina hooks to Claude Code settings
  hooks uninstall        Remove vox-machina hooks from Claude Code settings
  help                   Show this help message

Custom Voice Packs:
  Create a folder with audio files organized by hook:

    my-voice/
    ├── SessionStart/
    │   ├── 01.wav
    │   └── 02.mp3
    ├── Stop/
    ├── Notification/
    ├── PostToolUseFailure/
    ├── SessionEnd/
    └── PreCompact/

  Then install it:
    vox-machina install ./my-voice
EOF
}

# --- Main ---

mkdir -p "$VOX_HOME" "$VOICES_DIR"
[[ -f "$CONFIG_FILE" ]] || echo '{}' > "$CONFIG_FILE"

case "${1:-help}" in
  play)       cmd_play "${2:-}" ;;
  init)       cmd_init "${2:-}" ;;
  generate)   cmd_generate "${2:-}" "${3:-}" "${4:-}" ;;
  use)        cmd_use "${2:-}" ;;
  list)       cmd_list ;;
  mute)       cmd_mute ;;
  unmute)     cmd_unmute ;;
  status)     cmd_status ;;
  install)
    if [[ "${2:-}" == "hooks" ]] || [[ "${2:-}" == "" && "${1:-}" == "hooks" ]]; then
      shift; cmd_hooks_install
    else
      cmd_install_voice "${2:-}"
    fi
    ;;
  uninstall)  cmd_uninstall_voice "${2:-}" ;;
  hooks)
    case "${2:-}" in
      install)   cmd_hooks_install ;;
      uninstall) cmd_hooks_uninstall ;;
      *)         echo "Usage: vox-machina hooks [install|uninstall]" >&2; exit 1 ;;
    esac
    ;;
  help|--help|-h) cmd_help ;;
  *)          echo "Unknown command: $1. Run 'vox-machina help' for usage." >&2; exit 1 ;;
esac
