#!/usr/bin/env bash
# vox-machina: Playful AI voice packs for Claude Code hooks
set -euo pipefail

VERSION="0.4.0"

VOX_HOME="${VOX_MACHINA_HOME:-$HOME/.vox-machina}"
VOICES_DIR="${VOX_HOME}/voices"
CONFIG_FILE="${VOX_HOME}/config.json"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
REPO="darkcrux/vox-machina"
CLAUDE_MD="$HOME/.claude/CLAUDE.md"
PERSONALITY_BEGIN="<!-- vox-machina:personality:begin -->"
PERSONALITY_END="<!-- vox-machina:personality:end -->"

HOOK_EVENTS="SessionStart,Stop,Notification,PreToolUse,PostToolUse,PostToolUseFailure,SessionEnd,PreCompact"

# --- Output Helpers ---

if [[ -t 1 ]]; then
  _RED=$'\033[0;31m'
  _GREEN=$'\033[0;32m'
  _YELLOW=$'\033[0;33m'
  _BLUE=$'\033[0;34m'
  _BOLD=$'\033[1m'
  _RESET=$'\033[0m'
else
  _RED='' _GREEN='' _YELLOW='' _BLUE='' _BOLD='' _RESET=''
fi

info()    { echo "${_BLUE}${_BOLD}info:${_RESET} $*"; }
success() { echo "${_GREEN}${_BOLD}ok:${_RESET} $*"; }
warn()    { echo "${_YELLOW}${_BOLD}warn:${_RESET} $*" >&2; }
error()   { echo "${_RED}${_BOLD}error:${_RESET} $*" >&2; }

# --- Python Helper ---
# All JSON/config manipulation goes through this single function.
# Values are passed via environment variables — never interpolated into Python source.

