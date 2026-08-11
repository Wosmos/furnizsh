#!/usr/bin/env bash
# ============================================================
#  furnizsh — uninstaller
#  https://github.com/Wosmos/furnizsh
#
#  Removes the source block from ~/.zshrc, deletes the furnizsh
#  config directory, and optionally restores the configs that
#  install.sh backed up.
#
#  It does NOT uninstall the tools (starship, eza, bat, ...) or
#  Oh My Zsh unless you pass --tools — those are generally useful
#  on their own and you probably want to keep them.
#
#  Usage:
#    ./uninstall.sh [--dry-run] [--yes] [--restore] [--tools]
# ============================================================

set -euo pipefail

FURNIZSH_HOME="$HOME/.config/furnizsh"
BACKUP_ROOT="$HOME/.furnizsh-backup"
MARKER_START="# >>> furnizsh >>>"
MARKER_END="# <<< furnizsh <<<"

DRY_RUN=0
ASSUME_YES=0
RESTORE=0
REMOVE_TOOLS=0

if [ -t 1 ]; then
  C_ORANGE=$'\033[38;2;250;179;135m'
  C_GREEN=$'\033[38;2;166;227;161m'
  C_BLUE=$'\033[38;2;137;180;250m'
  C_GRAY=$'\033[38;2;108;112;134m'
  C_BOLD=$'\033[1m'
  C_RESET=$'\033[0m'
else
  C_ORANGE='' C_GREEN='' C_BLUE='' C_GRAY='' C_BOLD='' C_RESET=''
fi

step()  { printf "\n%s%s==>%s %s\n" "$C_BOLD" "$C_BLUE" "$C_RESET" "$1"; }
info()  { printf "    %s\n" "$1"; }
ok()    { printf "    %s✓%s %s\n" "$C_GREEN" "$C_RESET" "$1"; }
skip()  { printf "    %s· %s%s\n" "$C_GRAY" "$1" "$C_RESET"; }
warn()  { printf "    %s! %s%s\n" "$C_ORANGE" "$1" "$C_RESET"; }
die()   { printf "\n%serror:%s %s\n\n" "$C_ORANGE" "$C_RESET" "$1" >&2; exit 1; }

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
furnizsh uninstaller

  ./uninstall.sh [options]

Options:
  --dry-run   print every action without changing anything
  --yes       don't prompt for confirmation
  --restore   restore the configs from the most recent backup
  --tools     also uninstall the CLI tools and Oh My Zsh (asks first)
  -h, --help  this message
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --yes|-y)  ASSUME_YES=1 ;;
    --restore) RESTORE=1 ;;
    --tools)   REMOVE_TOOLS=1 ;;
    -h|--help) usage; exit 0 ;;
    *)         die "unknown option: $1 (try --help)" ;;
  esac
  shift
done

# ------------------------------------------------------------
# Remove the guarded block from ~/.zshrc
# ------------------------------------------------------------
unwire_zshrc() {
  step "Removing the block from ~/.zshrc"

  local zshrc="$HOME/.zshrc"
  if [ ! -f "$zshrc" ] || ! grep -qF "$MARKER_START" "$zshrc"; then
    skip "no furnizsh block found"
    return 0
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    printf "    %s[dry-run]%s strip the marked block from ~/.zshrc\n" "$C_GRAY" "$C_RESET"
    return 0
  fi

  # Keep a safety copy of the pre-edit .zshrc regardless.
  cp -a "$zshrc" "$zshrc.furnizsh-uninstall.bak"

  # Delete everything between the markers, inclusive. Portable across
  # BSD and GNU sed (no -i, no in-place extension differences).
  local tmp
  tmp="$(mktemp)"
  sed "/^${MARKER_START}\$/,/^${MARKER_END}\$/d" "$zshrc" >"$tmp"
  mv "$tmp" "$zshrc"

  ok "removed (pre-edit copy at ~/.zshrc.furnizsh-uninstall.bak)"
}

# ------------------------------------------------------------
# Delete ~/.config/furnizsh
# ------------------------------------------------------------
remove_config_dir() {
  step "Removing ~/.config/furnizsh"
  if [ ! -d "$FURNIZSH_HOME" ]; then
    skip "not present"
    return 0
  fi
  run rm -rf "$FURNIZSH_HOME"
  ok "removed"
}

