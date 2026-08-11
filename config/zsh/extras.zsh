# ============================================================
#  furnizsh — optional extra commands
#  https://github.com/Wosmos/furnizsh
#
#  Kept separate from functions.zsh because most of these call an
#  external service. Skip them entirely with:
#      ./install.sh --no-extras
#
#  Nothing here sends anything private: the queries are command
#  names, city names and language names. `note` writes locally only.
# ============================================================

: ${FURNIZSH_C:=}   # populated by functions.zsh, which loads first

# Every command below needs the network. One shared check so the
# failure message is the same everywhere.
_ag_need_net() {
  command -v curl >/dev/null 2>&1 || { print -u2 "$1: curl not found"; return 1 }
  return 0
}

# ============================================================
#  weather [location] — forecast in the terminal (wttr.in)
#  With no argument wttr.in geolocates by IP.
# ============================================================
weather() {
  _ag_need_net weather || return 1
  local where="${*:-}"
  curl -fsS --max-time 10 "https://wttr.in/${where// /+}?F" \
    || print -u2 "weather: could not reach wttr.in"
}

# ============================================================
#  cheat <command> — practical examples for any CLI tool (cheat.sh)
#  `cheat tar` beats reading tar's man page. tldr does this offline
#  if you installed the extended tool set.
# ============================================================
cheat() {
  if [[ -z "${1:-}" ]]; then
    print -u2 "usage: cheat <command> [subtopic]   e.g. cheat tar, cheat git/rebase"
    return 1
  fi
  _ag_need_net cheat || return 1

  local topic="${1}"
  shift
  # Extra words become a search within the topic, per cheat.sh's syntax.
  [[ $# -gt 0 ]] && topic="${topic}~${*// /+}"

  curl -fsS --max-time 10 "https://cheat.sh/${topic}" \
    || print -u2 "cheat: could not reach cheat.sh"
}

# ============================================================
#  qr <text> — render a QR code as terminal output (qrenco.de)
#  Handy for getting a localhost URL onto your phone.
# ============================================================
qr() {
  if [[ -z "${1:-}" ]]; then
    print -u2 "usage: qr <text-or-url>"
    return 1
  fi
  _ag_need_net qr || return 1
  curl -fsS --max-time 10 --data-urlencode "text=$*" https://qrenco.de/ \
    || print -u2 "qr: could not reach qrenco.de"
}

# ============================================================
#  gitignore <lang...> — fetch a .gitignore from toptal's generator
#  `gitignore node,macos` prints it; add -w to write the file.
# ============================================================
gitignore() {
  if [[ -z "${1:-}" ]]; then
    print -u2 "usage: gitignore [-w] <lang,lang,...>   e.g. gitignore node,macos,vscode"
    print -u2 "       -w writes ./.gitignore instead of printing"
    return 1
  fi
  _ag_need_net gitignore || return 1

  local write=0
  if [[ "$1" == "-w" ]]; then write=1; shift; fi

  local list="${*// /}"
  local body
  body=$(curl -fsSL --max-time 10 "https://www.toptal.com/developers/gitignore/api/${list}") \
    || { print -u2 "gitignore: could not reach the generator"; return 1 }

  if (( write )); then
    if [[ -e .gitignore ]]; then
      printf "%s.gitignore already exists — appending.%s\n" "$FURNIZSH_C[gray]" "$FURNIZSH_C[reset]"
      print -r -- "$body" >> .gitignore
    else
      print -r -- "$body" > .gitignore
    fi
    printf "%s✓%s wrote .gitignore (%s)\n" "$FURNIZSH_C[green]" "$FURNIZSH_C[reset]" "$list"
  else
    print -r -- "$body"
  fi
}

# ============================================================
#  note [text] — timestamped scratch notes, stored locally
#    note "fix the retry logic"   append a line
#    note                          open the file in $EDITOR
#    note -l                       print the last 20 lines
#  Location: $FURNIZSH_NOTES, default ~/.furnizsh-notes.md
# ============================================================
note() {
  local file="${FURNIZSH_NOTES:-$HOME/.furnizsh-notes.md}"
  [[ -f "$file" ]] || print -- "# notes\n" > "$file"

  case "${1:-}" in
    "")   ${EDITOR:-vi} "$file" ;;
    -l|--list)
      if command -v bat >/dev/null 2>&1; then bat --style=plain "$file" | tail -20
      else tail -20 "$file"; fi
      ;;
    *)
      printf -- "- %s  %s\n" "$(date '+%Y-%m-%d %H:%M')" "$*" >> "$file"
      printf "%s✓%s noted\n" "$FURNIZSH_C[green]" "$FURNIZSH_C[reset]"
      ;;
  esac
}