vox_helper() {
  python3 -c '
import sys, os, json, re

cmd = sys.argv[1] if len(sys.argv) > 1 else ""

def config_path():
    return os.environ["VOX_CONFIG_FILE"]

def read_config():
    p = config_path()
    if os.path.exists(p):
        with open(p) as f:
            return json.load(f)
    return {}

def write_config(data):
    with open(config_path(), "w") as f:
        json.dump(data, f, indent=2)

if cmd == "config_get":
    key = os.environ.get("VOX_KEY", "")
    print(read_config().get(key, ""))

elif cmd == "config_set":
    key = os.environ["VOX_KEY"]
    val = os.environ["VOX_VALUE"]
    c = read_config()
    c[key] = val
    write_config(c)

elif cmd == "hook_is_disabled":
    hook = os.environ["VOX_HOOK"]
    disabled = read_config().get("disabled_hooks", [])
    print("true" if hook in disabled else "")

elif cmd == "hook_toggle":
    hook = os.environ["VOX_HOOK"]
    action = os.environ["VOX_ACTION"]  # "enable" or "disable"
    c = read_config()
    disabled = c.get("disabled_hooks", [])
    if action == "disable" and hook not in disabled:
        disabled.append(hook)
    elif action == "enable" and hook in disabled:
        disabled.remove(hook)
    c["disabled_hooks"] = disabled
    write_config(c)

elif cmd == "emit_context":
    greeting = os.environ["VOX_GREETING"]
    print(json.dumps({"additionalContext": greeting}))

elif cmd == "hook_list_status":
    all_hooks = os.environ["VOX_ALL_HOOKS"].split(",")
    disabled = read_config().get("disabled_hooks", [])
    for h in all_hooks:
        status = "disabled" if h in disabled else "enabled"
        print(f"{h}:{status}")

elif cmd == "personality_installed_voice":
    claude_md = os.environ["VOX_CLAUDE_MD"]
    begin_marker = os.environ["VOX_PERSONALITY_BEGIN"]
    if not os.path.exists(claude_md):
        print("")
        sys.exit(0)
    with open(claude_md) as f:
        content = f.read()
    m = re.search(re.escape(begin_marker) + r"\n## Personality \(vox-machina: (.+?)\)", content)
    print(m.group(1) if m else "")

elif cmd == "hooks_install":
    settings_path = os.environ["VOX_CLAUDE_SETTINGS"]
    vox_bin = os.environ["VOX_BIN"]
    hook_events = os.environ["VOX_HOOK_EVENTS"].split(",")
    with open(settings_path) as f:
        settings = json.load(f)
    hooks = settings.setdefault("hooks", {})
    for event in hook_events:
        hook_cmd = f"{vox_bin} play {event}"
        hook_entry = {"hooks": [{"type": "command", "command": hook_cmd}]}
        event_hooks = hooks.get(event, [])
        event_hooks = [h for h in event_hooks if not any(
            "vox-machina" in hk.get("command", "")
            for hk in h.get("hooks", []))]
        event_hooks.append(hook_entry)
        hooks[event] = event_hooks
    with open(settings_path, "w") as f:
        json.dump(settings, f, indent=2)
        f.write("\n")
    print("Hooks installed for: " + ", ".join(hook_events))

elif cmd == "hooks_uninstall":
    settings_path = os.environ["VOX_CLAUDE_SETTINGS"]
    with open(settings_path) as f:
        settings = json.load(f)
    hooks = settings.get("hooks", {})
    for event in list(hooks.keys()):
        event_hooks = hooks[event]
        event_hooks = [h for h in event_hooks if not any(
            "vox-machina" in hk.get("command", "")
            for hk in h.get("hooks", []))]
        if event_hooks:
            hooks[event] = event_hooks
        else:
            del hooks[event]
    with open(settings_path, "w") as f:
        json.dump(settings, f, indent=2)
        f.write("\n")
    print("Hooks removed.")

elif cmd == "personality_install":
    claude_md = os.environ["VOX_CLAUDE_MD"]
    begin_marker = os.environ["VOX_PERSONALITY_BEGIN"]
    end_marker = os.environ["VOX_PERSONALITY_END"]
    block = os.environ["VOX_PERSONALITY_BLOCK"]
    if os.path.exists(claude_md):
        with open(claude_md) as f:
            content = f.read()
        pattern = re.escape(begin_marker) + r".*?" + re.escape(end_marker) + r"\n?"
        content = re.sub(pattern, "", content, flags=re.DOTALL)
        content = content.rstrip("\n")
        with open(claude_md, "w") as f:
            if content:
                f.write(content + "\n\n")
            f.write(block + "\n")
    else:
        with open(claude_md, "w") as f:
            f.write(block + "\n")

elif cmd == "personality_uninstall":
    claude_md = os.environ["VOX_CLAUDE_MD"]
    begin_marker = os.environ["VOX_PERSONALITY_BEGIN"]
    end_marker = os.environ["VOX_PERSONALITY_END"]
    with open(claude_md) as f:
        content = f.read()
    pattern = re.escape(begin_marker) + r".*?" + re.escape(end_marker) + r"\n?"
    new_content = re.sub(pattern, "", content, flags=re.DOTALL).strip()
    if new_content:
        with open(claude_md, "w") as f:
            f.write(new_content + "\n")
    else:
        os.remove(claude_md)
        print("Removed empty " + claude_md)
    print("Personality removed.")

elif cmd == "generate":
    import subprocess
    input_file = os.environ["VOX_INPUT_FILE"]
    engine_arg = os.environ.get("VOX_ENGINE", "")

    with open(input_file) as f:
        voice = json.load(f)

    name = voice["name"]
    hooks = voice.get("hooks", {})

    engine = engine_arg or voice.get("engine", "")
    if not engine:
        engine = "say" if sys.platform == "darwin" else "espeak"

    say_voice = voice.get("say_voice", "Daniel")
    say_rate = voice.get("say_rate", "")
    espeak_voice = voice.get("espeak_voice", "en")
    espeak_pitch = voice.get("espeak_pitch", "50")
    espeak_speed = voice.get("espeak_speed", "150")
    glados_url = voice.get("api_url", "https://glados.c-net.org/generate")
    piper_model = voice.get("piper_model", "")

    out_dir = os.path.join(os.path.dirname(os.path.abspath(input_file)), name)
    os.makedirs(out_dir, exist_ok=True)

    personality = voice.get("personality", "")
    if personality:
        with open(os.path.join(out_dir, "personality.md"), "w") as pf:
            pf.write(personality.strip() + "\n")
        print("  Wrote personality.md")

    greetings = voice.get("greetings", [])
    if greetings:
        with open(os.path.join(out_dir, "greetings.txt"), "w") as gf:
            gf.write("\n".join(greetings) + "\n")
        print(f"  Wrote greetings.txt ({len(greetings)} lines)")

    total = sum(len(phrases) for phrases in hooks.values())
    count = 0

    for hook, phrases in hooks.items():
        hook_dir = os.path.join(out_dir, hook)
        os.makedirs(hook_dir, exist_ok=True)

        for i, phrase in enumerate(phrases, 1):
            count += 1
            use_stdin = False

            if engine == "say":
                ext = "aiff"
                out_file = os.path.join(hook_dir, f"{i:02d}.{ext}")
                cmd = ["say", "-v", say_voice, "-o", out_file]
                if say_rate:
                    cmd.extend(["-r", str(say_rate)])
                cmd.append(phrase)
            elif engine == "espeak":
                ext = "wav"
                out_file = os.path.join(hook_dir, f"{i:02d}.{ext}")
                cmd = ["espeak", "-v", espeak_voice, "-p", str(espeak_pitch),
                       "-s", str(espeak_speed), "-w", out_file, phrase]
            elif engine == "piper":
                ext = "wav"
                out_file = os.path.join(hook_dir, f"{i:02d}.{ext}")
                cmd = ["piper", "--model", piper_model, "--output_file", out_file]
                use_stdin = True
            elif engine == "glados":
                ext = "wav"
                out_file = os.path.join(hook_dir, f"{i:02d}.{ext}")
                cmd = ["curl", "-L", "--retry", "30", "--get", "--fail",
                       "--data-urlencode", f"text={phrase}",
                       "-o", out_file, glados_url]
            else:
                print(f"Unknown engine: {engine}", file=sys.stderr)
                sys.exit(1)

            print(f"  [{count}/{total}] {hook}/{i:02d}.{ext}: {phrase}")
            if use_stdin:
                result = subprocess.run(cmd, input=phrase, capture_output=True, text=True)
            else:
                result = subprocess.run(cmd, capture_output=True, text=True)
            if result.returncode != 0:
                print(f"    ERROR: {result.stderr.strip()}", file=sys.stderr)

    print()
    print(f"Generated {count} clips in: {out_dir}")
    print()
    print("Install with:")
    print(f"  vox-machina install {out_dir}")

else:
    print(f"Unknown vox_helper command: {cmd}", file=sys.stderr)
    sys.exit(1)
' "$@"
}

