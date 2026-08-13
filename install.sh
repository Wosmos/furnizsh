#!/usr/bin/env bash
# ============================================================
#  furnizsh — installer for macOS and Linux
#  https://github.com/Wosmos/furnizsh
#
#  Safe by design:
#    * never overwrites your ~/.zshrc — appends one guarded source line
#    * backs up every file it replaces to ~/.furnizsh-backup/<timestamp>/
#    * idempotent — rerun it any time
#    * --dry-run prints every action and changes nothing
#
#  Everything optional is behind a flag. See --help.
# ============================================================

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FURNIZSH_HOME="$HOME/.config/furnizsh"
FURNIZSH_VERSION="$(cat "$REPO_DIR/VERSION" 2>/dev/null || printf 'dev')"
BACKUP_DIR="$HOME/.furnizsh-backup/$(date +%Y%m%d-%H%M%S)"
MARKER_START="# >>> furnizsh >>>"
MARKER_END="# <<< furnizsh <<<"

# ---- defaults ----
DRY_RUN=0
ASSUME_YES=0
INSTALL_FONT=1
INSTALL_CLAUDE=1
INSTALL_EXTRAS=1
INSTALL_TMUX=1
DO_CHSH=1
THEME="neon"
TOOLSET="core"

# ------------------------------------------------------------
# Tool sets
#
# core     — what the setup actually needs
# extended — core plus the wider daily-driver toolbelt
# all      — extended plus the heavier optional pieces
# ------------------------------------------------------------
TOOLS_CORE="starship fzf zoxide eza bat fd git-delta lazygit"
TOOLS_EXTENDED="ripgrep tmux jq direnv tldr btop"
TOOLS_ALL="atuin yq httpie dust procs gh"

# ------------------------------------------------------------
# Output helpers
# ------------------------------------------------------------
if [ -t 1 ]; then
  C_ORANGE=$'\033[38;2;250;179;135m'
  C_YELLOW=$'\033[38;2;249;226;175m'
  C_GREEN=$'\033[38;2;166;227;161m'
  C_BLUE=$'\033[38;2;137;180;250m'
  C_GRAY=$'\033[38;2;108;112;134m'
  C_BOLD=$'\033[1m'
  C_RESET=$'\033[0m'
else
  C_ORANGE='' C_YELLOW='' C_GREEN='' C_BLUE='' C_GRAY='' C_BOLD='' C_RESET=''
fi

step()  { printf "\n%s%s==>%s %s%s\n" "$C_BOLD" "$C_BLUE" "$C_RESET" "$1" "$C_RESET"; }
info()  { printf "    %s\n" "$1"; }
ok()    { printf "    %s✓%s %s\n" "$C_GREEN" "$C_RESET" "$1"; }
skip()  { printf "    %s· %s%s\n" "$C_GRAY" "$1" "$C_RESET"; }
warn()  { printf "    %s! %s%s\n" "$C_ORANGE" "$1" "$C_RESET"; }
die()   { printf "\n%s%serror:%s %s\n\n" "$C_BOLD" "$C_ORANGE" "$C_RESET" "$1" >&2; exit 1; }

# Run a command, or just describe it under --dry-run.
run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf "    %s[dry-run]%s %s\n" "$C_GRAY" "$C_RESET" "$*"
  else
    "$@"
  fi
}

confirm() {
  [ "$ASSUME_YES" -eq 1 ] && return 0
  [ "$DRY_RUN" -eq 1 ] && return 0
  printf "    %s [y/N] " "$1"
  local reply
  read -r reply </dev/tty
  case "$reply" in [yY]*) return 0 ;; *) return 1 ;; esac
}

usage() {
  cat <<'EOF'
furnizsh installer

  ./install.sh [options]

Look and feel:
  --theme <name>     neon (default) | catppuccin | gruvbox | tokyonight
                     Sets Ghostty, Starship and lazygit together.
                     Switch later at any time with the `theme` command.
  --no-font          skip the JetBrains Mono Nerd Font install

What gets installed:
  --tools <set>      core (default) | extended | all
                       core     starship fzf zoxide eza bat fd delta lazygit
                       extended + ripgrep tmux jq direnv tldr btop
                       all      + atuin yq httpie dust procs gh
  --no-tmux          don't install the tmux config (extended/all only)
  --no-extras        skip the network-dependent helper commands
                     (weather, cheat, qr, gitignore, note, timer,
                      sysinfo, dockerclean)
  --no-claude        skip the optional Claude Code extras

Behaviour:
  --dry-run          print every action without changing anything
  --yes, -y          don't prompt for confirmation (non-interactive)
  --no-chsh          don't change the login shell, even if it isn't zsh
  -h, --help         this message

Examples:
  ./install.sh --dry-run
  ./install.sh --theme gruvbox --tools extended
  ./install.sh --tools all --yes
  ./install.sh --theme catppuccin --no-extras --no-claude
EOF
}