# ============================================================
#  timer <minutes> [label] — countdown, then a desktop notification
# ============================================================
timer() {
  local mins="${1:-}"
  if [[ ! "$mins" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    print -u2 "usage: timer <minutes> [label]   e.g. timer 25 pomodoro"
    return 1
  fi
  shift
  local label="${*:-timer}"
  local secs=$(( mins * 60 ))
  local end=$(( $(date +%s) + secs ))

  printf "%s%s%s — %s min. ctrl+c to cancel.%s\n" \
    "$FURNIZSH_C[bold]" "$label" "$FURNIZSH_C[reset]" "$mins" "$FURNIZSH_C[reset]"

  local left
  while (( (left = end - $(date +%s)) > 0 )); do
    printf "\r  %s%02d:%02d remaining%s " \
      "$FURNIZSH_C[gray]" $(( left / 60 )) $(( left % 60 )) "$FURNIZSH_C[reset]"
    sleep 1
  done
  printf "\r%s✓ %s done%s%-20s\n" "$FURNIZSH_C[green]" "$label" "$FURNIZSH_C[reset]" " "

  # Best-effort desktop notification, per platform.
  if [[ "$OSTYPE" == darwin* ]]; then
    osascript -e "display notification \"$label finished\" with title \"timer\" sound name \"Glass\"" 2>/dev/null
  elif command -v notify-send >/dev/null 2>&1; then
    notify-send "timer" "$label finished" 2>/dev/null
  fi
  printf '\a'
}

# ============================================================
#  sysinfo — a compact summary of the machine
# ============================================================
sysinfo() {
  local B=$FURNIZSH_C[bold] D=$FURNIZSH_C[reset]
  local Y=$FURNIZSH_C[yellow] G=$FURNIZSH_C[gray]

  _row() { printf "  %s%-12s%s %s\n" "$Y" "$1" "$D" "$2"; }

  printf "\n%s%ssysinfo%s\n\n" "$B" "$FURNIZSH_C[blue]" "$D"

  if [[ "$OSTYPE" == darwin* ]]; then
    _row "os"      "$(sw_vers -productName) $(sw_vers -productVersion) ($(uname -m))"
    _row "host"    "$(scutil --get ComputerName 2>/dev/null || hostname)"
    _row "cpu"     "$(sysctl -n machdep.cpu.brand_string 2>/dev/null)"
    _row "cores"   "$(sysctl -n hw.ncpu) logical"
    _row "memory"  "$(( $(sysctl -n hw.memsize) / 1073741824 )) GB"
    _row "uptime"  "$(uptime | sed 's/.*up \([^,]*\),.*/\1/')"
    _row "disk"    "$(df -h / | awk 'NR==2 {print $4" free of "$2}')"
  else
    _row "os"      "$(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME" || uname -o) ($(uname -m))"
    _row "kernel"  "$(uname -r)"
    _row "host"    "$(hostname)"
    _row "cpu"     "$(awk -F: '/model name/{print $2; exit}' /proc/cpuinfo 2>/dev/null | sed 's/^ *//')"
    _row "cores"   "$(nproc 2>/dev/null) logical"
    _row "memory"  "$(free -h 2>/dev/null | awk 'NR==2 {print $3" used of "$2}')"
    _row "uptime"  "$(uptime -p 2>/dev/null | sed 's/^up //')"
    _row "disk"    "$(df -h / | awk 'NR==2 {print $4" free of "$2}')"
  fi

  _row "shell"   "zsh $ZSH_VERSION"
  _row "term"    "${TERM_PROGRAM:-$TERM}"
  _row "theme"   "$(_furnizsh_current_theme)"

  unfunction _row
  printf "\n"
}

# ============================================================
#  dockerclean — reclaim disk from docker, showing the total first
# ============================================================
dockerclean() {
  command -v docker >/dev/null 2>&1 || { print -u2 "dockerclean: docker not installed"; return 1 }
  docker info >/dev/null 2>&1 || { print -u2 "dockerclean: docker isn't running"; return 1 }

  printf "\n%sCurrent usage%s\n" "$FURNIZSH_C[bold]" "$FURNIZSH_C[reset]"
  docker system df

  printf "\n%sThis removes stopped containers, unused networks, dangling images and build cache.%s\n" \
    "$FURNIZSH_C[gray]" "$FURNIZSH_C[reset]"
  printf "%sNamed volumes are NOT touched — your database data is safe.%s\n" \
    "$FURNIZSH_C[gray]" "$FURNIZSH_C[reset]"
  printf "\nProceed? [y/N] "
  local reply; read -r reply
  [[ "$reply" == [yY]* ]] || { printf "Aborted.\n"; return 0 }

  docker system prune -f
  printf "\n%s✓%s done\n\n" "$FURNIZSH_C[green]" "$FURNIZSH_C[reset]"
}