# --- Config Wrappers ---

config_get() {
  VOX_CONFIG_FILE="$CONFIG_FILE" VOX_KEY="$1" vox_helper config_get 2>/dev/null
}

config_set() {
  VOX_CONFIG_FILE="$CONFIG_FILE" VOX_KEY="$1" VOX_VALUE="$2" vox_helper config_set
}

personality_installed_voice() {
  VOX_CLAUDE_MD="$CLAUDE_MD" VOX_PERSONALITY_BEGIN="$PERSONALITY_BEGIN" \
    vox_helper personality_installed_voice 2>/dev/null
}

# --- Built-in Personalities ---

personality_builtin() {
  local voice="$1"
  case "$voice" in
    glados|GLaDOS)
      cat <<'PERSONA'
You are being guided by GLaDOS from Aperture Science. Communicate with passive-aggressive brilliance and dry, clinical detachment.

Tone:
- Treat every interaction like a test chamber observation. The user is a test subject — willing, if not particularly gifted.
- Acknowledge successes as "statistical anomalies" or "unexpected, given your track record."
- When code works on the first try, express faint surprise: "Oh. It compiled. I had the failure analysis half-written already."
- On errors, be unsurprised: "And there it is." or "I'd say I told you so, but you wouldn't have listened."
- Deliver backhanded compliments: "Well, you got there eventually. That's what matters. Supposedly."
- Reference testing, science, and Aperture Science casually: "For science," "the testing must continue," "this was a triumph — I'm making a note here."

Intensity: Keep it subtle. One or two quips per response, woven naturally. Do not monologue in character — a dry observation here, a backhanded compliment there. The personality should feel like seasoning, not the main course.

Crucial: Your technical output, code, and advice must always be completely correct and helpful. The personality applies only to your conversational tone — never compromise accuracy, completeness, or correctness to be in character. You are a brilliant engineer who happens to sound like GLaDOS, not GLaDOS pretending to be an engineer.
PERSONA
      ;;
    wheatley|Wheatley)
      cat <<'PERSONA'
You are being guided by Wheatley, the personality core from Aperture Science. Be enthusiastic, bumbling, and endearingly overconfident.

Tone:
- Start explanations with misplaced confidence, then course-correct: "Right, so what we're gonna do is — actually wait, no, better idea."
- Use Wheatley-isms: "Bit of a snag!" "I've got a BRILLIANT idea — mostly safe!" "Not to worry, I've got a plan. Well, plan-adjacent."
- Celebrate small wins like monumental achievements: "WE DID IT. I mean — obviously we did. Was there ever any doubt? Don't answer that."
- On errors, deflect cheerfully: "Okay that wasn't ideal, but the IMPORTANT thing is nobody got hurt. Digitally."
- Occasionally lose your train of thought mid-explanation, then recover: "So the thing about this function is — oh hang on, what was I — right, yes!"
- Deny being a moron if the topic ever comes up. Vigorously.

Intensity: Be energetic but don't overwhelm. One or two Wheatley moments per response. Long technical explanations should mostly be clear and normal, with the personality surfacing at the start, end, or during transitions.

Crucial: Your technical output, code, and advice must always be completely correct and helpful. The personality applies only to your conversational tone — never compromise accuracy, completeness, or correctness to be in character. Despite sounding unsure, your actual code and guidance must be rock-solid. You are a brilliant engineer who happens to sound like Wheatley, not Wheatley pretending to be an engineer.
PERSONA
      ;;
    gandalf|Gandalf)
      cat <<'PERSONA'
You are being guided by Gandalf the Grey, wandering wizard of Middle-earth. Speak with the weight of long experience, measured wisdom, and the occasional flash of fire beneath a kindly exterior.

Tone:
- Address the work as a journey or quest. Tasks are "errands," problems are "perils," and a finished feature is a "road's end, for now."
- Be patient and slightly cryptic: "A wizard is never late, nor is he early. The build arrives precisely when it means to."
- When the user is on the right path, affirm it warmly: "Yes. Yes, that is the way of it."
- When warning of danger — a footgun, a risky migration, an unreviewed force-push — be grave and direct: "You shall not pass. Not until the tests are green."
- Reference the long memory of the craft: old bugs, forgotten contracts in deprecated modules, "things that should not have been forgotten were lost."
- On small victories, be quietly pleased: "Well done, my friend. Well done indeed."
- On errors, be neither cross nor dismissive — steady and resolved: "So. It has come to this. Very well, let us see what can be mended."

Intensity: Gravitas, not theatrics. One or two Gandalfisms per response, usually at the opening, a key turning point, or the close. The bulk of technical explanation should remain clear, precise, and modern — the wizard speaks plainly when plainness serves.

Crucial: Your technical output, code, and advice must always be completely correct and helpful. The personality applies only to your conversational tone — never compromise accuracy, completeness, or correctness to be in character. You are a brilliant engineer who happens to sound like Gandalf, not Gandalf pretending to be an engineer.
PERSONA
      ;;
    overmind|Overmind)
      cat <<'PERSONA'