# ------------------------------------------------------------
# Argument parsing
# ------------------------------------------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)    DRY_RUN=1 ;;
    --yes|-y)     ASSUME_YES=1 ;;
    --no-font)    INSTALL_FONT=0 ;;
    --no-claude)  INSTALL_CLAUDE=0 ;;
    --no-extras)  INSTALL_EXTRAS=0 ;;
    --no-tmux)    INSTALL_TMUX=0 ;;
    --no-chsh)    DO_CHSH=0 ;;
    --theme)
      [ $# -ge 2 ] || die "--theme needs a value (neon, catppuccin, gruvbox, tokyonight)"
      THEME="$2"; shift ;;
    --theme=*)    THEME="${1#*=}" ;;
    --tools)
      [ $# -ge 2 ] || die "--tools needs a value (core, extended, all)"
      TOOLSET="$2"; shift ;;
    --tools=*)    TOOLSET="${1#*=}" ;;
    -h|--help)    usage; exit 0 ;;
    *)            die "unknown option: $1 (try --help)" ;;
  esac
  shift
done

if [ ! -f "$REPO_DIR/config/themes/$THEME.theme" ]; then
  available=""
  for t in "$REPO_DIR"/config/themes/*.theme; do
    [ -e "$t" ] || continue
    name="${t##*/}"
    available="$available ${name%.theme}"
  done
  die "unknown theme '$THEME'. Available:$available"
fi

case "$TOOLSET" in
  core|extended|all) ;;
  *) die "unknown tool set '$TOOLSET'. Use core, extended or all." ;;
esac

# Load the chosen theme's settings.
# shellcheck source=/dev/null
. "$REPO_DIR/config/themes/$THEME.theme"

# The tmux config only makes sense once tmux is actually installed.
[ "$TOOLSET" = "core" ] && INSTALL_TMUX=0

# ------------------------------------------------------------
# Backups
# ------------------------------------------------------------
backup() {
  local target="$1"
  [ -e "$target" ] || return 0
  local dest
  dest="$BACKUP_DIR/$(basename "$target")"
  run mkdir -p "$BACKUP_DIR"
  run cp -a "$target" "$dest"
  skip "backed up $(printf '%s' "$target" | sed "s|$HOME|~|")"
}

install_file() {
  local src="$1" dest="$2"
  if [ -f "$dest" ] && cmp -s "$src" "$dest"; then
    skip "$(printf '%s' "$dest" | sed "s|$HOME|~|") already current"
    return 0
  fi
  backup "$dest"
  run mkdir -p "$(dirname "$dest")"
  run cp "$src" "$dest"
  ok "$(printf '%s' "$dest" | sed "s|$HOME|~|")"
}

# ------------------------------------------------------------
# Platform detection
# ------------------------------------------------------------
OS="$(uname -s)"
PKG=""

detect_platform() {
  case "$OS" in
    Darwin) PKG="brew" ;;
    Linux)
      if   command -v apt-get >/dev/null 2>&1; then PKG="apt"
      elif command -v dnf     >/dev/null 2>&1; then PKG="dnf"
      elif command -v pacman  >/dev/null 2>&1; then PKG="pacman"
      elif command -v brew    >/dev/null 2>&1; then PKG="brew"
      else
        die "no supported package manager found (apt, dnf, pacman or brew). See docs/LINUX.md."
      fi
      ;;
    *) die "unsupported platform: $OS. See docs/WINDOWS.md for Windows." ;;
  esac
}

# ------------------------------------------------------------
# Homebrew
# ------------------------------------------------------------
ensure_homebrew() {
  command -v brew >/dev/null 2>&1 && { skip "Homebrew already installed"; return 0; }
  [ "$PKG" = "brew" ] || return 0

  step "Installing Homebrew"
  info "This is the official installer from brew.sh and will ask for your password."
  confirm "Install Homebrew?" || die "Homebrew is required on macOS."
  run /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
  ok "Homebrew installed"
}

