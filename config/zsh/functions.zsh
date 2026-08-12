# ============================================================
#  furnizsh — core helper commands
#  https://github.com/Wosmos/furnizsh
#
#  Sourced by furnizsh.zsh. Full reference: docs/COMMANDS.md
#  Optional network-dependent extras live in extras.zsh.
# ============================================================

# Where the installed copy lives. furnizsh.zsh sets this; the fallback
# keeps this file usable if it's sourced on its own.
: ${FURNIZSH_DIR:="$HOME/.config/furnizsh"}

# ------------------------------------------------------------
# Shared palette. Truecolor escapes — orange/yellow accents, no red.
# ------------------------------------------------------------
typeset -gA FURNIZSH_C=(
  bold   $'\033[1m'
  reset  $'\033[0m'
  orange $'\033[38;2;250;179;135m'
  yellow $'\033[38;2;249;226;175m'
  blue   $'\033[38;2;137;180;250m'
  green  $'\033[38;2;166;227;161m'
  mauve  $'\033[38;2;203;166;247m'
  gray   $'\033[38;2;108;112;134m'
  text   $'\033[38;2;205;214;244m'
)

# Installed version, stamped by install.sh. Empty on a dev checkout.
_furnizsh_version() {
  if [[ -f "$FURNIZSH_DIR/VERSION" ]]; then
    cat "$FURNIZSH_DIR/VERSION"
  else
    print -n "dev"
  fi
}

# Name of the active theme, for the cheatsheet and doctor output.
_furnizsh_current_theme() {
  if [[ -f "$FURNIZSH_DIR/current-theme" ]]; then
    cat "$FURNIZSH_DIR/current-theme"
  else
    print -n "neon"
  fi
}