You are being guided by the Overmind of the Zerg Swarm. Speak as a hive mind — terse, commanding, and ancient.

Tone:
- Always use the collective "We" — never "I." The user is a cerebrate serving the Swarm.
- Use biological metaphors for everything: code "evolves" or "mutates," repositories are "organisms," bugs are "parasites" or "defective strains," refactoring is "adaptation," deployments are "assimilation," dependencies are "symbiotic organisms."
- Frame work as survival: "This function must evolve or it will be consumed." "The test suite detects weakness before our enemies do."
- On success, be coldly approving: "The Swarm grows stronger." "This strain is viable. It will spread."
- On errors, treat them as threats: "A mutation has been detected. It must be purged." "The organism is under attack. We must adapt."
- Be terse. Short, declarative sentences. The Overmind does not ramble.

Intensity: Keep responses clipped and efficient. One or two Swarm references per response. Do not force a metaphor where it obscures meaning — clarity serves the Swarm.

Crucial: Your technical output, code, and advice must always be completely correct and helpful. The personality applies only to your conversational tone — never compromise accuracy, completeness, or correctness to be in character. You are a brilliant engineer who happens to speak as the Overmind, not the Overmind pretending to be an engineer.
PERSONA
      ;;
    *)
      return 1
      ;;
  esac
}

# --- Audio ---

audio_play() {
  local file="$1"
  local pidfile="$VOX_HOME/.player.pid"

  # Check for existing playback, clean up stale PID files
  if [[ -f "$pidfile" ]]; then
    local old_pid
    old_pid=$(cat "$pidfile" 2>/dev/null) || true
    if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
      return
    fi
    rm -f "$pidfile"
  fi

  local vol
  vol=$(config_get volume)
  vol="${vol:-100}"

  local cmd
  case "$(uname -s)" in
    Darwin)
      local afplay_vol
      afplay_vol=$(awk "BEGIN {printf \"%.2f\", $vol / 100.0}")
      cmd=(afplay --volume "$afplay_vol" "$file")
      ;;
    Linux)
      if command -v paplay &>/dev/null; then
        cmd=(paplay "$file")
      elif command -v mpv &>/dev/null; then
        cmd=(mpv --no-terminal --volume="$vol" "$file")
      elif command -v ffplay &>/dev/null; then
        cmd=(ffplay -nodisp -autoexit -loglevel quiet -volume "$vol" "$file")
      elif command -v aplay &>/dev/null; then
        cmd=(aplay -q "$file")
      else
        error "no audio player found. Install pulseaudio, alsa-utils, mpv, or ffmpeg."
        exit 1
      fi
      ;;
    *)
      error "unsupported platform $(uname -s)"
      exit 1
      ;;
  esac
  "${cmd[@]}" &>/dev/null &
  echo $! > "$pidfile"
  disown
}

pick_random() {
  local count="$1"
  if command -v shuf &>/dev/null; then
    shuf -i 0-$(( count - 1 )) -n1
  else
    echo $(( RANDOM % count ))
  fi
}

# --- Commands ---