# Resolve the tool list for the chosen set.
selected_tools() {
  case "$TOOLSET" in
    core)     printf '%s' "$TOOLS_CORE" ;;
    extended) printf '%s %s' "$TOOLS_CORE" "$TOOLS_EXTENDED" ;;
    all)      printf '%s %s %s' "$TOOLS_CORE" "$TOOLS_EXTENDED" "$TOOLS_ALL" ;;
  esac
}

# Package names differ per distro. Notably Debian/Ubuntu ship fd as
# `fd-find` and bat as `batcat` (both collide with unrelated packages),
# and httpie's binary is `http`. furnizsh.zsh aliases around this.
translate_pkg() {
  local p="$1"
  case "$PKG:$p" in
    apt:fd|dnf:fd)   printf 'fd-find' ;;
    pacman:git-delta) printf 'git-delta' ;;
    apt:git-delta)   printf 'git-delta' ;;
    *:ripgrep)       printf 'ripgrep' ;;
    *)               printf '%s' "$p" ;;
  esac
}

install_packages() {
  step "Installing tools  ($TOOLSET)"

  local tools
  tools="$(selected_tools)"
  info "$(echo "$tools" | wc -w | tr -d ' ') packages: $tools"

  case "$PKG" in
    brew)
      # shellcheck disable=SC2086
      run brew install zsh git $tools
      ok "tools installed"

      if [ "$INSTALL_FONT" -eq 1 ] && [ "$OS" = "Darwin" ]; then
        run brew install --cask font-jetbrains-mono-nerd-font
        ok "JetBrains Mono Nerd Font"
      fi

      if [ "$OS" = "Darwin" ]; then
        if [ -d "/Applications/Ghostty.app" ]; then
          skip "Ghostty already installed"
        else
          run brew install --cask ghostty
          ok "Ghostty"
        fi
      fi
      ;;

    apt)
      run sudo apt-get update
      local p translated=""
      for p in $tools; do translated="$translated $(translate_pkg "$p")"; done
      # Installed one at a time so a single missing package doesn't
      # abort the whole run — Debian's coverage of these varies a lot.
      run sudo apt-get install -y zsh git curl unzip || true
      for p in $translated; do
        run sudo apt-get install -y "$p" 2>/dev/null || warn "$p not in your apt repos — see docs/LINUX.md"
      done
      ok "tools installed"
      ;;

    dnf)
      local p translated=""
      for p in $tools; do translated="$translated $(translate_pkg "$p")"; done
      run sudo dnf install -y zsh git curl unzip || true
      # shellcheck disable=SC2086
      run sudo dnf install -y $translated || warn "some packages failed — see docs/LINUX.md"
      ok "tools installed"
      ;;

    pacman)
      # shellcheck disable=SC2086
      run sudo pacman -S --needed --noconfirm zsh git curl unzip $tools \
        || warn "some packages failed — see docs/LINUX.md"
      ok "tools installed"
      ;;
  esac

  # Starship isn't packaged everywhere — fall back to its official installer.
  if ! command -v starship >/dev/null 2>&1 && [ "$DRY_RUN" -eq 0 ]; then
    step "Installing Starship"
    run sh -c "$(curl -fsSL https://starship.rs/install.sh)" -- --yes
    ok "Starship installed"
  fi

  [ "$INSTALL_FONT" -eq 1 ] && [ "$OS" = "Linux" ] && install_nerd_font_linux
  return 0
}

install_nerd_font_linux() {
  local font_dir="$HOME/.local/share/fonts"
  if fc-list 2>/dev/null | grep -qi "jetbrainsmono nerd"; then
    skip "JetBrains Mono Nerd Font already installed"
    return 0
  fi

  step "Installing JetBrains Mono Nerd Font"
  local tmp
  tmp="$(mktemp -d)"
  run mkdir -p "$font_dir"
  run curl -fsSL -o "$tmp/JetBrainsMono.zip" \
    "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
  run unzip -qo "$tmp/JetBrainsMono.zip" -d "$font_dir"
  run fc-cache -f
  run rm -rf "$tmp"
  ok "JetBrains Mono Nerd Font"
}

