# Contributing

Thanks for looking. This is a personal setup that other people are welcome to
use and improve — issues and PRs are both fine.

## Before you open a PR

Run the same checks CI does. All of them are fast:

```bash
shellcheck --severity=warning install.sh uninstall.sh doctor.sh
for f in config/zsh/*.zsh; do zsh -n "$f"; done
./install.sh --dry-run          # must report actions and change nothing
./doctor.sh                     # should be green on a machine that has it installed
```

On Windows:

```powershell
Invoke-ScriptAnalyzer -Path . -Recurse -Severity Error,Warning
.\install.ps1 -DryRun
.\doctor.ps1
```

The full install is exercised in a clean Ubuntu, Fedora and Arch container on
every push, including uninstall and an idempotency check. If your change touches
`install.sh`, expect that job to be the one that catches you.

## The rules that matter

**Never write to `~/.zshrc` beyond the guarded block.** The installer appends one
marked `source` line and nothing else. This is the property that makes it
uninstallable and safe to run on a machine someone actually works on. Don't
"simplify" it into copying a whole `.zshrc`.

**Back up before replacing.** Anything that overwrites a file goes through
`install_file`, which copies the original into `~/.furnizsh-backup/<timestamp>/`
first.

**Everything optional gets a flag.** If your addition isn't needed by everyone,
put it behind `--tools`, `--no-<thing>` or a theme, with a default that keeps a
plain `./install.sh` minimal.

**Guard every external tool.** Shell config is sourced on every prompt; a missing
binary must skip its block silently, not error. Use `command -v` and be aware of
Debian's renames (`fd` → `fdfind`, `bat` → `batcat`).

**No environment-specific anything.** No absolute `/Users/...` or `/home/...`
paths, no telemetry endpoints, no `.env`, no credentials. CI fails the build on
all of these.

**Explain the non-obvious in a comment.** Why `zsh-syntax-highlighting` must be
last, why `--icons=auto` rather than `--icons`, why `starship preset` needs
`--force`. These are the things that get "cleaned up" and quietly break.

## Adding a helper command

A command touches more places than you'd think. All of them:

1. `config/zsh/functions.zsh` — or `extras.zsh` if it needs the network
2. `config/powershell/Microsoft.PowerShell_profile.ps1` — the PowerShell port
3. `cheatsheet()` — both the short and `--comp` output, in both shells
4. `docs/COMMANDS.md` — with an example
5. `docs/CHEATSHEET.md` — the table
6. `docs/index.html` — the command grid
7. `.github/workflows/ci.yml` — add it to the "commands are defined" list

Print a usage line on bad input, and return non-zero. Every existing command does.

## Adding a theme

Four files, and CI checks the wiring:

1. `config/themes/<id>.theme` — all six keys are required
2. `config/themes/lazygit/<palette>.yml` — if you're not reusing one
3. Verify the names are real: `ghostty +list-themes` and `starship preset --list`
4. Add the id to `--theme`'s `ValidateSet` in `install.ps1` and to the help text
   in `install.sh`

## Style

- Two-space indent in shell, four in PowerShell
- Long flags in scripts (`--force`, not `-f`) — they read better in a year
- Comments explain *why*; the code already says what
- British or American spelling, just be consistent within a file

## Reporting a bug

Include the output of `./doctor.sh` (or `agdoctor`), your OS and shell, and the
tool versions involved. `./install.sh --dry-run` output helps for install
problems.
