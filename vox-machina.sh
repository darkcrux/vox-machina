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

# --- Commands ---

cmd_play() {
  local hook="${1:-Stop}"
  local voice
  voice=$(config_get active_voice)

  if [[ -z "$voice" ]]; then
    echo "No active voice set. Run: vox-machina use <voice>" >&2
    exit 1
  fi

  local audio_dir="${VOICES_DIR}/${voice}/${hook}"
  if [[ ! -d "$audio_dir" ]]; then
    # Try case-insensitive match (e.g. SessionStart -> session_start)
    local lower_hook
    lower_hook=$(echo "$hook" | sed 's/\([A-Z]\)/_\L\1/g' | sed 's/^_//')
    audio_dir="${VOICES_DIR}/${voice}/${lower_hook}"
    if [[ ! -d "$audio_dir" ]]; then
      exit 0
    fi
  fi

  local files=()
  for f in "$audio_dir"/*; do
    [[ -f "$f" ]] && files+=("$f")
  done

  if [[ ${#files[@]} -eq 0 ]]; then
    exit 0
  fi

  local selected="${files[$((RANDOM % ${#files[@]}))]}"
  afplay "$selected" &
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

cmd_hooks_install() {
  if [[ ! -f "$CLAUDE_SETTINGS" ]]; then
    echo "Claude Code settings not found at $CLAUDE_SETTINGS" >&2
    exit 1
  fi

  local vox_bin="${VOX_HOME}/vox-machina.sh"

  python3 -c "
import json

settings_path = '$CLAUDE_SETTINGS'
vox_bin = '$vox_bin'

with open(settings_path) as f:
    settings = json.load(f)

hooks = settings.setdefault('hooks', {})

hook_events = ['SessionStart', 'Stop', 'Notification', 'PostToolUseFailure']

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
        vox_bin in hk.get('command', '')
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

  local vox_bin="${VOX_HOME}/vox-machina.sh"

  python3 -c "
import json

settings_path = '$CLAUDE_SETTINGS'
vox_bin = '$vox_bin'

with open(settings_path) as f:
    settings = json.load(f)

hooks = settings.get('hooks', {})

for event in list(hooks.keys()):
    event_hooks = hooks[event]
    event_hooks = [h for h in event_hooks if not any(
        vox_bin in hk.get('command', '')
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
  install <voice|path>   Install a voice pack (from GitHub Release or local folder)
  uninstall <voice>      Remove an installed voice pack
  use <voice>            Set the active voice pack
  list                   List installed voice packs
  play <hook>            Play a random clip for a hook (SessionStart, Stop, Notification, PostToolUseFailure)
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
    └── PostToolUseFailure/

  Then install it:
    vox-machina install ./my-voice
EOF
}

# --- Main ---

mkdir -p "$VOX_HOME" "$VOICES_DIR"
[[ -f "$CONFIG_FILE" ]] || echo '{}' > "$CONFIG_FILE"

case "${1:-help}" in
  play)       cmd_play "${2:-}" ;;
  use)        cmd_use "${2:-}" ;;
  list)       cmd_list ;;
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