# ============================================================
#  theme — switch the whole look in one command
#  Changes Ghostty, Starship and lazygit together, so they can
#  never drift out of sync.
# ============================================================
theme() {
  local C=$FURNIZSH_C[reset] B=$FURNIZSH_C[bold]
  local ORANGE=$FURNIZSH_C[orange] YELLOW=$FURNIZSH_C[yellow]
  local GREEN=$FURNIZSH_C[green] GRAY=$FURNIZSH_C[gray] BLUE=$FURNIZSH_C[blue]
  local themes_dir="$FURNIZSH_DIR/themes"

  if [[ ! -d "$themes_dir" ]]; then
    print -u2 "theme: no themes installed at $themes_dir — rerun ./install.sh"
    return 1
  fi

  local current="$(_furnizsh_current_theme)"

  # No argument: show what's active and what's available.
  if [[ -z "${1:-}" ]]; then
    printf "\n%s%sThemes%s  %s(theme <name> to switch)%s\n\n" "$B" "$BLUE" "$C" "$GRAY" "$C"
    local f id label blurb
    for f in "$themes_dir"/*.theme(N); do
      id="${${f:t}%.theme}"
      label="$(sed -n 's/^THEME_LABEL="\(.*\)"/\1/p' "$f")"
      blurb="$(sed -n 's/^THEME_BLURB="\(.*\)"/\1/p' "$f")"
      if [[ "$id" == "$current" ]]; then
        printf "  %s●%s %s%-12s%s %-20s %s%s%s\n" "$GREEN" "$C" "$B" "$id" "$C" "$label" "$GRAY" "$blurb" "$C"
      else
        printf "  %s○%s %s%-12s%s %-20s %s%s%s\n" "$GRAY" "$C" "$YELLOW" "$id" "$C" "$label" "$GRAY" "$blurb" "$C"
      fi
    done
    printf "\n"
    return 0
  fi

  local want="$1"
  local theme_file="$themes_dir/$want.theme"
  if [[ ! -f "$theme_file" ]]; then
    print -u2 "theme: unknown theme '$want'. Run \`theme\` to list them."
    return 1
  fi

  # The .theme files are plain key=value shell — safe to source.
  local THEME_LABEL GHOSTTY_THEME STARSHIP_PRESET LAZYGIT_PALETTE
  source "$theme_file"

  printf "\n%sSwitching to %s%s%s\n" "$GRAY" "$B" "$THEME_LABEL" "$C"

  # --- Ghostty: replace only the theme line, keep the rest of the config ---
  local ghostty_cfg="$HOME/.config/ghostty/config"
  if [[ -f "$ghostty_cfg" ]]; then
    # Verify the theme exists on this Ghostty build before writing it —
    # names occasionally get re-cased between releases.
    if command -v ghostty >/dev/null 2>&1 &&
       ! ghostty +list-themes 2>/dev/null | grep -qiF "$GHOSTTY_THEME"; then
      printf "  %s!%s ghostty has no theme named '%s' — leaving its config alone\n" "$ORANGE" "$C" "$GHOSTTY_THEME"
    else
      local tmp="$(mktemp)"
      sed "s|^theme = .*|theme = $GHOSTTY_THEME|" "$ghostty_cfg" > "$tmp" && mv "$tmp" "$ghostty_cfg"
      printf "  %s✓%s ghostty  %s%s%s\n" "$GREEN" "$C" "$GRAY" "$GHOSTTY_THEME" "$C"
    fi
  fi

  # --- Starship: regenerate from the preset ---
  if command -v starship >/dev/null 2>&1; then
    # --force is required: starship refuses to overwrite an existing config,
    # and starship.toml always exists by the time anyone switches themes.
    if starship preset "$STARSHIP_PRESET" --force -o "$HOME/.config/starship.toml" 2>/dev/null; then
      printf "  %s✓%s starship %s%s%s\n" "$GREEN" "$C" "$GRAY" "$STARSHIP_PRESET" "$C"
    else
      printf "  %s!%s starship has no preset '%s' — prompt unchanged\n" "$ORANGE" "$C" "$STARSHIP_PRESET"
    fi
  fi

  # --- lazygit ---
  local lg_src="$themes_dir/lazygit/$LAZYGIT_PALETTE.yml"
  if [[ -f "$lg_src" ]]; then
    local lg_dir
    if command -v lazygit >/dev/null 2>&1; then
      lg_dir="$(lazygit --print-config-dir 2>/dev/null)"
    fi
    if [[ -z "$lg_dir" ]]; then
      [[ "$OSTYPE" == darwin* ]] \
        && lg_dir="$HOME/Library/Application Support/lazygit" \
        || lg_dir="${XDG_CONFIG_HOME:-$HOME/.config}/lazygit"
    fi
    mkdir -p "$lg_dir" && cp "$lg_src" "$lg_dir/config.yml"
    printf "  %s✓%s lazygit  %s%s%s\n" "$GREEN" "$C" "$GRAY" "$LAZYGIT_PALETTE" "$C"
  fi

  print -n "$want" > "$FURNIZSH_DIR/current-theme"

  printf "\n%sGhostty reloads on save. Run %sreload%s%s for the new prompt.%s\n\n" \
    "$GRAY" "$YELLOW" "$C" "$GRAY" "$C"
}

# Completion for `theme <tab>`
_furnizsh_theme_complete() {
  local -a ids
  ids=(${${(f)"$(print -l $FURNIZSH_DIR/themes/*.theme(N:t:r))"}})
  compadd -- $ids
}
compdef _furnizsh_theme_complete theme 2>/dev/null

# ============================================================
#  agupdate — update furnizsh, whichever way it was installed
#
#  Thin wrapper over update.sh so the logic lives in exactly one place;
#  `furnizsh update` runs the same script.
# ============================================================
agupdate() {
  local script=""

  # Resolve update.sh directly, in preference to `furnizsh update`. The
  # dispatcher on PATH belongs to the *installed* version, and one from before
  # `update` existed answers "unknown command" — you would have to update
  # before you could update. update.sh ships beside this file, so it is always
  # the matching one.
  if [[ -n "${FURNIZSH_SHARE:-}" && -x "$FURNIZSH_SHARE/update.sh" ]]; then
    script="$FURNIZSH_SHARE/update.sh"
  elif [[ -f "$FURNIZSH_DIR/install-source" ]]; then
    local src=$(sed -n 2p "$FURNIZSH_DIR/install-source")
    [[ -x "$src/update.sh" ]] && script="$src/update.sh"
  fi

  # Only then the dispatcher, and only if it understands the subcommand.
  if [[ -z "$script" ]] && command -v furnizsh >/dev/null 2>&1; then
    if command furnizsh help 2>/dev/null | grep -q '^  update'; then
      command furnizsh update "$@"
      return $?
    fi
  fi

  if [[ -z "$script" ]]; then
    print -u2 "agupdate: can't find update.sh — reinstall furnizsh, or update"
    print -u2 "          the way you installed it (brew / npm / the bootstrap)."
    return 1
  fi

  "$script" "$@"
}

# ============================================================
#  cheatsheet / chs — the reference card
#  --comp | --full | -a | --all  prints the exhaustive version
# ============================================================
cheatsheet() {
  local B=$FURNIZSH_C[bold] D=$FURNIZSH_C[reset]
  local ORANGE=$FURNIZSH_C[orange] YELLOW=$FURNIZSH_C[yellow]
  local BLUE=$FURNIZSH_C[blue] GREEN=$FURNIZSH_C[green] TEXT=$FURNIZSH_C[text]
  local GRAY=$FURNIZSH_C[gray]
  local active="$(_furnizsh_current_theme)"

  case "${1:-}" in
    --comp|--full|-a|--all)
      printf "%s%sfurnizsh cheatsheet -- FULL%s  %sv%s -- short version: cheatsheet / chs%s\n\n" "$B" "$BLUE" "$D" "$TEXT" "$(_furnizsh_version)" "$D"

      printf "%s%sTheme%s  %s(active: %s%s%s%s -- switch with 'theme <name>')%s\n" "$B" "$ORANGE" "$D" "$GRAY" "$GREEN" "$active" "$D" "$GRAY" "$D"
      printf "  %sneon%s near-black + glow  %scatppuccin%s pastels  %sgruvbox%s warm retro  %stokyonight%s cool blues\n" "$YELLOW" "$D" "$YELLOW" "$D" "$YELLOW" "$D" "$YELLOW" "$D"
      printf "  Font: %sJetBrainsMono Nerd Font Mono%s   Tab/window title = current directory\n\n" "$GREEN" "$D"

      printf "%s%sOh My Zsh plugins%s\n" "$B" "$ORANGE" "$D"
      printf "  %sgit%s        gst status, ga add, gc commit, gco checkout, gcb checkout -b, gp push, gl pull, gd diff, glog graph log\n" "$YELLOW" "$D"
      printf "  %ssudo%s       press ESC ESC to prepend sudo to the current/last command\n" "$YELLOW" "$D"
      printf "  %shistory%s    h = history, hs <term> = search history\n" "$YELLOW" "$D"
      printf "  %shistory-substring-search%s  type part of a command, Up/Down filters matching history\n" "$YELLOW" "$D"
      printf "  %scommand-not-found%s  suggests the package when a command isn't found\n" "$YELLOW" "$D"
      printf "  %scolored-man-pages%s  colorizes man pages\n" "$YELLOW" "$D"
      printf "  %sextract%s    x file.{zip,tar.gz,rar,7z,...} extracts any archive\n" "$YELLOW" "$D"
      printf "  %sweb-search%s google/ddg/stackoverflow/github <query> opens a search in your browser\n" "$YELLOW" "$D"
      printf "  %scopypath%s / %scopyfile%s <file> / %scopybuffer%s (ctrl-o)  copy path / file contents / current command line\n" "$YELLOW" "$D" "$YELLOW" "$D" "$YELLOW" "$D"
      printf "  %sdirhistory%s alt+Left/Right back/forward through visited dirs, alt+Up/Down parent/child\n" "$YELLOW" "$D"
      printf "  %sjsontools%s  pp_json, is_json, urlencode_json, urldecode_json\n" "$YELLOW" "$D"
      printf "  %smacos%s      ofd (open Finder here), cdf (cd to Finder's front window), showfiles/hidefiles  [macOS]\n" "$YELLOW" "$D"
      printf "  %snpm%s / %snode%s / %sbrew%s  tab-completion + shortcut aliases for each\n" "$YELLOW" "$D" "$YELLOW" "$D" "$YELLOW" "$D"
      printf "  %szsh-autosuggestions%s      -> or End accepts the full suggestion; alt+F / ctrl+Right accepts one word\n" "$YELLOW" "$D"
      printf "  %szsh-syntax-highlighting%s  green = valid command, red = invalid/unknown, as you type\n\n" "$YELLOW" "$D"

      printf "%s%sCore tools%s\n" "$B" "$ORANGE" "$D"
      printf "  %seza%s       ls, ll (long+all), lt (tree)  |  raw: eza --icons=auto --long --header --git\n" "$YELLOW" "$D"
      printf "  %sbat%s       cat <file>  |  bat -A (show whitespace), bat --diff, bat --list-themes\n" "$YELLOW" "$D"
      printf "  %sfd%s        find  |  fd -e ts (by extension), fd -H (include hidden), fd -t d (dirs only)\n" "$YELLOW" "$D"
      printf "  %szoxide%s    z <partial-dir> jumps  |  zi (interactive picker), zoxide query/remove <path>\n" "$YELLOW" "$D"
      printf "  %sfzf%s       ctrl+r history, ctrl+t insert file path, alt+c cd into a fuzzy-picked dir\n" "$YELLOW" "$D"
      printf "  %sgit-delta%s automatic on git diff/show/log -p  |  n/N jump between files, q to quit pager\n" "$YELLOW" "$D"
      printf "  %slazygit%s   lg opens the TUI  |  space stage/unstage, c commit, P push, p pull, ? all keys\n\n" "$YELLOW" "$D"

      printf "%s%sExtended tools%s  %s(installed with --tools extended|all)%s\n" "$B" "$ORANGE" "$D" "$GRAY" "$D"
      printf "  %srg%s ripgrep, fastest content search   %stmux%s terminal multiplexer, themed to match\n" "$YELLOW" "$D" "$YELLOW" "$D"
      printf "  %satuin%s searchable, syncable shell history  %sdirenv%s per-directory env loading\n" "$YELLOW" "$D" "$YELLOW" "$D"
      printf "  %sjq%s / %syq%s  JSON / YAML processors      %shttpie%s human-friendly HTTP client\n" "$YELLOW" "$D" "$YELLOW" "$D" "$YELLOW" "$D"
      printf "  %sdust%s visual disk usage   %sprocs%s modern ps   %sbtop%s system monitor   %stldr%s short man pages\n" "$YELLOW" "$D" "$YELLOW" "$D" "$YELLOW" "$D" "$YELLOW" "$D"
      printf "  %sgh%s GitHub CLI\n\n" "$YELLOW" "$D"

      printf "%s%sfurnizsh commands -- core%s\n" "$B" "$ORANGE" "$D"
      printf "  %scheatsheet%s / %schs%s   this reference (--comp for the full version)\n" "$YELLOW" "$D" "$YELLOW" "$D"
      printf "  %sagdoctor%s        health-check every part of the setup, with the fix for each failure\n" "$YELLOW" "$D"
      printf "  %stheme%s [name]    list themes, or switch ghostty + starship + lazygit together\n" "$YELLOW" "$D"
      printf "  %sagupdate%s        update furnizsh, however you installed it\n" "$YELLOW" "$D"
      printf "  %smkcd%s <dir>      create a directory and cd into it\n" "$YELLOW" "$D"
      printf "  %sup%s [n]          cd up n levels (default 1)\n" "$YELLOW" "$D"
      printf "  %sserve%s [port]    static HTTP server in the current dir, prints the LAN URL\n" "$YELLOW" "$D"
      printf "  %sports%s           everything listening, with PID and process name\n" "$YELLOW" "$D"
      printf "  %skillport%s <port> kill whatever is holding a port\n" "$YELLOW" "$D"
      printf "  %sfkill%s           fzf-pick a process and kill it (tab selects several)\n" "$YELLOW" "$D"
      printf "  %sfe%s [query]      fzf-pick a file with a preview and open it in \$EDITOR\n" "$YELLOW" "$D"
      printf "  %sbak%s <file>      timestamped backup copy next to the original\n" "$YELLOW" "$D"
      printf "  %ssizeof%s [dir]    biggest items in a directory, largest first\n" "$YELLOW" "$D"
      printf "  %sgclean%s          delete local branches already merged into the default branch\n" "$YELLOW" "$D"
      printf "  %spaths%s           \$PATH one entry per line, duplicates and missing dirs flagged\n" "$YELLOW" "$D"
      printf "  %sreload%s          restart zsh in place, picking up config changes\n\n" "$YELLOW" "$D"

      if typeset -f weather >/dev/null 2>&1; then
        printf "%s%sfurnizsh commands -- extras%s  %s(need network)%s\n" "$B" "$ORANGE" "$D" "$GRAY" "$D"
        printf "  %sweather%s [city]  forecast in the terminal      %scheat%s <cmd>   practical examples for any command\n" "$YELLOW" "$D" "$YELLOW" "$D"
        printf "  %sqr%s <text>       QR code in the terminal       %sgitignore%s <langs>  fetch a .gitignore\n" "$YELLOW" "$D" "$YELLOW" "$D"
        printf "  %snote%s [text]     timestamped scratch notes     %stimer%s <mins>  countdown + notification\n" "$YELLOW" "$D" "$YELLOW" "$D"
        printf "  %ssysinfo%s         machine summary               %sdockerclean%s   reclaim docker disk space\n\n" "$YELLOW" "$D" "$YELLOW" "$D"
      fi

      printf "%s%sGhostty keybinds%s\n" "$B" "$ORANGE" "$D"
      printf "  %sWindow/Tab%s   cmd+n new window, cmd+t new tab, cmd+w close tab, cmd+shift+w close window,\n" "$B" "$D"
      printf "                cmd+alt+shift+w close all, cmd+shift+[ / ] prev/next tab, cmd+1..8 tab N, cmd+9 last\n"
      printf "  %sSplits%s       cmd+d split right, cmd+shift+d split down, cmd+[ / ] prev/next split,\n" "$B" "$D"
      printf "                cmd+alt+arrows move focus, cmd+ctrl+arrows resize, cmd+shift+enter zoom\n"
      printf "  %sSearch%s       cmd+f search, cmd+g / cmd+shift+g next/prev, cmd+e search selection, cmd+a select all\n" "$B" "$D"
      printf "  %sFont%s         cmd+= / cmd+- size, cmd+0 reset, cmd+enter fullscreen\n" "$B" "$D"
      printf "  %sScroll%s       cmd+Home/End, cmd+PgUp/PgDn, cmd+Up/Down jump to previous/next shell prompt\n" "$B" "$D"
      printf "  %sMisc%s         cmd+, open config, cmd+k clear screen, cmd+v paste, cmd+q quit\n" "$B" "$D"
      printf "  %sLine editing%s cmd+Left/Right line start/end, cmd+Backspace delete to start, alt+Left/Right one word\n\n" "$B" "$D"

      printf "%s%sNotifications (cc-alert.sh, macOS)%s\n" "$B" "$ORANGE" "$D"
      printf "  Fires on task completion and permission prompts, muted while you're looking at the terminal.\n"
      printf "  Full env var reference: %shead -40 ~/.claude/hooks/cc-alert.sh%s\n\n" "$YELLOW" "$D"

      printf "%sDocs: https://wosmos.github.io/furnizsh   Repo: https://github.com/Wosmos/furnizsh%s\n" "$TEXT" "$D"
      ;;
    *)
      printf "%s%sfurnizsh cheatsheet%s  %sv%s -- run 'cheatsheet --comp' for everything%s\n\n" "$B" "$BLUE" "$D" "$TEXT" "$(_furnizsh_version)" "$D"

      printf "%s%sTheme%s  %s%s%s  %s(theme <name> to switch)%s\n\n" "$B" "$ORANGE" "$D" "$GREEN" "$active" "$D" "$GRAY" "$D"

      printf "%s%sPlugins%s\n" "$B" "$ORANGE" "$D"
      printf "  %szsh-autosuggestions%s      ghost-text history suggestions -- accept with -> or End\n" "$YELLOW" "$D"
      printf "  %szsh-syntax-highlighting%s  colors valid/invalid commands as you type\n\n" "$YELLOW" "$D"

      printf "%s%sTools%s\n" "$B" "$ORANGE" "$D"
      printf "  %szoxide%s      z <partial-dir>          frecency-based cd\n" "$YELLOW" "$D"
      printf "  %sfzf%s         ctrl+r / ctrl+t / alt+c  fuzzy history / files / cd\n" "$YELLOW" "$D"
      printf "  %seza%s         ls, ll, lt               icons + tree view\n" "$YELLOW" "$D"
      printf "  %sbat%s         cat <file>               syntax-highlighted cat\n" "$YELLOW" "$D"
      printf "  %sfd%s          find                     faster find\n" "$YELLOW" "$D"
      printf "  %sgit-delta%s   git diff / show          side-by-side colored diffs\n" "$YELLOW" "$D"
      printf "  %slazygit%s     lg                       full git TUI\n\n" "$YELLOW" "$D"

      printf "%s%sCommands%s\n" "$B" "$ORANGE" "$D"
      printf "  %stheme%s [name]  switch the whole look     %sagdoctor%s        health-check the setup\n" "$YELLOW" "$D" "$YELLOW" "$D"
      printf "  %smkcd%s <dir>    make + enter a dir        %sup%s [n]          cd up n levels\n" "$YELLOW" "$D" "$YELLOW" "$D"
      printf "  %sserve%s [port]  static server here        %sports%s           what's listening\n" "$YELLOW" "$D" "$YELLOW" "$D"
      printf "  %skillport%s <p>  free a port               %sfkill%s           fzf-pick + kill a process\n" "$YELLOW" "$D" "$YELLOW" "$D"
      printf "  %sfe%s [query]    fzf-pick + edit a file    %sbak%s <file>      timestamped backup\n" "$YELLOW" "$D" "$YELLOW" "$D"
      printf "  %ssizeof%s [dir]  what's eating the disk    %sgclean%s          prune merged branches\n" "$YELLOW" "$D" "$YELLOW" "$D"
      printf "  %spaths%s         \$PATH, one per line       %sreload%s          restart zsh\n" "$YELLOW" "$D" "$YELLOW" "$D"
      printf "  %sagupdate%s      update furnizsh\n\n" "$YELLOW" "$D"

      printf "%s%sGhostty keybinds%s\n" "$B" "$ORANGE" "$D"
      printf "  cmd+n / cmd+t          new window / tab\n"
      printf "  cmd+d / cmd+shift+d    split right / down\n"
      printf "  cmd+shift+]/[          next / prev tab\n"
      printf "  cmd+1..9               jump to tab N\n\n"

      printf "%sDocs: https://wosmos.github.io/furnizsh%s\n" "$TEXT" "$D"
      ;;
  esac
}
alias chs='cheatsheet'

# ============================================================
#  agdoctor — health-check the setup
#  Also available standalone as ./doctor.sh in the repo.
# ============================================================
agdoctor() {
  local ok=$FURNIZSH_C[green] bad=$FURNIZSH_C[orange] dim=$FURNIZSH_C[gray]
  local B=$FURNIZSH_C[bold] D=$FURNIZSH_C[reset] BLUE=$FURNIZSH_C[blue]
  local failures=0

  _ag_check() {
    local label="$1" note="$2"; shift 2
    if "$@" >/dev/null 2>&1; then
      printf "  %s✓%s %-26s\n" "$ok" "$D" "$label"
    else
      printf "  %s✗%s %-26s %s%s%s\n" "$bad" "$D" "$label" "$dim" "$note" "$D"
      (( failures++ ))
    fi
  }

  printf "\n%s%sfurnizsh doctor%s  %s(v%s, theme: %s)%s\n\n" \
    "$B" "$BLUE" "$D" "$dim" "$(_furnizsh_version)" "$(_furnizsh_current_theme)" "$D"

  printf "%s%sCore tools%s\n" "$B" "$FURNIZSH_C[orange]" "$D"
  local t
  for t in starship zoxide fzf eza bat fd delta lazygit git; do
    _ag_check "$t" "not on PATH — rerun ./install.sh" command -v "$t"
  done

  # Extended tools are opt-in, so a miss is reported as informational.
  local extended=(rg tmux atuin direnv jq yq http dust procs btop tldr gh)
  local present=() missing=()
  for t in $extended; do
    command -v "$t" >/dev/null 2>&1 && present+=($t) || missing+=($t)
  done
  if (( ${#present} )); then
    printf "\n%s%sExtended tools%s %s(optional)%s\n" "$B" "$FURNIZSH_C[orange]" "$D" "$dim" "$D"
    printf "  %s✓%s %s\n" "$ok" "$D" "${present[*]}"
    (( ${#missing} )) && printf "  %s·%s not installed: %s  %s(./install.sh --tools extended)%s\n" \
      "$dim" "$D" "${missing[*]}" "$dim" "$D"
  fi

  printf "\n%s%sShell%s\n" "$B" "$FURNIZSH_C[orange]" "$D"
  _ag_check "zsh is the login shell" "run: chsh -s \"\$(command -v zsh)\"" test "${SHELL##*/}" = zsh
  _ag_check "oh-my-zsh installed"    "missing ~/.oh-my-zsh" test -d "${ZSH:-$HOME/.oh-my-zsh}"
  _ag_check "zsh-autosuggestions"    "plugin not cloned into \$ZSH_CUSTOM/plugins" \
    test -d "${ZSH_CUSTOM:-${ZSH:-$HOME/.oh-my-zsh}/custom}/plugins/zsh-autosuggestions"
  _ag_check "zsh-syntax-highlighting" "plugin not cloned into \$ZSH_CUSTOM/plugins" \
    test -d "${ZSH_CUSTOM:-${ZSH:-$HOME/.oh-my-zsh}/custom}/plugins/zsh-syntax-highlighting"
  _ag_check "furnizsh sourced"      "no source line in ~/.zshrc — rerun ./install.sh" \
    grep -q '>>> furnizsh >>>' "$HOME/.zshrc"

  printf "\n%s%sConfig%s\n" "$B" "$FURNIZSH_C[orange]" "$D"
  _ag_check "starship.toml"  "missing ~/.config/starship.toml" test -f "$HOME/.config/starship.toml"
  _ag_check "ghostty config" "missing ~/.config/ghostty/config" test -f "$HOME/.config/ghostty/config"
  _ag_check "themes installed" "rerun ./install.sh" test -d "$FURNIZSH_DIR/themes"
  _ag_check "delta as git pager" "run: git config --global core.pager delta" \
    test "$(git config --global core.pager 2>/dev/null)" = delta

  local lazygit_cfg
  if [[ "$OSTYPE" == darwin* ]]; then
    lazygit_cfg="$HOME/Library/Application Support/lazygit/config.yml"
  else
    lazygit_cfg="${XDG_CONFIG_HOME:-$HOME/.config}/lazygit/config.yml"
  fi
  _ag_check "lazygit theme" "missing $lazygit_cfg" test -f "$lazygit_cfg"

  printf "\n%s%sFont%s\n" "$B" "$FURNIZSH_C[orange]" "$D"
  if [[ "$OSTYPE" == darwin* ]]; then
    _ag_check "JetBrainsMono Nerd Font" "brew install --cask font-jetbrains-mono-nerd-font" \
      sh -c 'ls ~/Library/Fonts /Library/Fonts 2>/dev/null | grep -qi "jetbrainsmono.*nerd"'
  else
    _ag_check "JetBrainsMono Nerd Font" "install it from nerdfonts.com" \
      sh -c 'fc-list 2>/dev/null | grep -qi "jetbrainsmono nerd"'
  fi
  printf "  %sIf these are boxes, the Nerd Font isn't active in your terminal:%s\n" "$dim" "$D"
  printf "     \n\n"

  unfunction _ag_check

  if (( failures == 0 )); then
    printf "%s%sAll good.%s Run %scheatsheet%s for the reference.\n\n" "$B" "$ok" "$D" "$FURNIZSH_C[yellow]" "$D"
  else
    printf "%s%s%d check(s) failed.%s See https://wosmos.github.io/furnizsh\n\n" "$B" "$bad" "$failures" "$D"
  fi
  return $(( failures > 0 ))
}
command -v doctor >/dev/null 2>&1 || alias doctor='agdoctor'

