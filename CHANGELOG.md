# Changelog

Notable changes to furnizsh. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.1.0] — 2026-08-13

First release. Pre-1.0 on purpose: the macOS and Linux paths are exercised
end-to-end by CI on Ubuntu, Fedora and Arch, but the PowerShell scripts are
linted rather than executed, so Windows is untested. Expect the command set to
move before 1.0.

### Added

- `furnizsh update` — the conventional entry point, matching `brew upgrade` and
  friends. The update logic now lives in `update.sh`, which both it and
  `fzupdate` run, so there is one implementation rather than two that drift.
  `--check` reports whether an update exists without installing it.
- `scripts/bump.sh` — bumps the version across all five files CI cross-checks,
  promotes the `Unreleased` changelog section, and re-runs the consistency
  check. Documented in [docs/RELEASING.md](docs/RELEASING.md).
- `install.sh` and `install.ps1` now record how furnizsh was installed, in
  `~/.config/furnizsh/install-source`.
- `install.ps1` stamps the installed version, which it never did before — so
  Windows had no version to report.

### Changed

- `fzupdate` updates by whichever channel you installed from — the bootstrap
  script, Homebrew, npm, the PowerShell Gallery or a git checkout — instead of
  assuming a git checkout and failing for everyone else. It also checks the
  current release first and stops early if you are already on it.

### Fixed

- `fzupdate` reported success even when the update had failed.
- Uninstall left behind the blank line the installer wrote above its block, so
  a full cycle did not restore `.zshrc` byte-for-byte as documented. CI now
  asserts byte-equality instead of only grepping the marker away.

First public release.

### The setup

- Ghostty + zsh + Oh My Zsh + Starship, themed and wired together
- Core tools: eza, bat, fd, zoxide, fzf, git-delta, lazygit
- Oh My Zsh with 17 plugins, plus `macos` and `brew` on macOS
- Terminal title shows the current directory rather than the running command

### Themes

- Four complete looks — `neon`, `catppuccin`, `gruvbox`, `tokyonight`
- `theme <name>` switches Ghostty, Starship and lazygit together, so they can't
  drift apart
- `--theme` at install time picks the starting look

### Tool sets

- `--tools core` (default) — the eight tools the setup needs
- `--tools extended` — adds ripgrep, tmux, jq, direnv, tldr, btop
- `--tools all` — adds atuin, yq, httpie, dust, procs, gh
- tmux ships with a matching themed config

### Commands

24 helpers, in both zsh and PowerShell:

- **Core** — `cheatsheet`/`chs`, `fzdoctor`, `theme`, `fzupdate`, `mkcd`, `up`,
  `serve`, `ports`, `killport`, `fkill`, `fe`, `bak`, `sizeof`, `gprune`,
  `paths`, `reload`
- **Extras** (need network, skip with `--no-extras`) — `weather`, `cheat`, `qr`,
  `gitignore`, `note`, `timer`, `sysinfo`, `dockerclean`

### Platforms

- macOS and Linux: `install.sh`, `uninstall.sh`, `doctor.sh`
- Windows: `install.ps1`, `uninstall.ps1`, `doctor.ps1`, a full PowerShell
  profile, and Windows Terminal colour schemes
- Ghostty has no Windows build, so Windows gets either WSL2 or the native
  PowerShell route — both documented

### Safety

- The installer never overwrites `~/.zshrc`; it appends one marked `source` line
- Everything replaced is backed up to `~/.furnizsh-backup/<timestamp>/`
- Idempotent, and `./uninstall.sh` restores the original byte-for-byte
- `--dry-run` prints every action and changes nothing
- Login-shell changes, git pager replacement and profile overwrites all prompt

### Distribution

- `curl -fsSL https://wosmos.github.io/furnizsh/install | sh` — no clone, ~50 KB
- Homebrew tap: `brew tap wosmos/tap && brew install furnizsh`
- npm: `npm i -g furnizsh` (63 KB published)
- PowerShell Gallery: `Install-Module furnizsh`
- An `furnizsh` command wrapping install / uninstall / doctor / theme / version
- Tag-triggered release workflow with build provenance attestation

### CI

- shellcheck and zsh parse checks on every push
- PSScriptAnalyzer and a parse check for every `.ps1`
- YAML/JSON/TOML validation, and a check that every theme's keys and referenced
  palette exist
- A secrets scan that fails on absolute home paths, credential shapes and
  telemetry endpoints
- Full install → verify → idempotency → uninstall in clean Ubuntu, Fedora and
  Arch containers
- The Pages site is checked for well-formedness, self-containment and complete
  theme tokens

### Notes on two bugs found while building this

- `alias ls='eza --icons'` is broken on eza ≥ 0.18: the flag takes an optional
  `WHEN` value, so a bare `--icons` swallows the path and `ls somedir` fails.
  Everything here uses `--icons=auto`.
- `starship preset -o` refuses to overwrite an existing file. Without `--force`,
  every theme switch after the first would silently leave the prompt unchanged.
