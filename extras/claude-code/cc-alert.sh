#!/bin/bash
# Claude Code OS alert — works on any Mac, any project. macOS built-ins only
# (osascript JXA, open, afplay, say) — no jq/brew dependencies.
#
# HOOK MODE (Claude Code pipes event JSON on stdin — wire in settings.json):
#   Stop          → "✅ Finished" alert, only if the turn ran longer than
#                   CC_ALERT_MIN_SECONDS (default 90) so quick replies don't spam.
#   Notification  → "🔐 needs permission" / "⏳ waiting for input" alert, rate-limited
#                   (see CC_ALERT_COOLDOWN) unless it's flagged destructive/priority.
#   The dialog shows: project name, status, tool/command detail (permission
#   notifications), a one-line summary of your last prompt, how long you were
#   away, and an "Open Project" button that jumps to the exact editor window
#   for that folder (open -a reuses the already-open window).
#
# MANUAL MODE: cc-alert.sh "<title>" "<message>" "<spoken phrase>"
#
# Env overrides (set inline, or in ~/.claude/hooks/cc-alert.env for machine-wide
# defaults, or <project>/.claude/cc-alert.env for a per-project override):
#   CC_ALERT_MIN_SECONDS      min Stop turn duration to alert on (default 90)
#   CC_ALERT_APP              editor app name for "Open Project"
#   CC_ALERT_SILENT=1         no voice
#   CC_ALERT_DRYRUN=1         print instead of showing UI
#   CC_ALERT_ALWAYS=1         alert even if you're looking right at the terminal
#   CC_ALERT_SOUND_STOP       sound for Stop alerts (default Glass)
#   CC_ALERT_SOUND_NOTIFY     sound for routine Notification alerts (default Sosumi)
#   CC_ALERT_SOUND_PRIORITY   sound for destructive-action alerts (default Basso)
#   CC_ALERT_VOICE            `say -v` voice name (default: system default voice)
#   CC_ALERT_COOLDOWN         seconds between routine Notification alerts (default 20)
#   CC_ALERT_SUGGEST_THRESHOLD repeat count before suggesting a permissions.allow rule (default 3)
#   CC_ALERT_QUIET_START/END  HH:MM 24h window to suppress Stop alerts and mute
#                             routine Notification alerts (both unset = feature off)
#
# Persistent files: ~/.claude/hooks/cc-alert.log (every alert fired),
#                    ~/.claude/hooks/.cc-alert-freq (repeated-permission counts)

set -u

# ---------- install / uninstall into a project's local settings ----------
# Usage (run inside a project):  cc-alert.sh --install [path-to-settings.local.json]
#                                cc-alert.sh --uninstall [path]
if [ "${1:-}" = "--install" ] || [ "${1:-}" = "--uninstall" ]; then
  MODE="$1"
  TARGET="${2:-$PWD/.claude/settings.local.json}"
  python3 - "$MODE" "$TARGET" <<'PY'
import json, sys, os
mode, target = sys.argv[1], sys.argv[2]
os.makedirs(os.path.dirname(target), exist_ok=True)
try:
    with open(target) as f: cfg = json.load(f)
except Exception: cfg = {}
hooks = cfg.setdefault("hooks", {})
def has(ev):
    return any("cc-alert.sh" in h.get("command","")
               for grp in hooks.get(ev, []) for h in grp.get("hooks", []))
if mode == "--install":
    for ev in ("Stop", "Notification"):
        if not has(ev):
            hooks.setdefault(ev, []).append(
                {"matcher": "", "hooks": [
                    {"type": "command", "command": "~/.claude/hooks/cc-alert.sh", "timeout": 15}]})
    msg = "installed"
else:
    for ev in ("Stop", "Notification"):
        for grp in hooks.get(ev, []):
            grp["hooks"] = [h for h in grp.get("hooks", []) if "cc-alert.sh" not in h.get("command","")]
        hooks[ev] = [g for g in hooks.get(ev, []) if g.get("hooks")]
        if not hooks.get(ev): hooks.pop(ev, None)
    if not hooks: cfg.pop("hooks", None)
    msg = "removed"