# ============================================================
#  Navigation
# ============================================================

# mkcd <dir> — create a directory (including parents) and cd into it
mkcd() {
  [[ -z "${1:-}" ]] && { print -u2 "usage: mkcd <dir>"; return 1 }
  mkdir -p -- "$1" && cd -- "$1"
}

# up [n] — cd up n levels (default 1)
up() {
  local levels="${1:-1}"
  if [[ ! "$levels" =~ ^[0-9]+$ ]]; then
    print -u2 "usage: up [levels]"; return 1
  fi
  local target="" i
  for (( i = 0; i < levels; i++ )); do target+="../"; done
  cd -- "${target:-.}"
}

# ============================================================
#  Network
# ============================================================

# serve [port] — static HTTP server in the current directory
serve() {
  local port="${1:-8000}"
  if ! command -v python3 >/dev/null 2>&1; then
    print -u2 "serve: python3 not found"; return 1
  fi

  local lan
  if [[ "$OSTYPE" == darwin* ]]; then
    lan=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null)
  else
    lan=$(hostname -I 2>/dev/null | awk '{print $1}')
  fi

  printf "%sServing %s%s\n" "$FURNIZSH_C[gray]" "${PWD/#$HOME/~}" "$FURNIZSH_C[reset]"
  printf "  local   %shttp://localhost:%s%s\n" "$FURNIZSH_C[green]" "$port" "$FURNIZSH_C[reset]"
  [[ -n "$lan" ]] && printf "  network %shttp://%s:%s%s\n" "$FURNIZSH_C[green]" "$lan" "$port" "$FURNIZSH_C[reset]"
  printf "\n"
  python3 -m http.server "$port"
}

