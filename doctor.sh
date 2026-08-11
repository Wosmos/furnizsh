#!/usr/bin/env bash
# ============================================================
#  afterglow — health check
#  https://github.com/Wosmos/afterglow
#
#  Verifies every part of the setup and tells you the exact command
#  to fix whatever is missing. This is the standalone version; once
#  the shell config is installed, `agdoctor` does the same thing
#  from inside zsh.
#
#  Exits 0 if everything passes, 1 otherwise — safe to use in CI.
#
#  Usage:  ./doctor.sh [--quiet]
# ============================================================

set -uo pipefail   # deliberately no -e: a failing check must not abort the run

QUIET=0
[ "${1:-}" = "--quiet" ] && QUIET=1

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

FAILURES=0
OS="$(uname -s)"

section() { [ "$QUIET" -eq 1 ] || printf "\n%s%s%s%s\n" "$C_BOLD" "$C_ORANGE" "$1" "$C_RESET"; }

# check <label> <fix hint> <command...>
check() {
  local label="$1" hint="$2"
  shift 2
  if "$@" >/dev/null 2>&1; then
    [ "$QUIET" -eq 1 ] || printf "  %s✓%s %-28s\n" "$C_GREEN" "$C_RESET" "$label"
    return 0
  else
    printf "  %s✗%s %-28s %s%s%s\n" "$C_ORANGE" "$C_RESET" "$label" "$C_GRAY" "$hint" "$C_RESET"
    FAILURES=$((FAILURES + 1))
    return 1
  fi
}

AG_VERSION="$(cat "$HOME/.config/afterglow/VERSION" 2>/dev/null || printf 'not installed')"
[ "$QUIET" -eq 1 ] || printf "\n%s%s  afterglow doctor%s  %s(%s)%s\n" \
  "$C_BOLD" "$C_BLUE" "$C_RESET" "$C_GRAY" "$AG_VERSION" "$C_RESET"

# ------------------------------------------------------------
section "Tools"
# ------------------------------------------------------------
for tool in git zsh starship zoxide fzf eza lazygit; do
  check "$tool" "not on PATH — rerun ./install.sh" command -v "$tool"
done

# Debian/Ubuntu rename two of these; either name counts as a pass.
check "bat" "install bat (Debian: batcat)" \
  sh -c 'command -v bat || command -v batcat'
check "fd" "install fd (Debian: fdfind)" \
  sh -c 'command -v fd || command -v fdfind'
check "delta" "install git-delta" command -v delta

# ------------------------------------------------------------
section "Shell"
# ------------------------------------------------------------
check "zsh is the login shell" "chsh -s \"\$(command -v zsh)\"" \
  sh -c '[ "${SHELL##*/}" = zsh ]'

ZSH_DIR="${ZSH:-$HOME/.oh-my-zsh}"
check "oh-my-zsh installed" "rerun ./install.sh" test -d "$ZSH_DIR"

ZSH_CUSTOM_DIR="${ZSH_CUSTOM:-$ZSH_DIR/custom}"
check "zsh-autosuggestions" "git clone into \$ZSH_CUSTOM/plugins" \
  test -d "$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions"
check "zsh-syntax-highlighting" "git clone into \$ZSH_CUSTOM/plugins" \
  test -d "$ZSH_CUSTOM_DIR/plugins/zsh-syntax-highlighting"

check "afterglow.zsh installed" "rerun ./install.sh" \
  test -f "$HOME/.config/afterglow/afterglow.zsh"
check "functions.zsh installed" "rerun ./install.sh" \
  test -f "$HOME/.config/afterglow/functions.zsh"
check "sourced from ~/.zshrc" "rerun ./install.sh" \
  grep -qF ">>> afterglow >>>" "$HOME/.zshrc"

# ------------------------------------------------------------
section "Config"
# ------------------------------------------------------------
check "starship.toml" "rerun ./install.sh" test -f "$HOME/.config/starship.toml"
check "ghostty config" "rerun ./install.sh" test -f "$HOME/.config/ghostty/config"

if [ "$OS" = "Darwin" ]; then
  LAZYGIT_CFG="$HOME/Library/Application Support/lazygit/config.yml"
else
  LAZYGIT_CFG="${XDG_CONFIG_HOME:-$HOME/.config}/lazygit/config.yml"
fi
check "lazygit theme" "rerun ./install.sh" test -f "$LAZYGIT_CFG"

check "delta is the git pager" "git config --global core.pager delta" \
  sh -c '[ "$(git config --global core.pager 2>/dev/null)" = delta ]'

# ------------------------------------------------------------
section "Terminal"
# ------------------------------------------------------------
if [ "$OS" = "Darwin" ]; then
  check "Ghostty installed" "brew install --cask ghostty" test -d "/Applications/Ghostty.app"
  check "JetBrainsMono Nerd Font" "brew install --cask font-jetbrains-mono-nerd-font" \
    sh -c 'ls ~/Library/Fonts /Library/Fonts 2>/dev/null | grep -qi "jetbrainsmono.*nerd"'
else
  check "Ghostty installed" "see ghostty.org/docs/install" command -v ghostty
  check "JetBrainsMono Nerd Font" "see docs/LINUX.md" \
    sh -c 'fc-list 2>/dev/null | grep -qi "jetbrainsmono nerd"'
fi

if [ "$QUIET" -eq 0 ]; then
  printf "\n  %sTruecolor check — these should be three distinct pastel blocks:%s\n" "$C_GRAY" "$C_RESET"
  printf "    \033[48;2;250;179;135m   \033[0m\033[48;2;166;227;161m   \033[0m\033[48;2;137;180;250m   \033[0m\n"
  printf "\n  %sNerd Font check — these should be icons, not boxes:%s\n" "$C_GRAY" "$C_RESET"
  printf "         \n"
fi

# ------------------------------------------------------------
if [ "$FAILURES" -eq 0 ]; then
  [ "$QUIET" -eq 1 ] || printf "\n%s%s  All good.%s Run %scheatsheet%s for the reference.\n\n" \
    "$C_BOLD" "$C_GREEN" "$C_RESET" "$C_YELLOW" "$C_RESET"
  exit 0
else
  printf "\n%s%s  %d check(s) failed.%s Docs: https://wosmos.github.io/afterglow\n\n" \
    "$C_BOLD" "$C_ORANGE" "$FAILURES" "$C_RESET"
  exit 1
fi