with open(target, "w") as f:
    json.dump(cfg, f, indent=2); f.write("\n")
print(f"{msg} cc-alert hooks -> {target}")
print("Restart the session (or check /hooks) to activate.")
PY
  exit 0
fi

MIN_SECONDS="${CC_ALERT_MIN_SECONDS:-90}"

DIALOG_JS='function run(argv){
  const app=Application.currentApplication();app.includeStandardAdditions=true;
  const [title,body,icon,mode]=argv;
  const opts={withTitle:title,givingUpAfter:120};
  if(mode==="open"){opts.buttons=["Dismiss","Open Project"];opts.defaultButton="Open Project";}
  else{opts.buttons=["OK"];opts.defaultButton="OK";}
  if(icon){try{opts.withIcon=Path(icon);}catch(e){}}
  try{const r=app.displayDialog(body,opts);return r.gaveUp?"":String(r.buttonReturned);}
  catch(e){return "";}
}'

# Walks a dot path (e.g. "tool_input.command"); a single segment behaves
# exactly like the old flat lookup, so every existing jget call is unaffected.
JGET='function run(a){try{let j=JSON.parse(a[0]);for(const p of a[1].split(".")){if(j==null)return "";j=j[p];}return j==null?"":String(j);}catch(e){return "";}}'

# Last human prompt (skips tool results, meta lines, <command>/<ide> wrappers).
PROMPT_JS='function run(argv){
  for(let i=argv.length-1;i>=0;i--){
    try{
      const j=JSON.parse(argv[i]);
      if(j.type!=="user"||!j.message)continue;
      let c=j.message.content,t="";
      if(typeof c==="string")t=c;
      else if(Array.isArray(c)){t=c.filter(p=>p.type==="text").map(p=>p.text).join(" ");}
      t=(t||"")
        .replace(/<(command|local-command)-[a-z-]+>[\s\S]*?<\/\1-[a-z-]+>/g,"")
        .replace(/<(ide_opened_file|ide_selection|system-reminder|task-notification)>[\s\S]*?<\/\1>/g,"")
        .trim();
      if(!t||t.startsWith("<"))continue;
      t=t.replace(/\s+/g," ");
      if(t.length>160)t=t.slice(0,160)+"…";
      return t+"|||"+(j.timestamp||"");
    }catch(e){}
  }
  return "|||";
}'

icon_path() {
  for i in "/Applications/Visual Studio Code.app/Contents/Resources/Code.icns" \
           "/Applications/Cursor.app/Contents/Resources/Cursor.icns" \
           "/Applications/Claude.app/Contents/Resources/electron.icns"; do
    [ -f "$i" ] && printf '%s' "$i" && return
  done
}

editor_app() {
  if [ -n "${CC_ALERT_APP:-}" ]; then printf '%s' "$CC_ALERT_APP"; return; fi
  [ -d "/Applications/Visual Studio Code.app" ] && printf 'Visual Studio Code' && return
  [ -d "/Applications/Cursor.app" ] && printf 'Cursor' && return
  printf 'Terminal'
}

# True when the app the user is CURRENTLY looking at is the editor/terminal that
# hosts the Claude session — i.e. they're present, so an alert would just nag.
# lsappinfo needs no Accessibility permission; osascript is a fallback.
editor_is_frontmost() {
  local front=''
  front="$(lsappinfo info -only name "$(lsappinfo front 2>/dev/null)" 2>/dev/null \
    | sed -n 's/^"LSDisplayName"="\(.*\)"$/\1/p')"
  [ -z "$front" ] && front="$(osascript -e \
    'tell application "System Events" to get name of first process whose frontmost is true' 2>/dev/null)"
  case "$front" in
    Code|'Code - Insiders'|Cursor|Windsurf|Electron|Terminal|iTerm2|WezTerm|Alacritty|kitty|Hyper|Ghostty)
      return 0 ;;
    *) return 1 ;;
  esac
}