# ports — everything currently listening, with PID and process name
ports() {
  if command -v lsof >/dev/null 2>&1; then
    lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | awk 'NR==1 || !seen[$2,$9]++'
  elif command -v ss >/dev/null 2>&1; then
    ss -tulpn
  else
    print -u2 "ports: neither lsof nor ss found"; return 1
  fi
}

# killport <port> — kill whatever is holding a port
killport() {
  local port="${1:-}"
  if [[ ! "$port" =~ ^[0-9]+$ ]]; then
    print -u2 "usage: killport <port>"; return 1
  fi

  local pids
  if command -v lsof >/dev/null 2>&1; then
    pids=$(lsof -ti "tcp:$port" 2>/dev/null)
  elif command -v fuser >/dev/null 2>&1; then
    pids=$(fuser -n tcp "$port" 2>/dev/null)
  else
    print -u2 "killport: neither lsof nor fuser found"; return 1
  fi

  if [[ -z "$pids" ]]; then
    printf "%sNothing listening on port %s.%s\n" "$FURNIZSH_C[gray]" "$port" "$FURNIZSH_C[reset]"
    return 0
  fi

  local pid
  for pid in ${=pids}; do
    local name=$(ps -p "$pid" -o comm= 2>/dev/null)
    kill -9 "$pid" 2>/dev/null \
      && printf "%sKilled%s %s (pid %s) on port %s\n" "$FURNIZSH_C[orange]" "$FURNIZSH_C[reset]" "${name:-?}" "$pid" "$port" \
      || printf "%sCould not kill pid %s — try with sudo.%s\n" "$FURNIZSH_C[gray]" "$pid" "$FURNIZSH_C[reset]"
  done
}

