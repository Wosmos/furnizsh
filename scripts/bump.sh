#!/usr/bin/env bash
# ============================================================
#  bump — cut a new furnizsh version
#
#  Five files have to agree on the version number and CI fails the
#  build if any one of them drifts. Editing them by hand is a trap,
#  so this does all five, writes the CHANGELOG entry, and tags.
#
#    ./scripts/bump.sh patch          0.1.0 -> 0.1.1
#    ./scripts/bump.sh minor          0.1.0 -> 0.2.0
#    ./scripts/bump.sh major          0.1.0 -> 1.0.0
#    ./scripts/bump.sh 1.4.2          explicit
#    ./scripts/bump.sh patch --dry-run
#
#  It does not push. Pushing is a separate, deliberate step —
#  see the reminder it prints at the end.
# ============================================================

set -euo pipefail
cd "$(dirname "$0")/.."

G=$'\033[38;2;166;227;161m'; O=$'\033[38;2;250;179;135m'
D=$'\033[38;2;108;112;134m'; Y=$'\033[38;2;249;226;175m'; R=$'\033[0m'
ok()   { printf "  ${G}✓${R} %s\n" "$1"; }
info() { printf "  ${D}·${R} ${D}%s${R}\n" "$1"; }
die()  { printf "\n  ${O}✗${R} %s\n\n" "$1" >&2; exit 1; }

DRY_RUN=0; SPEC=""
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*)        die "unknown flag: $arg" ;;
    *)         SPEC="$arg" ;;
  esac
done
[ -n "$SPEC" ] || die "usage: bump.sh <patch|minor|major|X.Y.Z> [--dry-run]"

CUR=$(cat VERSION)
IFS=. read -r MA MI PA <<<"$CUR"
case "$SPEC" in
  major) NEW="$((MA+1)).0.0" ;;
  minor) NEW="$MA.$((MI+1)).0" ;;
  patch) NEW="$MA.$MI.$((PA+1))" ;;
  [0-9]*.[0-9]*.[0-9]*) NEW="$SPEC" ;;
  *) die "not a bump kind or a semver: $SPEC" ;;
esac

printf "\n${O}==>${R} furnizsh ${D}%s${R} -> ${Y}%s${R}%s\n\n" "$CUR" "$NEW" \
  "$([ "$DRY_RUN" -eq 1 ] && printf "   ${D}(dry run)${R}")"

# --- preflight -------------------------------------------------
[ "$DRY_RUN" -eq 1 ] || [ -z "$(git status --porcelain)" ] \
  || die "working tree is dirty — commit or stash first"
git rev-parse "v$NEW" >/dev/null 2>&1 && die "tag v$NEW already exists"
[ "$(git rev-parse --abbrev-ref HEAD)" = "main" ] || info "not on main — continuing anyway"
ok "preflight"

edit() { # file, sed-expression
  if [ "$DRY_RUN" -eq 1 ]; then
    printf "  ${D}·${R} would edit ${D}%s${R}\n" "$1"
  else
    perl -pi -e "$2" "$1"
    ok "$1"
  fi
}

# --- the five files CI cross-checks ---------------------------
[ "$DRY_RUN" -eq 1 ] || printf '%s\n' "$NEW" > VERSION
[ "$DRY_RUN" -eq 1 ] && info "would write VERSION" || ok "VERSION"

edit packaging/npm/package.json          "s/\"version\": \"$CUR\"/\"version\": \"$NEW\"/"
edit packaging/powershell/furnizsh.psd1  "s/ModuleVersion += +'$CUR'/ModuleVersion     = '$NEW'/"
edit packaging/homebrew/furnizsh.rb      "s|/v$CUR\.tar\.gz|/v$NEW.tar.gz|"

# The formula's sha256 can only be known after the tag exists — GitHub
# generates the tarball from it, and tar embeds the commit date. The
# release workflow recomputes and commits it to the tap.
info "formula sha256 is recomputed by the release workflow after the tag"

# --- CHANGELOG -------------------------------------------------
DATE=$(date +%F)
if grep -q '^## \[Unreleased\]' CHANGELOG.md; then
  # Standard changelog flow: promote what has accumulated rather than opening
  # a second empty section above it.
  if [ "$DRY_RUN" -eq 1 ]; then
    info "would promote '## [Unreleased]' to '## [$NEW] — $DATE'"
  else
    perl -pi -e "s/^## \\[Unreleased\\].*/## [$NEW] — $DATE/" CHANGELOG.md
    ok "CHANGELOG.md (promoted Unreleased)"
  fi
elif [ "$DRY_RUN" -eq 1 ]; then
  info "would open a '## [$NEW] — $DATE' section"
else
  perl -0pi -e "s/^(# Changelog\n\n)/\$1## [$NEW] — $DATE\n\n### Added\n\n### Changed\n\n### Fixed\n\n/" CHANGELOG.md
  ok "CHANGELOG.md"
fi

# --- verify the same way CI does ------------------------------
if [ "$DRY_RUN" -eq 0 ]; then
  printf "\n${O}==>${R} Consistency check ${D}(same one CI runs)${R}\n"
  fail=0
  check() { # label, actual
    if [ "$2" = "$NEW" ]; then ok "$1  $2"
    else printf "  ${O}✗${R} %s  %s ${D}(expected %s)${R}\n" "$1" "$2" "$NEW"; fail=1; fi
  }
  check "VERSION      " "$(cat VERSION)"
  check "package.json " "$(python3 -c "import json;print(json.load(open('packaging/npm/package.json'))['version'])")"
  check "furnizsh.psd1" "$(sed -n "s/.*ModuleVersion *= *'\([^']*\)'.*/\1/p" packaging/powershell/furnizsh.psd1)"
  check "formula url  " "$(sed -n 's|.*/tags/v\([0-9.]*\)\.tar\.gz.*|\1|p' packaging/homebrew/furnizsh.rb | head -1)"
  check "CHANGELOG    " "$(sed -n 's/^## \[\([0-9]\+\.[0-9]\+\.[0-9]\+\)\].*/\1/p' CHANGELOG.md | head -1)"
  [ "$fail" -eq 0 ] || die "version drift — fix before committing"
fi

# --- what's left -----------------------------------------------
printf "\n${O}==>${R} Next\n"
if [ "$DRY_RUN" -eq 1 ]; then
  info "dry run — nothing was written"
  exit 0
fi
cat <<EOF
  1. Check the ${Y}## [$NEW]${R} section in CHANGELOG.md reads the way you want.
  2. ${Y}git add -A && git commit -m "release: v$NEW"${R}
  3. ${Y}git tag v$NEW${R}
  4. ${Y}git push origin main --follow-tags${R}   ${D}<- publishes to all four channels${R}

  ${D}Step 4 is the point of no return: it fires the release workflow, which
  creates the GitHub Release and publishes to npm and the PowerShell Gallery.
  Those publish timestamps are public and cannot be rewritten afterwards.${R}
EOF