# Self-contained "don't bug me right now" window — no dependency on macOS
# Focus/DND internals (those have no stable public API and a false positive
# there would silently swallow real alerts, which is worse than no feature).
in_quiet_hours() {
  [ -n "${CC_ALERT_QUIET_START:-}" ] && [ -n "${CC_ALERT_QUIET_END:-}" ] || return 1
  local now start end
  now="$(date +%H%M)"
  start="${CC_ALERT_QUIET_START/:/}"
  end="${CC_ALERT_QUIET_END/:/}"
  if [ "$start" -le "$end" ] 2>/dev/null; then
    [ "$now" -ge "$start" ] && [ "$now" -lt "$end" ]
  else
    [ "$now" -ge "$start" ] || [ "$now" -lt "$end" ]
  fi
}

# Fixed pattern list for "this permission request is dangerous enough to
# always alert regardless of cooldown/quiet-hours". Edit the regex to extend.
is_destructive() {
  local cmd="${1:-}"
  [ -z "$cmd" ] && return 1
  printf '%s' "$cmd" | grep -qiE 'rm +-[a-z]*r[a-z]*f|rm +-[a-z]*f[a-z]*r|git +push[^|]*--force|git +reset +--hard|drop +table|truncate|dd +if=|mkfs'
}

# Increment-or-create a hash's count in the frequency file; prints new count.
# Never fails the caller — any error path still prints a usable count.
freq_bump() {
  local file="$HOME/.claude/hooks/.cc-alert-freq" hash="$1" count tmp
  mkdir -p "$(dirname "$file")" 2>/dev/null
  count="$(awk -F'\t' -v h="$hash" '$1==h{print $2; f=1} END{if(!f) print 0}' "$file" 2>/dev/null)"
  [ -z "$count" ] && count=0
  count=$(( count + 1 ))
  tmp="$(mktemp 2>/dev/null || printf '%s' "$file.tmp")"
  if [ -f "$file" ]; then
    awk -F'\t' -v h="$hash" -v c="$count" '$1==h{print h"\t"c; done=1; next} {print} END{if(!done) print h"\t"c}' "$file" > "$tmp" 2>/dev/null \
      && mv "$tmp" "$file" 2>/dev/null
  else
    printf '%s\t%s\n' "$hash" "$count" > "$file" 2>/dev/null
  fi
  printf '%s' "$count"
}

fire_ui() { # $1 title  $2 body  $3 spoken  $4 sound  $5 mode(open|ok)  $6 cwd
  if [ "${CC_ALERT_DRYRUN:-}" = "1" ]; then
    printf 'DRYRUN\ntitle: %s\nbody: %s\nspoken: %s\nsound: %s\nmode: %s\ncwd: %s\n' "$1" "$2" "$3" "$4" "$5" "$6"
    return
  fi
  (
    [ -n "$4" ] && afplay "/System/Library/Sounds/$4.aiff" >/dev/null 2>&1 &
    [ "${CC_ALERT_SILENT:-}" = "1" ] || say ${CC_ALERT_VOICE:+-v "$CC_ALERT_VOICE"} "$3" >/dev/null 2>&1 &
    BTN="$(osascript -l JavaScript -e "$DIALOG_JS" "$1" "$2" "$(icon_path)" "$5" 2>/dev/null)"
    if [ "$BTN" = "Open Project" ] && [ -n "$6" ]; then
      open -a "$(editor_app)" "$6" >/dev/null 2>&1 || open "$6" >/dev/null 2>&1
    fi
  ) </dev/null >/dev/null 2>&1 &
  disown 2>/dev/null || true
}