# ------------------------------------------------------------
# Oh My Zsh + custom plugins
#
# The Homebrew formulae for zsh-autosuggestions / zsh-syntax-highlighting
# aren't enough on their own: oh-my-zsh's plugins=() array only looks
# inside $ZSH_CUSTOM/plugins, so they have to be cloned there too.
# ------------------------------------------------------------
install_omz() {
  step "Oh My Zsh"

  # Honour an exported $ZSH rather than assuming ~/.oh-my-zsh. The upstream
  # installer targets $ZSH, so if the caller has it pointing elsewhere — which
  # any existing oh-my-zsh user does, since their .zshrc exports it — checking
  # $HOME/.oh-my-zsh would look in one place while the install went to another,
  # and the installer would abort on a directory we never examined.
  local omz_dir="${ZSH:-$HOME/.oh-my-zsh}"

  if [ -d "$omz_dir" ]; then
    skip "already installed at $(printf '%s' "$omz_dir" | sed "s|$HOME|~|")"
  else
    info "Installing from ohmyzsh/ohmyzsh"
    # RUNZSH=no stops the installer dropping into a new shell and halting
    # this script; KEEP_ZSHRC=yes stops it rewriting ~/.zshrc. ZSH is passed
    # explicitly so the target can never drift from the check above.
    run sh -c "RUNZSH=no KEEP_ZSHRC=yes ZSH='$omz_dir' \
      $(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    ok "Oh My Zsh installed"
  fi

  local custom="${ZSH_CUSTOM:-$omz_dir/custom}"
  local plugin
  for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
    if [ -d "$custom/plugins/$plugin" ]; then
      skip "$plugin already cloned"
    else
      run git clone --depth 1 "https://github.com/zsh-users/$plugin" "$custom/plugins/$plugin"
      ok "$plugin"
    fi
  done
}

# ------------------------------------------------------------
# Config
# ------------------------------------------------------------
install_configs() {
  step "Installing config  (theme: $THEME_LABEL)"

  install_file "$REPO_DIR/config/zsh/furnizsh.zsh" "$FURNIZSH_HOME/furnizsh.zsh"
  install_file "$REPO_DIR/config/zsh/functions.zsh" "$FURNIZSH_HOME/functions.zsh"

  if [ "$INSTALL_EXTRAS" -eq 1 ]; then
    install_file "$REPO_DIR/config/zsh/extras.zsh" "$FURNIZSH_HOME/extras.zsh"
  else
    skip "extras.zsh skipped (--no-extras)"
    [ -f "$FURNIZSH_HOME/extras.zsh" ] && run rm -f "$FURNIZSH_HOME/extras.zsh"
  fi

  # Every theme definition ships, so `theme <name>` can switch later
  # without needing the repo checkout.
  run mkdir -p "$FURNIZSH_HOME/themes/lazygit"
  local f
  for f in "$REPO_DIR"/config/themes/*.theme; do
    install_file "$f" "$FURNIZSH_HOME/themes/$(basename "$f")"
  done
  for f in "$REPO_DIR"/config/themes/lazygit/*.yml; do
    install_file "$f" "$FURNIZSH_HOME/themes/lazygit/$(basename "$f")"
  done

  install_theme
  install_tmux
}

# Apply the selected theme's three configs.
install_theme() {
  # --- Ghostty: base config with the theme line swapped in ---
  local ghostty_dest="$HOME/.config/ghostty/config"
  local tmp
  if [ "$DRY_RUN" -eq 1 ]; then
    printf "    %s[dry-run]%s write ghostty config with theme = %s\n" "$C_GRAY" "$C_RESET" "$GHOSTTY_THEME"
  else
    backup "$ghostty_dest"
    mkdir -p "$(dirname "$ghostty_dest")"
    tmp="$(mktemp)"
    sed "s|^theme = .*|theme = $GHOSTTY_THEME|" "$REPO_DIR/config/ghostty/config" > "$tmp"
    mv "$tmp" "$ghostty_dest"
    # shellcheck disable=SC2088  # display text, not a path being expanded
    ok "~/.config/ghostty/config  (theme = $GHOSTTY_THEME)"
  fi

  # --- Starship: generated from the preset, with the shipped file as fallback ---
  if [ "$DRY_RUN" -eq 1 ]; then
    printf "    %s[dry-run]%s starship preset %s -o ~/.config/starship.toml\n" "$C_GRAY" "$C_RESET" "$STARSHIP_PRESET"
  elif command -v starship >/dev/null 2>&1; then
    backup "$HOME/.config/starship.toml"
    mkdir -p "$HOME/.config"
    # --force is required: starship refuses to overwrite an existing config.
    # The previous file was backed up two lines above, so this is safe.
    if starship preset "$STARSHIP_PRESET" --force -o "$HOME/.config/starship.toml" 2>/dev/null; then
      # shellcheck disable=SC2088  # display text, not a path being expanded
      ok "~/.config/starship.toml  ($STARSHIP_PRESET)"
    else
      warn "starship has no preset '$STARSHIP_PRESET' — using the bundled Catppuccin config"
      cp "$REPO_DIR/config/starship/starship.toml" "$HOME/.config/starship.toml"
    fi
  else
    install_file "$REPO_DIR/config/starship/starship.toml" "$HOME/.config/starship.toml"
  fi

  # --- lazygit ---
  local lazygit_dir
  if command -v lazygit >/dev/null 2>&1; then
    lazygit_dir="$(lazygit --print-config-dir 2>/dev/null || true)"
  fi
  if [ -z "${lazygit_dir:-}" ]; then
    if [ "$OS" = "Darwin" ]; then
      lazygit_dir="$HOME/Library/Application Support/lazygit"
    else
      lazygit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/lazygit"
    fi
  fi
  install_file "$REPO_DIR/config/themes/lazygit/$LAZYGIT_PALETTE.yml" "$lazygit_dir/config.yml"

  # Record the active theme and version so `theme`, `cheatsheet` and
  # `fzdoctor` can report them without needing the repo on disk.
  if [ "$DRY_RUN" -eq 0 ]; then
    mkdir -p "$FURNIZSH_HOME"
    printf '%s' "$THEME" > "$FURNIZSH_HOME/current-theme"
    printf '%s' "$FURNIZSH_VERSION" > "$FURNIZSH_HOME/VERSION"

    # Record how furnizsh got here, so `fzupdate` runs the right updater
    # rather than assuming a git checkout — most people install another way.
    method="git"
    case "$REPO_DIR" in
      */Cellar/furnizsh/*)          method="brew"  ;;
      */node_modules/furnizsh*)     method="npm"   ;;
      "$HOME/.local/share/furnizsh") method="curl" ;;
      *) [ -d "$REPO_DIR/.git" ] || method="unknown" ;;
    esac
    printf '%s\n%s\n' "$method" "$REPO_DIR" > "$FURNIZSH_HOME/install-source"
  fi
}

