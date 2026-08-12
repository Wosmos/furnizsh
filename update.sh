#!/usr/bin/env bash
# ============================================================
#  furnizsh — update to the latest release
#
#  Usage:  ./update.sh [--check] [--yes]
#
#  furnizsh can arrive four different ways, and each has its own updater.
#  Running the wrong one leaves the package manager's view of the world out
#  of step with what's actually on disk, so this dispatches on the channel
#  recorded at install time rather than guessing.
#
#  Reached as `furnizsh update`, or as `agupdate` inside zsh.
# ============================================================

set -u

FURNIZSH_HOME="${FURNIZSH_HOME:-$HOME/.config/furnizsh}"
REPO_API="https://api.github.com/repos/Wosmos/furnizsh/releases/latest"
BOOTSTRAP="https://wosmos.github.io/furnizsh/install"

CHECK_ONLY=0
ASSUME_YES=0

for arg in "$@"; do
  case "$arg" in
    --check)   CHECK_ONLY=1 ;;
    --yes|-y)  ASSUME_YES=1 ;;
    --help|-h)
      sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *)
      printf 'update: unknown option %s\n' "$arg" >&2
      exit 1 ;;
  esac
done

if [ -t 1 ]; then
  C_ORANGE=$'\033[38;2;250;179;135m'
  C_YELLOW=$'\033[38;2;249;226;175m'
  C_GREEN=$'\033[38;2;166;227;161m'
  C_GRAY=$'\033[38;2;108;112;134m'
  C_RESET=$'\033[0m'
else
  C_ORANGE='' C_YELLOW='' C_GREEN='' C_GRAY='' C_RESET=''
fi

info() { printf '  %s%s%s\n' "$C_GRAY" "$1" "$C_RESET"; }
ok()   { printf '  %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$1"; }
die()  { printf '  %s✗%s %s\n' "$C_ORANGE" "$C_RESET" "$1" >&2; exit 1; }

installed_version() {
  if [ -f "$FURNIZSH_HOME/VERSION" ]; then
    cat "$FURNIZSH_HOME/VERSION"
  else
    printf 'unknown'
  fi
}

latest_version() {
  command -v curl >/dev/null 2>&1 || return 0
  curl -fsS --max-time 5 "$REPO_API" 2>/dev/null \
    | sed -n 's/.*"tag_name": *"v\{0,1\}\([^"]*\)".*/\1/p' \
    | head -1
}

HERE="$(installed_version)"
LATEST="$(latest_version)"

printf '\n  %sfurnizsh%s  installed %s%s%s' \
  "$C_YELLOW" "$C_RESET" "$C_GRAY" "$HERE" "$C_RESET"
if [ -n "$LATEST" ]; then
  printf '  ·  latest %s%s%s\n\n' "$C_GRAY" "$LATEST" "$C_RESET"
else
  printf '  ·  %scouldn'\''t reach GitHub%s\n\n' "$C_GRAY" "$C_RESET"
fi

if [ -n "$LATEST" ] && [ "$LATEST" = "$HERE" ]; then
  ok "already up to date"
  exit 0
fi

if [ "$CHECK_ONLY" -eq 1 ]; then
  [ -n "$LATEST" ] && info "run 'furnizsh update' to install $LATEST"
  # An available update is not an error; --check reports, it doesn't gate.
  exit 0
fi

# ---- which channel ----
METHOD=''
SOURCE=''
if [ -f "$FURNIZSH_HOME/install-source" ]; then
  METHOD="$(sed -n 1p "$FURNIZSH_HOME/install-source")"
  SOURCE="$(sed -n 2p "$FURNIZSH_HOME/install-source")"
fi

case "$METHOD" in
  brew)
    info "installed with Homebrew"
    brew update || die "brew update failed"
    brew upgrade furnizsh || die "brew upgrade failed"
    furnizsh install --yes || die "reapplying the config failed"
    ;;
  npm)
    info "installed with npm"
    npm install -g furnizsh || die "npm install failed"
    furnizsh install --yes || die "reapplying the config failed"
    ;;
  curl)
    info "installed with the bootstrap script"
    command -v curl >/dev/null 2>&1 || die "curl isn't available"
    if [ "$ASSUME_YES" -eq 1 ]; then
      curl -fsSL "$BOOTSTRAP" | sh -s -- --yes || die "bootstrap failed"
    else
      curl -fsSL "$BOOTSTRAP" | sh || die "bootstrap failed"
    fi
    ;;
  git)
    info "installed from a checkout at $SOURCE"
    [ -d "$SOURCE/.git" ] || die "$SOURCE is no longer a checkout — reinstall to fix"
    git -C "$SOURCE" pull --ff-only || die "git pull failed"
    "$SOURCE/install.sh" --yes || die "reapplying the config failed"
    ;;
  *)
    printf '  %sCan'\''t tell how furnizsh was installed.%s Use the way you got it:\n\n' \
      "$C_ORANGE" "$C_RESET"
    printf '    %sbrew upgrade furnizsh%s\n'  "$C_YELLOW" "$C_RESET"
    printf '    %snpm install -g furnizsh%s\n' "$C_YELLOW" "$C_RESET"
    printf '    %scurl -fsSL %s | sh%s\n'      "$C_YELLOW" "$BOOTSTRAP" "$C_RESET"
    printf '    %sUpdate-Module furnizsh%s   (PowerShell)\n\n' "$C_YELLOW" "$C_RESET"
    exit 1
    ;;
esac

printf '\n'
ok "updated — open a new shell, or run ${C_YELLOW}reload${C_RESET}"