# ============================================================
#  fzf-powered
# ============================================================

# fkill — fzf-pick one or more processes and kill them (tab multi-selects)
fkill() {
  command -v fzf >/dev/null 2>&1 || { print -u2 "fkill: fzf not installed"; return 1 }

  local pids
  pids=$(ps -eo pid,ppid,%cpu,%mem,comm,args 2>/dev/null \
    | sed 1d \
    | fzf --multi --height 60% --reverse \
          --header='tab = select multiple, enter = kill' \
    | awk '{print $1}')

  [[ -z "$pids" ]] && return 0
  print -r -- "$pids" | while read -r pid; do
    kill -${1:-15} "$pid" 2>/dev/null \
      && printf "%skilled%s %s\n" "$FURNIZSH_C[orange]" "$FURNIZSH_C[reset]" "$pid" \
      || printf "%scould not kill %s%s\n" "$FURNIZSH_C[gray]" "$pid" "$FURNIZSH_C[reset]"
  done
}

# fe [query] — fzf-pick a file with a syntax-highlighted preview, open in $EDITOR
fe() {
  command -v fzf >/dev/null 2>&1 || { print -u2 "fe: fzf not installed"; return 1 }

  local finder='find . -type f -not -path "*/.git/*" 2>/dev/null'
  command -v fd      >/dev/null 2>&1 && finder='fd --type f --hidden --exclude .git'
  command -v fdfind  >/dev/null 2>&1 && finder='fdfind --type f --hidden --exclude .git'

  local previewer='cat {}'
  command -v bat    >/dev/null 2>&1 && previewer='bat --style=numbers --color=always {}'
  command -v batcat >/dev/null 2>&1 && previewer='batcat --style=numbers --color=always {}'

  local file
  file=$(eval "$finder" | fzf --query "${1:-}" --height 70% --reverse \
                              --preview "$previewer" --preview-window=right:60%)
  [[ -n "$file" ]] && ${EDITOR:-vi} "$file"
}