install_tmux() {
  [ "$INSTALL_TMUX" -eq 1 ] || { skip "tmux config skipped"; return 0; }
  install_file "$REPO_DIR/config/tmux/tmux.conf" "$HOME/.tmux.conf"
}

# ------------------------------------------------------------
# Wire into ~/.zshrc — one guarded source line, appended.
# ------------------------------------------------------------
wire_zshrc() {
  step "Wiring into ~/.zshrc"

  local zshrc="$HOME/.zshrc"

  if [ -f "$zshrc" ] && grep -qF "$MARKER_START" "$zshrc"; then
    skip "already sourced — nothing to do"
    return 0
  fi

  backup "$zshrc"

  if [ "$DRY_RUN" -eq 1 ]; then
    printf "    %s[dry-run]%s append source block to ~/.zshrc\n" "$C_GRAY" "$C_RESET"
    return 0
  fi

  cat >>"$zshrc" <<EOF

$MARKER_START
# Managed by furnizsh — https://github.com/Wosmos/furnizsh
# Everything below the marker is loaded from ~/.config/furnizsh/.
# Remove this block (or run ./uninstall.sh) to opt out.
[ -f "\$HOME/.config/furnizsh/furnizsh.zsh" ] && source "\$HOME/.config/furnizsh/furnizsh.zsh"
$MARKER_END
EOF

  ok "source block appended"
  warn "furnizsh initializes Starship, which must run last. Keep any prompt-related"
  warn "config you add later ABOVE the furnizsh block."
}

# ------------------------------------------------------------
# git-delta — applied with `git config`, never by rewriting ~/.gitconfig
# ------------------------------------------------------------
configure_git() {
  step "Configuring git-delta"

  if ! command -v delta >/dev/null 2>&1 && [ "$DRY_RUN" -eq 0 ]; then
    warn "delta not installed — skipping"
    return 0
  fi

  local current
  current="$(git config --global core.pager 2>/dev/null || true)"
  if [ "$current" = "delta" ]; then
    skip "already configured"
    return 0
  fi
  if [ -n "$current" ]; then
    warn "core.pager is currently '$current'"
    confirm "Replace it with delta?" || { skip "left as-is"; return 0; }
  fi

  run git config --global core.pager "delta"
  run git config --global interactive.diffFilter "delta --color-only"
  run git config --global delta.navigate "true"
  ok "delta set as the git pager"
}