# ---------- manual mode ----------
if [ -t 0 ] || [ $# -gt 0 ]; then
  fire_ui "${1:-Claude Code}" "${2:-Done.}" "${3:-Claude is done}" "Glass" "ok" ""
  exit 0
fi

# ---------- hook mode ----------
PAYLOAD="$(cat)"
[ -z "$PAYLOAD" ] && exit 0
jget() { osascript -l JavaScript -e "$JGET" "$PAYLOAD" "$1" 2>/dev/null; }

EVENT="$(jget hook_event_name)"
CWD="$(jget cwd)"
TRANSCRIPT="$(jget transcript_path)"
NOTE_MSG="$(jget message)"
NOTE_TYPE="$(jget notification_type)"
SESSION_ID="$(jget session_id)"
PROJECT="$(basename "${CWD:-unknown}")"

# Machine-wide defaults, then a per-project override — both optional, both
# plain KEY=value shell files. A broken config file is ignored, not fatal.
[ -f "$HOME/.claude/hooks/cc-alert.env" ] && . "$HOME/.claude/hooks/cc-alert.env" 2>/dev/null
[ -n "${CWD:-}" ] && [ -f "$CWD/.claude/cc-alert.env" ] && . "$CWD/.claude/cc-alert.env" 2>/dev/null

KEY="$(printf '%s' "${SESSION_ID:-$CWD}" | md5 2>/dev/null)"
[ -z "$KEY" ] && KEY="fallback"
LASTSEEN_FILE="/tmp/.cc-alert-lastseen-$KEY"
COOLDOWN_FILE="/tmp/.cc-alert-cooldown-$KEY"

SUMMARY="" ; TS=""
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  set --
  while IFS= read -r line; do set -- "$@" "$line"; done < <(
    grep '"type":"user"' "$TRANSCRIPT" 2>/dev/null |
      grep -v '"tool_use_id"' | grep -v '"isMeta":true' |
      awk 'length < 8000' | tail -8
  )
  if [ $# -gt 0 ]; then
    R="$(osascript -l JavaScript -e "$PROMPT_JS" "$@" 2>/dev/null)"
    SUMMARY="${R%%|||*}"
    TS="${R##*|||}"
  fi
fi

# If the user is looking right at the editor/terminal hosting this session,
# they don't need a popup — they can see the result. Only alert when they've
# switched away. CC_ALERT_ALWAYS=1 forces the alert regardless. Either way,
# record "last confirmed present" so a later alert can report how long you
# were actually gone.
if editor_is_frontmost; then
  date -u +%s > "$LASTSEEN_FILE" 2>/dev/null
  if [ "${CC_ALERT_ALWAYS:-}" != "1" ] && [ "${CC_ALERT_DRYRUN:-}" != "1" ]; then
    exit 0
  fi
fi

IS_PRIORITY=0

case "$EVENT" in
  Stop)
    # Skip quick turns — only alert when work ran long enough that the user
    # has plausibly moved to another window. No timestamp → alert anyway.
    if [ -n "$TS" ]; then
      EPOCH="$(date -ju -f '%Y-%m-%dT%H:%M:%S' "${TS%%.*}" +%s 2>/dev/null || echo 0)"
      if [ "$EPOCH" -gt 0 ]; then
        ELAPSED=$(( $(date -u +%s) - EPOCH ))
        [ "$ELAPSED" -lt "$MIN_SECONDS" ] && exit 0
      fi
    fi
    in_quiet_hours && exit 0
    STATUS="✅ Finished the task."
    SPOKEN="Claude finished in $PROJECT"
    SOUND="${CC_ALERT_SOUND_STOP:-Glass}"
    ;;
  Notification)
    TOOL_NAME="$(jget tool_name)"
    TOOL_CMD="$(jget tool_input.command)"
    TOOL_FILE="$(jget tool_input.file_path)"
    IS_PERMISSION=0

    # Classify by notification_type (documented values) first, fall back to
    # keyword-matching the free-text message.
    case "$NOTE_TYPE$NOTE_MSG" in
      *permission*) STATUS="🔐 Needs your permission — open the project to answer:"
                    SPOKEN="Claude needs permission in $PROJECT"
                    IS_PERMISSION=1 ;;
      *idle*|*needs_input*|*waiting*|*elicitation*)
                    STATUS="⏳ Waiting for your input:"
                    SPOKEN="Claude is waiting in $PROJECT" ;;
      *completed*)  STATUS="✅ Finished the task."
                    SPOKEN="Claude finished in $PROJECT" ;;
      *)            STATUS="🔔 Needs your attention:"
                    SPOKEN="Claude needs you in $PROJECT" ;;
    esac

    DETAIL=""
    if [ "$IS_PERMISSION" = "1" ]; then
      DETAIL="${TOOL_CMD:-${TOOL_FILE:-$TOOL_NAME}}"
      if is_destructive "$TOOL_CMD"; then
        IS_PRIORITY=1
        STATUS="⚠️ DESTRUCTIVE — $STATUS"
      fi
    fi

    QUIET_NOW=0
    if [ "$IS_PRIORITY" != "1" ]; then
      in_quiet_hours && QUIET_NOW=1
      LAST=0
      [ -f "$COOLDOWN_FILE" ] && LAST="$(cat "$COOLDOWN_FILE" 2>/dev/null || echo 0)"
      [ -z "$LAST" ] && LAST=0
      NOW_EPOCH="$(date -u +%s)"
      if [ $(( NOW_EPOCH - LAST )) -lt "${CC_ALERT_COOLDOWN:-20}" ]; then
        exit 0
      fi
      printf '%s' "$NOW_EPOCH" > "$COOLDOWN_FILE" 2>/dev/null
    fi

    [ -n "$NOTE_MSG" ] && STATUS="$STATUS
