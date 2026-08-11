#!/bin/bash
# Claude Code statusline — live session data from stdin.
input=$(cat)

j() { echo "$input" | jq -r "$1"; }

model=$(j '.model.display_name // "?"')
style=$(j '.output_style.name // "default"')
pct=$(j '.context_window.used_percentage // 0')
cwd=$(j '.workspace.current_dir // .cwd')
effort=$(j '.effort.level // empty')
cost=$(j '.cost.total_cost_usd // empty')
lines_add=$(j '.cost.total_lines_added // 0')
lines_del=$(j '.cost.total_lines_removed // 0')
rl5=$(j '.rate_limits.five_hour.used_percentage // empty')
rl5_reset=$(j '.rate_limits.five_hour.resets_at // empty')
rl7=$(j '.rate_limits.seven_day.used_percentage // empty')
rl7_reset=$(j '.rate_limits.seven_day.resets_at // empty')
think=$(j '.thinking.enabled // false')
fast=$(j '.fast_mode // false')

s="$HOME/.claude/settings.json"; sl="$HOME/.claude/settings.local.json"
[ -n "$effort" ] || effort=$(jq -r '.effortLevel // empty' "$sl" 2>/dev/null)
[ -n "$effort" ] || effort=$(jq -r '.effortLevel // "default"' "$s" 2>/dev/null)

branch=$(git -C "$cwd" branch --show-current 2>/dev/null)

# repo name; if the cwd is a linked worktree (git-dir != git-common-dir), label it as worktree instead
repo_label=""; repo_name=""
toplevel=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)
if [ -n "$toplevel" ]; then
  gitdir=$(git -C "$cwd" rev-parse --git-dir 2>/dev/null)
  commondir=$(git -C "$cwd" rev-parse --git-common-dir 2>/dev/null)
  repo_name=$(basename "$toplevel")
  if [ -n "$gitdir" ] && [ "$gitdir" != "$commondir" ]; then repo_label="worktree"; else repo_label="repo"; fi
fi

# epoch → "2h23m" countdown
countdown() {
  local secs=$(( ${1%.*} - $(date +%s) )); [ "$secs" -lt 0 ] && secs=0
  echo "$((secs / 3600))h$(( (secs % 3600) / 60 ))m"
}
# usage % → block-character progress bar, e.g. ██████░░░░
bar() {
  local v=${1%.*}; [ -n "$v" ] || v=0
  local width=10
  local filled=$(( v * width / 100 )); [ "$filled" -gt "$width" ] && filled=$width
  local empty=$(( width - filled ))
  local s=""; local i
  for ((i=0; i<filled; i++)); do s+="█"; done
  for ((i=0; i<empty; i++)); do s+="░"; done
  echo "$s"
}

R=$'\033[0m'; DIM=$'\033[90m'; GREEN=$'\033[38;2;80;200;120m'; RED=$'\033[31m'; SEP=" ${DIM}│${R} "

line1="${DIM}✦ $model$R"
line1+="$SEP${DIM}⚡$effort$R"
[ "$style" != "default" ] && line1+="$SEP${DIM}✎ $style$R"
[ "$fast" = "true" ] && line1+="$SEP${DIM}🚀 fast$R"
[ "$think" = "true" ] && line1+="$SEP${DIM}🧠 think$R"
line1+="$SEP${DIM}context: ${pct%.*}%$R"
[ -n "$cost" ] && line1+="$SEP${DIM}\$$(printf '%.2f' "$cost")$R"
[ -n "$repo_name" ] && line1+="$SEP${GREEN}$repo_label: ${DIM}$repo_name$R"
[ -n "$branch" ] && line1+="$SEP${GREEN}branch: ${DIM}$branch$R"
[ "$lines_add" != "0" ] || [ "$lines_del" != "0" ] && line1+="$SEP${GREEN}+$lines_add$R $RED-$lines_del$R"
echo "$line1"

# lines 2-3: usage limits (session 5h + weekly 7d), matching claude.ai usage page, on separate lines
if [ -n "$rl5" ] || [ -n "$rl7" ]; then
  echo ""
  echo ""
fi
if [ -n "$rl5" ]; then
  line2="${RED}5 hour limit:  ${DIM}$(bar "$rl5") ${rl5%.*}%$R"
  [ -n "$rl5_reset" ] && line2+=" ${DIM}(resets in $(countdown "$rl5_reset"))$R"
  echo "$line2"
fi
# per-model weekly breakdown — undocumented Anthropic usage API (same one ccstatusline uses),
# not part of the documented statusline JSON. Cached 150s / 30s failure backoff to avoid a
# network call on every message.
if [ -n "$rl7" ]; then
  usage_dir="$HOME/.cache/ai-statusline"; usage_cache="$usage_dir/weekly-usage.json"; usage_lock="$usage_dir/weekly-usage.lock"
  mkdir -p "$usage_dir" 2>/dev/null
  file_age() { [ -f "$1" ] || { echo 999999; return; }; echo $(( $(date +%s) - $(stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0) )); }

  if [ "$(file_age "$usage_cache")" -gt 150 ] && [ "$(file_age "$usage_lock")" -gt 30 ]; then
    usage_token=""
    [ "$(uname)" = "Darwin" ] && usage_token=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
    [ -n "$usage_token" ] || usage_token=$(jq -r '.claudeAiOauth.accessToken // empty' "$HOME/.claude/.credentials.json" 2>/dev/null)
    if [ -n "$usage_token" ]; then
      usage_resp=$(curl -s --max-time 4 -H "Authorization: Bearer $usage_token" -H "anthropic-beta: oauth-2025-04-20" "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)
      if [ -n "$usage_resp" ] && echo "$usage_resp" | jq -e '.limits' >/dev/null 2>&1; then
        echo "$usage_resp" > "$usage_cache"; rm -f "$usage_lock"
      else
        touch "$usage_lock"
      fi
    else
      touch "$usage_lock"
    fi
  fi

  if [ -f "$usage_cache" ]; then
    while IFS=$'\t' read -r mname mpct mreset; do
      [ -n "$mname" ] || continue
      label=$(printf '%-15s' "$mname limit:")
      line_model="${RED}$label${DIM}$(bar "$mpct") ${mpct}%$R"
      reset_epoch=$([ -n "$mreset" ] && python3 -c "import datetime,sys; print(int(datetime.datetime.fromisoformat(sys.argv[1]).timestamp()))" "$mreset" 2>/dev/null)
      [ -n "$reset_epoch" ] && line_model+=" ${DIM}(resets $(date -r "$reset_epoch" '+%a %-I:%M %p' 2>/dev/null))$R"
      echo "$line_model"
    done < <(jq -r '.limits[]? | select(.kind=="weekly_scoped") | [(.scope.model.display_name // "?"), (.percent|tostring), (.resets_at // "")] | @tsv' "$usage_cache" 2>/dev/null)
  fi
fi

if [ -n "$rl7" ]; then
  line3="${RED}weekly limit:  ${DIM}$(bar "$rl7") ${rl7%.*}%$R"
  [ -n "$rl7_reset" ] && line3+=" ${DIM}(resets $(date -r "${rl7_reset%.*}" '+%a %-I:%M %p' 2>/dev/null))$R"
  echo "$line3"
fi

if [ -n "$rl5" ] || [ -n "$rl7" ]; then
  echo ""
  echo ""
fi