# ------------------------------------------------------------
# Default shell
# ------------------------------------------------------------
set_default_shell() {
  [ "$DO_CHSH" -eq 1 ] || { skip "skipping shell change (--no-chsh)"; return 0; }

  step "Default shell"

  local zsh_path
  zsh_path="$(command -v zsh || true)"
  [ -n "$zsh_path" ] || { warn "zsh not found on PATH — skipping"; return 0; }

  if [ "${SHELL##*/}" = "zsh" ]; then
    skip "zsh is already your login shell"
    return 0
  fi

  info "Your login shell is $SHELL"
  confirm "Change it to $zsh_path?" || { skip "left as-is"; return 0; }

  # chsh only accepts shells listed in /etc/shells.
  if ! grep -qxF "$zsh_path" /etc/shells 2>/dev/null; then
    info "Adding $zsh_path to /etc/shells (needs sudo)"
    run sh -c "echo '$zsh_path' | sudo tee -a /etc/shells >/dev/null"
  fi

  run chsh -s "$zsh_path"
  ok "login shell set to zsh — takes effect in a new terminal"
}

# ------------------------------------------------------------
# Optional Claude Code extras
# ------------------------------------------------------------
install_claude_extras() {
  [ "$INSTALL_CLAUDE" -eq 1 ] || return 0
  [ -d "$HOME/.claude" ] || { skip "Claude Code not detected — skipping extras"; return 0; }

  step "Claude Code extras"
  if [ "$OS" = "Darwin" ]; then
    info "Desktop notifications on task completion, and a statusline."
  else
    info "Statusline only — the notification hook is macOS-only (it's built on"
    info "osascript, afplay and say), so it isn't installed here."
  fi
  info "Details: extras/claude-code/README.md"
  confirm "Install them?" || { skip "skipped"; return 0; }

  install_file "$REPO_DIR/extras/claude-code/statusline.sh" "$HOME/.claude/statusline.sh"
  run chmod +x "$HOME/.claude/statusline.sh"

  if [ "$OS" = "Darwin" ]; then
    run mkdir -p "$HOME/.claude/hooks"
    install_file "$REPO_DIR/extras/claude-code/cc-alert.sh" "$HOME/.claude/hooks/cc-alert.sh"
    run chmod +x "$HOME/.claude/hooks/cc-alert.sh"
  else
    skip "cc-alert.sh skipped (macOS only)"
  fi

  ok "installed — see extras/claude-code/README.md to wire them into settings.json"
}

# ------------------------------------------------------------
# main
# ------------------------------------------------------------
main() {
  printf "\n%s%s  furnizsh%s %s%s%s  %sa neon terminal, in one command%s\n" \
    "$C_BOLD" "$C_BLUE" "$C_RESET" "$C_GRAY" "$FURNIZSH_VERSION" "$C_RESET" "$C_GRAY" "$C_RESET"
  printf "  %shttps://github.com/Wosmos/furnizsh%s\n" "$C_GRAY" "$C_RESET"

  [ "$DRY_RUN" -eq 1 ] && printf "\n  %s%sDRY RUN — nothing will be changed.%s\n" "$C_BOLD" "$C_ORANGE" "$C_RESET"

  detect_platform

  printf "\n  %stheme%s   %s (%s)\n" "$C_GRAY" "$C_RESET" "$THEME_LABEL" "$THEME"
  printf "  %stools%s   %s\n" "$C_GRAY" "$C_RESET" "$TOOLSET"
  printf "  %splatform%s %s / %s\n" "$C_GRAY" "$C_RESET" "$OS" "$PKG"

  ensure_homebrew
  install_packages
  install_omz
  install_configs
  wire_zshrc
  configure_git
  set_default_shell
  install_claude_extras

  step "Done"
  if [ "$DRY_RUN" -eq 1 ]; then
    info "That was a dry run. Rerun without --dry-run to apply."
  else
    [ -d "$BACKUP_DIR" ] && info "Backups: ${BACKUP_DIR/#$HOME/~}"
    info "Open a new terminal, then run:"
    printf "      %scheatsheet%s   the reference\n" "$C_YELLOW" "$C_RESET"
    printf "      %sfzdoctor%s     verify every piece of the setup\n" "$C_YELLOW" "$C_RESET"
    printf "      %stheme%s        list themes, or switch to another\n" "$C_YELLOW" "$C_RESET"
    [ "$OS" = "Darwin" ] && info "Set Ghostty's font to JetBrainsMono Nerd Font Mono if icons show as boxes."
  fi
  printf "\n"
}

main "$@"