$NOTE_MSG"
    [ -n "$DETAIL" ] && STATUS="$STATUS
Detail: $DETAIL"

    if [ "$IS_PERMISSION" = "1" ] && [ -n "$DETAIL" ]; then
      SIG="$TOOL_NAME:$(printf '%s' "$DETAIL" | cut -c1-40)"
      SIGHASH="$(printf '%s' "$SIG" | md5 2>/dev/null)"
      if [ -n "$SIGHASH" ]; then
        COUNT="$(freq_bump "$SIGHASH")"
        if [ "${COUNT:-0}" -ge "${CC_ALERT_SUGGEST_THRESHOLD:-3}" ] 2>/dev/null; then
          STATUS="$STATUS
💡 Asked ${COUNT}x — consider adding \"$DETAIL\" to permissions.allow."
        fi
      fi
    fi

    if [ "$IS_PRIORITY" = "1" ]; then
      SOUND="${CC_ALERT_SOUND_PRIORITY:-Basso}"
    elif [ "$QUIET_NOW" = "1" ]; then
      SOUND=""
      CC_ALERT_SILENT=1
    else
      SOUND="${CC_ALERT_SOUND_NOTIFY:-Sosumi}"
    fi
    ;;
  *) exit 0 ;;
esac

BODY="📁 $PROJECT
$STATUS"
[ -n "$SUMMARY" ] && BODY="$BODY

Your last ask: \"$SUMMARY\""

if [ -f "$LASTSEEN_FILE" ]; then
  LASTSEEN_EPOCH="$(cat "$LASTSEEN_FILE" 2>/dev/null || echo 0)"
  [ -z "$LASTSEEN_EPOCH" ] && LASTSEEN_EPOCH=0
  if [ "$LASTSEEN_EPOCH" -gt 0 ] 2>/dev/null; then
    AWAY_M=$(( ( $(date -u +%s) - LASTSEEN_EPOCH ) / 60 ))
    [ "$AWAY_M" -gt 0 ] && BODY="$BODY

🕐 You were away ~${AWAY_M}m"
  fi
fi

BODY="$BODY

$CWD"

STATUS_ONELINE="$(printf '%s' "$STATUS" | tr '\n' ' ')"
printf '%s\t%s\t%s\t%s\n' "$(date -u +%FT%TZ)" "$EVENT" "$PROJECT" "$STATUS_ONELINE" >> "$HOME/.claude/hooks/cc-alert.log" 2>/dev/null

fire_ui "Claude — $PROJECT" "$BODY" "$SPOKEN" "$SOUND" "open" "$CWD"
exit 0