# ------------------------------------------------------------
# Restore configs from the newest backup
# ------------------------------------------------------------
restore_backup() {
  [ "$RESTORE" -eq 1 ] || return 0

  step "Restoring from backup"

  if [ ! -d "$BACKUP_ROOT" ]; then
    warn "no backups found under ~/.furnizsh-backup"
    return 0
  fi

  local newest
  newest="$(ls -1d "$BACKUP_ROOT"/*/ 2>/dev/null | sort | tail -1)"
  [ -n "$newest" ] || { warn "no backup directories found"; return 0; }
  newest="${newest%/}"

  info "Newest backup: ${newest/#$HOME/~}"
  info "Contents:"
  local f
  for f in "$newest"/*; do
    [ -e "$f" ] && info "  $(basename "$f")"
  done

  warn "Restoring copies files back over your current config."
  confirm "Restore them?" || { skip "left as-is"; return 0; }

  # Map each backed-up basename to where it came from. install.sh only
  # ever backs up this fixed set, so an explicit table is safer than
  # trying to infer paths.
  local lazygit_dir
  if [ "$(uname -s)" = "Darwin" ]; then
    lazygit_dir="$HOME/Library/Application Support/lazygit"
  else
    lazygit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/lazygit"
  fi

  for f in "$newest"/*; do
    [ -e "$f" ] || continue
    local name dest
    name="$(basename "$f")"
    case "$name" in
      .zshrc)        dest="$HOME/.zshrc" ;;
      starship.toml) dest="$HOME/.config/starship.toml" ;;
      config)        dest="$HOME/.config/ghostty/config" ;;
      config.yml)    dest="$lazygit_dir/config.yml" ;;
      furnizsh.zsh|functions.zsh) continue ;;
      cc-alert.sh)   dest="$HOME/.claude/hooks/cc-alert.sh" ;;
      statusline.sh) dest="$HOME/.claude/statusline.sh" ;;
      *)             warn "don't know where $name came from — skipping"; continue ;;
    esac
    run cp -a "$f" "$dest"
    ok "restored ${dest/#$HOME/~}"
  done
}

# ------------------------------------------------------------
# git-delta
# ------------------------------------------------------------
unconfigure_git() {
  step "git-delta"

  if [ "$(git config --global core.pager 2>/dev/null || true)" != "delta" ]; then
    skip "delta isn't the configured pager"
    return 0
  fi

  confirm "Unset delta as your git pager?" || { skip "left as-is"; return 0; }
  run git config --global --unset core.pager || true
  run git config --global --unset interactive.diffFilter || true
  run git config --global --unset delta.navigate || true
  ok "unset"
}

# ------------------------------------------------------------
# Tools (opt-in)
# ------------------------------------------------------------
remove_tools() {
  [ "$REMOVE_TOOLS" -eq 1 ] || return 0

  step "Uninstalling tools"
  warn "This removes starship, zoxide, eza, bat, fd, delta, lazygit and fzf."
  warn "They're useful outside furnizsh — you probably want to keep them."
  confirm "Uninstall them anyway?" || { skip "kept"; return 0; }

  if command -v brew >/dev/null 2>&1; then
    run brew uninstall --ignore-dependencies starship zoxide eza bat fd git-delta lazygit fzf \
      zsh-autosuggestions zsh-syntax-highlighting || true
    ok "brew packages removed"
  else
    warn "no Homebrew — remove them with your distro's package manager"
  fi

  if [ -d "$HOME/.oh-my-zsh" ]; then
    confirm "Also remove Oh My Zsh (~/.oh-my-zsh)?" && {
      run rm -rf "$HOME/.oh-my-zsh"
      ok "Oh My Zsh removed"
    }
  fi
}

main() {
  printf "\n%s%s  furnizsh uninstall%s\n" "$C_BOLD" "$C_BLUE" "$C_RESET"
  [ "$DRY_RUN" -eq 1 ] && printf "\n  %s%sDRY RUN — nothing will be changed.%s\n" "$C_BOLD" "$C_ORANGE" "$C_RESET"

  unwire_zshrc
  remove_config_dir
  restore_backup
  unconfigure_git
  remove_tools

  step "Done"
  if [ "$DRY_RUN" -eq 1 ]; then
    info "That was a dry run. Rerun without --dry-run to apply."
  else
    info "Open a new terminal for the change to take effect."
    [ -d "$BACKUP_ROOT" ] && info "Your backups are still at ${BACKUP_ROOT/#$HOME/~} — delete them when you're happy."
  fi
  printf "\n"
}

main "$@"
