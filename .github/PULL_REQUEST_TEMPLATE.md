## What this changes

<!-- One or two sentences. -->

## Why

<!-- The problem it solves. -->

## Checks

- [ ] `shellcheck --severity=warning install.sh uninstall.sh doctor.sh` is clean
- [ ] `zsh -n` passes on every file in `config/zsh/`
- [ ] `./install.sh --dry-run` reports the change and modifies nothing
- [ ] `./doctor.sh` is green after installing

If it adds a command, all seven places are updated (see CONTRIBUTING.md):

- [ ] `functions.zsh` or `extras.zsh`
- [ ] the PowerShell profile
- [ ] `cheatsheet` output, short and `--comp`, in both shells
- [ ] `docs/COMMANDS.md`
- [ ] `docs/CHEATSHEET.md`
- [ ] `site/commands.html`
- [ ] the CI "commands are defined" list

## Anything reviewers should know

<!-- Trade-offs, things you weren't sure about, follow-ups. -->