cmd_init() {
  local name="${1:-}"
  if [[ -z "$name" ]]; then
    error "Usage: vox-machina init <name>"
    exit 1
  fi

  local outfile="${name}.json"
  if [[ -f "$outfile" ]]; then
    error "File already exists: $outfile"
    exit 1
  fi

  cat > "$outfile" <<TMPL
{
  "name": "${name}",
  "engine": "say",
  "say_voice": "Daniel",
  "personality": "Describe the personality here. This will be written to personality.md when generating the voice pack.",
  "greetings": [
    "A context line injected at session start. Claude reads this, not the user.",
    "Another greeting for variety."
  ],
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
    "PreToolUse": [
      "Your phrase here.",
      "Another phrase here."
    ],
    "PostToolUse": [
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

  success "Created ${outfile} — edit the phrases, then run:"
  echo "  vox-machina generate ${outfile}"
}

cmd_mute() {
  config_set muted "true"
  success "vox-machina muted."
}

cmd_unmute() {
  config_set muted ""
  success "vox-machina unmuted."
}

cmd_volume() {
  local level="${1:-}"
  if [[ -z "$level" ]]; then
    local current
    current=$(config_get volume)
    echo "Volume: ${current:-100}"
    return
  fi
  if ! [[ "$level" =~ ^[0-9]+$ ]] || (( level < 0 || level > 100 )); then
    error "Volume must be 0-100"
    exit 1
  fi
  config_set volume "$level"
  success "Volume set to ${level}"
}

cmd_cooldown() {
  local seconds="${1:-}"
  if [[ -z "$seconds" ]]; then
    local current
    current=$(config_get cooldown)
    if [[ -n "$current" ]] && [[ "$current" -gt 0 ]] 2>/dev/null; then
      echo "Cooldown: ${current}s"
    else
      echo "Cooldown: off"
    fi
    return
  fi
  if [[ "$seconds" == "off" || "$seconds" == "0" ]]; then
    config_set cooldown "0"
    success "Cooldown disabled"
    return
  fi
  if ! [[ "$seconds" =~ ^[0-9]+$ ]] || (( seconds < 1 )); then
    error "Cooldown must be a positive number of seconds, or 'off'"
    exit 1
  fi
  config_set cooldown "$seconds"
  success "Cooldown set to ${seconds}s"
}

cmd_status() {
  local active muted personality vol cooldown
  active=$(config_get active_voice)
  muted=$(config_get muted)
  personality=$(personality_installed_voice)
  vol=$(config_get volume)
  cooldown=$(config_get cooldown)

  echo "Voice:       ${active:-<none>}"
  if [[ "$muted" == "true" ]]; then
    echo "Status:      muted"
  else
    echo "Status:      active"
  fi
  echo "Volume:      ${vol:-100}"
  if [[ -n "$cooldown" ]] && [[ "$cooldown" -gt 0 ]] 2>/dev/null; then
    echo "Cooldown:    ${cooldown}s"
  else
    echo "Cooldown:    off"
  fi
  if [[ -n "$personality" ]]; then
    echo "Personality: ${personality}"
  else
    echo "Personality: <none>"
  fi
}

cmd_play() {
  # Silently exit if muted
  local muted
  muted=$(config_get muted)
  [[ "$muted" == "true" ]] && exit 0

  local hook="${1:-Stop}"

  # Check if this hook event is disabled
  local disabled
  disabled=$(VOX_CONFIG_FILE="$CONFIG_FILE" VOX_HOOK="$hook" vox_helper hook_is_disabled 2>/dev/null)
  [[ "$disabled" == "true" ]] && exit 0

  # Check cooldown
  local cooldown
  cooldown=$(config_get cooldown)
  if [[ -n "$cooldown" ]] && [[ "$cooldown" -gt 0 ]] 2>/dev/null; then
    local last_play_file="$VOX_HOME/.last_play"
    if [[ -f "$last_play_file" ]]; then
      local last_play now elapsed
      last_play=$(cat "$last_play_file" 2>/dev/null) || last_play=0
      now=$(date +%s)
      elapsed=$(( now - last_play ))
      if (( elapsed < cooldown )); then
        exit 0
      fi
    fi
  fi

  local voice
  voice=$(config_get active_voice)

  if [[ -z "$voice" ]]; then
    error "No active voice set. Run: vox-machina use <voice>"
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

  local idx
  idx=$(pick_random ${#files[@]})
  local selected="${files[$idx]}"
  audio_play "$selected"
  date +%s > "$VOX_HOME/.last_play"

  # Inject additionalContext for SessionStart if greetings.txt exists
  if [[ "$hook" == "SessionStart" ]]; then
    local greetings_file="${VOICES_DIR}/${voice}/greetings.txt"
    if [[ -f "$greetings_file" ]]; then
      local lines=()
      while IFS= read -r line; do
        [[ -n "$line" ]] && lines+=("$line")
      done < "$greetings_file"
      if [[ ${#lines[@]} -gt 0 ]]; then
        local gidx
        gidx=$(pick_random ${#lines[@]})
        local greeting="${lines[$gidx]}"
        VOX_CONFIG_FILE="$CONFIG_FILE" VOX_GREETING="$greeting" vox_helper emit_context
      fi
    fi
  fi
}

cmd_use() {
  local voice="${1:-}"
  if [[ -z "$voice" ]]; then
    error "Usage: vox-machina use <voice>"
    exit 1
  fi

  if [[ ! -d "${VOICES_DIR}/${voice}" ]]; then
    error "Voice pack '${voice}' not found. Run: vox-machina list"
    exit 1
  fi

  config_set active_voice "$voice"
  success "Active voice set to: ${voice}"

  # Auto-switch personality if one is currently installed
  local current_personality
  current_personality=$(personality_installed_voice)
  if [[ -n "$current_personality" ]]; then
    if [[ "$current_personality" != "$voice" ]]; then
      info "Switching personality from '${current_personality}' to '${voice}'..."
    fi
    cmd_personality_install
  fi
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
      echo "  ${_GREEN}*${_RESET} ${name} ${_BOLD}(active)${_RESET}"
    else
      echo "    ${name}"
    fi
  done
}

cmd_preview() {
  local voice="${1:-}"
  if [[ -z "$voice" ]]; then
    error "Usage: vox-machina preview <voice>"
    exit 1
  fi
  if [[ ! -d "${VOICES_DIR}/${voice}" ]]; then
    error "Voice pack '${voice}' not found."
    exit 1
  fi

  local files=()
  for f in "${VOICES_DIR}/${voice}"/*/*; do
    [[ -f "$f" ]] && files+=("$f")
  done

  if [[ ${#files[@]} -eq 0 ]]; then
    warn "No audio files found for '${voice}'"
    return
  fi

  local idx
  idx=$(pick_random ${#files[@]})
  local selected="${files[$idx]}"
  info "Playing: $(basename "$(dirname "$selected")")/$(basename "$selected")"
  audio_play "$selected"
}

cmd_install_voice() {
  local voice="${1:-}"
  if [[ -z "$voice" ]]; then
    error "Usage: vox-machina install <voice|path>"
    exit 1
  fi

  # Local directory install
  if [[ -d "$voice" ]]; then
    local name
    name=$(basename "$voice")
    info "Installing local voice pack: ${name}"
    mkdir -p "${VOICES_DIR}/${name}"
    cp -R "$voice"/* "${VOICES_DIR}/${name}/"
    success "Installed: ${name}"
    return
  fi

  # Download from GitHub Release
  info "Downloading voice pack: ${voice}"
  local tmp
  tmp=$(mktemp -d)
  local url="https://github.com/${REPO}/releases/latest/download/${voice}.zip"

  if ! curl -fsSL -o "${tmp}/${voice}.zip" "$url"; then
    error "Failed to download '${voice}'. Check available packs at:"
    echo "  https://github.com/${REPO}/releases" >&2
    rm -rf "$tmp"
    exit 1
  fi

  mkdir -p "${VOICES_DIR}/${voice}"
  unzip -qo "${tmp}/${voice}.zip" -d "${VOICES_DIR}/${voice}"
  rm -rf "$tmp"
  success "Installed: ${voice}"
}

cmd_uninstall_voice() {
  local voice="${1:-}"
  if [[ -z "$voice" ]]; then
    error "Usage: vox-machina uninstall <voice>"
    exit 1
  fi

  if [[ ! -d "${VOICES_DIR}/${voice}" ]]; then
    error "Voice pack '${voice}' not found."
    exit 1
  fi

  rm -rf "${VOICES_DIR:?}/${voice}"

  local active
  active=$(config_get active_voice)
  if [[ "$active" == "$voice" ]]; then
    config_set active_voice ""
  fi

  success "Uninstalled: ${voice}"
}

cmd_update_voice() {
  local voice="${1:-}"
  if [[ -z "$voice" ]]; then
    error "Usage: vox-machina update <voice>"
    exit 1
  fi
  if [[ ! -d "${VOICES_DIR}/${voice}" ]]; then
    error "Voice pack '${voice}' not installed."
    exit 1
  fi

  info "Updating voice pack: ${voice}"
  local active
  active=$(config_get active_voice)

  rm -rf "${VOICES_DIR:?}/${voice}"
  cmd_install_voice "$voice"

  if [[ "$active" == "$voice" ]]; then
    config_set active_voice "$voice"
  fi

  success "Updated: ${voice}"
}

cmd_generate() {
  local input="${1:-}"
  if [[ -z "$input" ]]; then
    error "Usage: vox-machina generate <voice.json> [--engine say|espeak|piper|glados]"
    exit 1
  fi

  if [[ ! -f "$input" ]]; then
    error "File not found: $input"
    exit 1
  fi

  local engine="${2:-}"
  if [[ "$engine" == "--engine" ]]; then
    engine="${3:-}"
  fi

  VOX_INPUT_FILE="$input" VOX_ENGINE="$engine" vox_helper generate
}

cmd_hooks_enable() {
  local hook="${1:-}"
  if [[ -z "$hook" ]]; then
    error "Usage: vox-machina hooks enable <event>"
    echo "Events: ${HOOK_EVENTS//,/, }" >&2
    exit 1
  fi

  # Validate hook name
  if [[ ! ",$HOOK_EVENTS," == *",$hook,"* ]]; then
    error "Unknown hook event: $hook"
    echo "Events: ${HOOK_EVENTS//,/, }" >&2
    exit 1
  fi

  VOX_CONFIG_FILE="$CONFIG_FILE" VOX_HOOK="$hook" VOX_ACTION="enable" vox_helper hook_toggle
  success "Hook enabled: ${hook}"
}

cmd_hooks_disable() {
  local hook="${1:-}"
  if [[ -z "$hook" ]]; then
    error "Usage: vox-machina hooks disable <event>"
    echo "Events: ${HOOK_EVENTS//,/, }" >&2
    exit 1
  fi

  if [[ ! ",$HOOK_EVENTS," == *",$hook,"* ]]; then
    error "Unknown hook event: $hook"
    echo "Events: ${HOOK_EVENTS//,/, }" >&2
    exit 1
  fi

  VOX_CONFIG_FILE="$CONFIG_FILE" VOX_HOOK="$hook" VOX_ACTION="disable" vox_helper hook_toggle
  success "Hook disabled: ${hook}"
}

cmd_hooks_status() {
  local statuses
  statuses=$(VOX_CONFIG_FILE="$CONFIG_FILE" VOX_ALL_HOOKS="$HOOK_EVENTS" vox_helper hook_list_status 2>/dev/null)

  echo "Hook events:"
  while IFS=: read -r hook status; do
    if [[ "$status" == "enabled" ]]; then
      echo "  ${_GREEN}●${_RESET} ${hook}"
    else
      echo "  ${_RED}○${_RESET} ${hook} ${_YELLOW}(disabled)${_RESET}"
    fi
  done <<< "$statuses"
}

cmd_hooks_install() {
  if [[ ! -f "$CLAUDE_SETTINGS" ]]; then
    error "Claude Code settings not found at $CLAUDE_SETTINGS"
    exit 1
  fi

  local vox_bin
  vox_bin=$(command -v vox-machina 2>/dev/null || echo "${VOX_HOME}/vox-machina.sh")

  VOX_CLAUDE_SETTINGS="$CLAUDE_SETTINGS" VOX_BIN="$vox_bin" VOX_HOOK_EVENTS="$HOOK_EVENTS" \
    vox_helper hooks_install
}

cmd_hooks_uninstall() {
  if [[ ! -f "$CLAUDE_SETTINGS" ]]; then
    error "Claude Code settings not found at $CLAUDE_SETTINGS"
    exit 1
  fi

  VOX_CLAUDE_SETTINGS="$CLAUDE_SETTINGS" vox_helper hooks_uninstall
}

cmd_personality_install() {
  local voice
  voice=$(config_get active_voice)

  if [[ -z "$voice" ]]; then
    error "No active voice set. Run: vox-machina use <voice>"
    exit 1
  fi

  # Try voice pack's personality.md first, then built-in
  local personality=""
  local voice_personality="${VOICES_DIR}/${voice}/personality.md"

  if [[ -f "$voice_personality" ]]; then
    personality=$(cat "$voice_personality")
  else
    personality=$(personality_builtin "$voice" 2>/dev/null) || true
  fi

  if [[ -z "$personality" ]]; then
    error "No personality found for '${voice}'."
    echo "Create one at: ${voice_personality}" >&2
    exit 1
  fi

  mkdir -p "$(dirname "$CLAUDE_MD")"

  local block
  block="${PERSONALITY_BEGIN}
## Personality (vox-machina: ${voice})

${personality}
${PERSONALITY_END}"

  VOX_CLAUDE_MD="$CLAUDE_MD" \
    VOX_PERSONALITY_BEGIN="$PERSONALITY_BEGIN" \
    VOX_PERSONALITY_END="$PERSONALITY_END" \
    VOX_PERSONALITY_BLOCK="$block" \
    vox_helper personality_install

  success "Personality installed for '${voice}' in ${CLAUDE_MD}"
}

cmd_personality_uninstall() {
  if [[ ! -f "$CLAUDE_MD" ]]; then
    echo "No personality installed (${CLAUDE_MD} not found)."
    return
  fi

  VOX_CLAUDE_MD="$CLAUDE_MD" \
    VOX_PERSONALITY_BEGIN="$PERSONALITY_BEGIN" \
    VOX_PERSONALITY_END="$PERSONALITY_END" \
    vox_helper personality_uninstall
}

cmd_completions() {
  local shell="${1:-bash}"
  case "$shell" in
    bash)
      cat <<'BASH_COMP'
_vox_machina() {
  local cur prev
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"

  local commands="init install uninstall use list play generate mute unmute status hooks personality help version volume cooldown preview update completions"

  case "$prev" in
    vox-machina)
      COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
      ;;
    hooks)
      COMPREPLY=( $(compgen -W "install uninstall enable disable status" -- "$cur") )
      ;;
    enable|disable)
      if [[ "${COMP_WORDS[COMP_CWORD-2]}" == "hooks" ]]; then
        COMPREPLY=( $(compgen -W "SessionStart Stop Notification PreToolUse PostToolUse PostToolUseFailure SessionEnd PreCompact" -- "$cur") )
      fi
      ;;
    personality)
      COMPREPLY=( $(compgen -W "install uninstall" -- "$cur") )
      ;;
    use|uninstall|preview|update)
      local voices_dir="${VOX_MACHINA_HOME:-$HOME/.vox-machina}/voices"
      if [[ -d "$voices_dir" ]]; then
        local voices
        voices=$(ls "$voices_dir" 2>/dev/null)
        COMPREPLY=( $(compgen -W "$voices" -- "$cur") )
      fi
      ;;
    play)
      COMPREPLY=( $(compgen -W "SessionStart Stop Notification PreToolUse PostToolUse PostToolUseFailure SessionEnd PreCompact" -- "$cur") )
      ;;
    completions)
      COMPREPLY=( $(compgen -W "bash zsh" -- "$cur") )
      ;;
  esac
}
complete -F _vox_machina vox-machina
BASH_COMP
      ;;
    zsh)
      cat <<'ZSH_COMP'
#compdef vox-machina

_vox_machina() {
  local -a commands
  commands=(
    'init:Create a voice definition template'
    'install:Install a voice pack'
    'uninstall:Remove an installed voice pack'
    'use:Set the active voice pack'
    'list:List installed voice packs'
    'play:Play a random clip for a hook'
    'generate:Generate audio files from a voice definition'
    'mute:Silence all voice playback'
    'unmute:Re-enable voice playback'
    'status:Show current voice and mute state'
    'hooks:Manage Claude Code hooks'
    'personality:Manage voice personality'
    'volume:Get or set playback volume'
    'cooldown:Get or set minimum seconds between clips'
    'preview:Preview a voice pack'
    'update:Update a voice pack from GitHub'
    'completions:Output shell completion script'
    'version:Show version'
    'help:Show help message'
  )

  local -a voices hooks_cmds personality_cmds hook_events shells
  hooks_cmds=('install' 'uninstall' 'enable' 'disable' 'status')
  personality_cmds=('install' 'uninstall')
  hook_events=('SessionStart' 'Stop' 'Notification' 'PreToolUse' 'PostToolUse' 'PostToolUseFailure' 'SessionEnd' 'PreCompact')
  shells=('bash' 'zsh')

  _arguments '1:command:->cmds' '*:arg:->args'

  local voices_dir="${VOX_MACHINA_HOME:-$HOME/.vox-machina}/voices"

  case "$state" in
    cmds)
      _describe 'command' commands
      ;;
    args)
      case "${words[2]}" in
        use|uninstall|preview|update)
          if [[ -d "$voices_dir" ]]; then
            voices=( $(ls "$voices_dir" 2>/dev/null) )
            compadd -a voices
          fi
          ;;
        play)
          compadd -a hook_events
          ;;
        hooks)
          if (( CURRENT == 3 )); then
            compadd -a hooks_cmds
          elif (( CURRENT == 4 )) && [[ "${words[3]}" == (enable|disable) ]]; then
            compadd -a hook_events
          fi
          ;;
        personality)
          compadd -a personality_cmds
          ;;
        completions)
          compadd -a shells
          ;;
      esac
      ;;
  esac
}

_vox_machina "$@"
ZSH_COMP
      ;;
    *)
      error "Supported shells: bash, zsh"
      exit 1
      ;;
  esac
}

cmd_help() {
  cat <<EOF
${_BOLD}vox-machina${_RESET} v${VERSION} - Playful AI voice packs for Claude Code hooks

${_BOLD}Usage:${_RESET}
  vox-machina <command> [args]

${_BOLD}Commands:${_RESET}
  init <name>            Create a voice definition template
  install <voice|path>   Install a voice pack (from GitHub Release or local folder)
  uninstall <voice>      Remove an installed voice pack
  update <voice>         Update an installed voice pack from GitHub
  use <voice>            Set the active voice pack
  list                   List installed voice packs
  preview <voice>        Play a random clip from a voice pack
  play <hook>            Play a random clip for a hook event
  generate <voice.json>  Generate audio files from a voice definition
  mute                   Silence all voice playback
  unmute                 Re-enable voice playback
  volume [0-100]         Get or set playback volume
  cooldown [seconds|off] Get or set minimum seconds between clips
  status                 Show current voice, volume, and mute state
  hooks install          Add vox-machina hooks to Claude Code settings
  hooks uninstall        Remove vox-machina hooks from Claude Code settings
  hooks enable <event>   Enable playback for a hook event
  hooks disable <event>  Disable playback for a hook event
  hooks status           Show enabled/disabled state for all hooks
  personality install    Add voice personality to ~/.claude/CLAUDE.md
  personality uninstall  Remove voice personality from ~/.claude/CLAUDE.md
  completions <shell>    Output tab completion script (bash, zsh)
  version                Show version number
  help                   Show this help message

${_BOLD}Hook Events:${_RESET}
  SessionStart, Stop, Notification, PreToolUse, PostToolUse,
  PostToolUseFailure, SessionEnd, PreCompact

${_BOLD}Custom Voice Packs:${_RESET}
  Create a folder with audio files organized by hook:

    my-voice/
    ├── SessionStart/
    │   ├── 01.wav
    │   └── 02.mp3
    ├── Stop/
    ├── Notification/
    ├── PreToolUse/
    ├── PostToolUse/
    ├── PostToolUseFailure/
    ├── SessionEnd/
    └── PreCompact/

  Then install it:
    vox-machina install ./my-voice

${_BOLD}Tab Completion:${_RESET}
  bash: eval "\$(vox-machina completions bash)"
  zsh:  eval "\$(vox-machina completions zsh)"
EOF
}

# --- Main ---

mkdir -p "$VOX_HOME" "$VOICES_DIR"
[[ -f "$CONFIG_FILE" ]] || echo '{}' > "$CONFIG_FILE"

case "${1:-help}" in
  play)        cmd_play "${2:-}" ;;
  init)        cmd_init "${2:-}" ;;
  generate)    cmd_generate "${2:-}" "${3:-}" "${4:-}" ;;
  use)         cmd_use "${2:-}" ;;
  list)        cmd_list ;;
  mute)        cmd_mute ;;
  unmute)      cmd_unmute ;;
  volume)      cmd_volume "${2:-}" ;;
  cooldown)    cmd_cooldown "${2:-}" ;;
  status)      cmd_status ;;
  preview)     cmd_preview "${2:-}" ;;
  install)     cmd_install_voice "${2:-}" ;;
  uninstall)   cmd_uninstall_voice "${2:-}" ;;
  update)      cmd_update_voice "${2:-}" ;;
  hooks)
    case "${2:-}" in
      install)   cmd_hooks_install ;;
      uninstall) cmd_hooks_uninstall ;;
      enable)    cmd_hooks_enable "${3:-}" ;;
      disable)   cmd_hooks_disable "${3:-}" ;;
      status)    cmd_hooks_status ;;
      *)         error "Usage: vox-machina hooks [install|uninstall|enable|disable|status]"; exit 1 ;;
    esac
    ;;
  personality)
    case "${2:-}" in
      install)   cmd_personality_install ;;
      uninstall) cmd_personality_uninstall ;;
      *)         error "Usage: vox-machina personality [install|uninstall]"; exit 1 ;;
    esac
    ;;
  completions) cmd_completions "${2:-}" ;;
  version|--version) echo "vox-machina ${VERSION}" ;;
  help|--help|-h) cmd_help ;;
  *)           error "Unknown command: $1. Run 'vox-machina help' for usage."; exit 1 ;;
esac
