# Releasing

For maintainers. If you just want to update your own install, run `fzupdate`.

## The problem this solves

Five files have to carry the same version number:

| File | Where |
|---|---|
| `VERSION` | source of truth |
| `CHANGELOG.md` | topmost `## [x.y.z]` heading |
| `packaging/npm/package.json` | `version` |
| `packaging/powershell/furnizsh.psd1` | `ModuleVersion` |
| `packaging/homebrew/furnizsh.rb` | the tag in `url` |

CI fails the build if any one of them disagrees, so editing them by hand is a
good way to lose ten minutes to a typo.

## Cutting a release

```bash
./scripts/bump.sh patch          # 1.0.0 -> 1.0.1
./scripts/bump.sh minor          # 1.0.0 -> 1.1.0
./scripts/bump.sh major          # 1.0.0 -> 2.0.0
./scripts/bump.sh 1.4.2          # explicit
./scripts/bump.sh patch --dry-run
```

It refuses to run on a dirty tree or over an existing tag, edits all five files,
opens an empty `## [x.y.z]` section in the changelog, and re-runs the same
consistency check CI does. It does **not** commit, tag or push — those stay
manual, and it prints the exact commands when it finishes.

Then:

```bash
# fill in the CHANGELOG section first — bump.sh leaves it empty on purpose
git add -A && git commit -m "release: v1.1.0"
git tag v1.1.0
git push origin main --follow-tags
```

The tag push is what actually publishes. It triggers `.github/workflows/release.yml`,
which creates the GitHub Release, publishes to npm and the PowerShell Gallery,
and updates the Homebrew tap.

## What the bump script deliberately leaves alone

The formula's `sha256`. GitHub generates the release tarball from the tag, and
tar embeds mtimes derived from commit dates — so the checksum cannot be known
until the tag exists. The release workflow computes it and commits it to the tap.

## Which bump

- **patch** — fixes, doc changes, a new theme variant. Nothing anyone has to
  react to.
- **minor** — new commands, new flags, new platform support. Existing setups keep
  working untouched.
- **major** — a command is removed or renamed, a flag changes meaning, or the
  `.zshrc` block layout changes such that an old install will not cleanly
  upgrade.

`fzupdate` re-runs the installer, which is append-only and idempotent, so minor
and patch upgrades never need a manual step. A major one should say what to do
in its changelog entry.

## Before you push

Release timestamps are public and cannot be rewritten afterwards — the GitHub
Release `published_at`, the npm publish time and the Gallery publish time are all
stamped at push. Commit dates can be rewritten; those three cannot.

## If a publish fails

Every job in the release workflow is idempotent — it checks whether that version
is already published and skips rather than failing. So the normal fix (add the
missing secret, re-run the workflow) works without bumping the version again.