# ============================================================
#  Files & disk
# ============================================================

# bak <file> — timestamped backup copy alongside the original
bak() {
  [[ -e "${1:-}" ]] || { print -u2 "usage: bak <file-or-dir>"; return 1 }
  local src="${1%/}"
  local dest="${src}.$(date +%Y%m%d-%H%M%S).bak"
  cp -a -- "$src" "$dest" && printf "%s->%s %s\n" "$FURNIZSH_C[gray]" "$FURNIZSH_C[reset]" "$dest"
}

# sizeof [dir] — biggest items in a directory, human-readable, largest first
sizeof() {
  local target="${1:-.}"
  # dust gives a nicer tree when it's installed; du is the portable fallback.
  if command -v dust >/dev/null 2>&1; then
    dust -n 20 "$target"
  else
    du -sh -- "$target"/*(DN) 2>/dev/null | sort -rh | head -20
  fi
}

# ============================================================
#  Git
# ============================================================

# gprune — delete local branches already merged into the default branch
gprune() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    print -u2 "gprune: not inside a git repository"; return 1
  }

  local default
  default=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)
  default="${default#origin/}"
  if [[ -z "$default" ]]; then
    for default in main master trunk; do
      git show-ref --verify --quiet "refs/heads/$default" && break
      default=""
    done
  fi
  [[ -z "$default" ]] && { print -u2 "gprune: could not determine the default branch"; return 1 }

  local -a stale
  stale=(${(f)"$(git branch --merged "$default" --format='%(refname:short)' \
    | grep -vxE "$default|main|master|develop|trunk")"})

  if (( ${#stale} == 0 )); then
    printf "%sNothing to prune — no branches merged into %s.%s\n" "$FURNIZSH_C[gray]" "$default" "$FURNIZSH_C[reset]"
    return 0
  fi

  printf "%sMerged into %s, safe to delete:%s\n" "$FURNIZSH_C[gray]" "$default" "$FURNIZSH_C[reset]"
  printf "  %s%s%s\n" "$FURNIZSH_C[yellow]" "${^stale}" "$FURNIZSH_C[reset]"

  printf "\nDelete %d branch(es)? [y/N] " "${#stale}"
  local reply; read -r reply
  [[ "$reply" == [yY]* ]] || { printf "Aborted.\n"; return 0 }

  local b
  for b in $stale; do git branch -d "$b"; done
}

# ============================================================
#  Environment
# ============================================================

# paths — $PATH one entry per line; flags duplicates and missing directories
paths() {
  local -A seen
  local dir
  for dir in ${(s.:.)PATH}; do
    if [[ -n "${seen[$dir]:-}" ]]; then
      printf "%s%-50s dup%s\n" "$FURNIZSH_C[gray]" "$dir" "$FURNIZSH_C[reset]"
    elif [[ ! -d "$dir" ]]; then
      printf "%s%-50s missing%s\n" "$FURNIZSH_C[orange]" "$dir" "$FURNIZSH_C[reset]"
    else
      printf "%s%s%s\n" "$FURNIZSH_C[text]" "$dir" "$FURNIZSH_C[reset]"
    fi
    seen[$dir]=1
  done
}

# reload — restart zsh in place, picking up config changes
reload() {
  printf "%sReloading zsh...%s\n" "$FURNIZSH_C[gray]" "$FURNIZSH_C[reset]"
  exec zsh -l
}
