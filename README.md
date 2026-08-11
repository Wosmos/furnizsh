<div align="center">

# afterglow

**A neon terminal — Ghostty + zsh + Starship, in one command.**

Four matched themes, 24 helper commands, and the modern replacements for `ls`,
`cat`, `find`, `cd`, `diff` and `git` — installed, themed to match, and wired
together. macOS, Linux and Windows.

[**Docs**](https://wosmos.github.io/afterglow) ·
[Setup guide](docs/SETUP.md) ·
[Cheatsheet](docs/CHEATSHEET.md) ·
[Commands](docs/COMMANDS.md) ·
[Changelog](CHANGELOG.md)

![macOS](https://img.shields.io/badge/macOS-supported-a6e3a1?style=flat-square)
![Linux](https://img.shields.io/badge/Linux-supported-a6e3a1?style=flat-square)
![Windows](https://img.shields.io/badge/Windows-PowerShell%20%2F%20WSL2-f9e2af?style=flat-square)
![License](https://img.shields.io/badge/license-MIT-cba6f7?style=flat-square)

</div>

---

## Install

```bash
curl -fsSL https://wosmos.github.io/afterglow/install | sh
```

Or through a package manager:

```bash
brew tap wosmos/tap && brew install afterglow && afterglow install   # macOS, Linux
npm i -g afterglow-terminal && afterglow install                     # anywhere with Node
```

```powershell
Install-Module afterglow -Scope CurrentUser; Install-Afterglow       # Windows
```

Or clone it, if you'd rather read every line first:

```bash
git clone https://github.com/Wosmos/afterglow.git
cd afterglow
./install.sh
```

See exactly what it would do first — this changes nothing:

```bash
curl -fsSL https://wosmos.github.io/afterglow/install | sh -s -- --dry-run
```

Then open a new terminal and run `agdoctor` to verify, `cheatsheet` for the
reference card, or `theme` to try a different look.

**Windows:** `.\install.ps1` instead — see [docs/WINDOWS.md](docs/WINDOWS.md).

---

## Pick what you want

Everything optional is behind a flag. A plain `./install.sh` stays minimal.

```bash
./install.sh --theme gruvbox --tools extended
./install.sh --tools all --yes
./install.sh --theme catppuccin --no-extras --no-claude
```

| Flag | Default | What |
|---|---|---|
| `--theme <name>` | `neon` | `neon` · `catppuccin` · `gruvbox` · `tokyonight` |
| `--tools <set>` | `core` | `core` · `extended` · `all` — see below |
| `--dry-run` | off | print every action, change nothing |
| `--yes` | off | don't prompt (non-interactive installs) |
| `--no-font` | off | skip the Nerd Font |
| `--no-tmux` | off | skip the tmux config |
| `--no-extras` | off | skip the network-dependent commands |
| `--no-claude` | off | skip the Claude Code extras |
| `--no-chsh` | off | don't change your login shell |

`.\install.ps1` takes the same options in PowerShell form: `-Theme`, `-Tools`,
`-DryRun`, `-Yes`, `-NoFont`, `-NoExtras`, `-NoTerminal`.

---

## It won't wreck your setup

This is the part most dotfiles repos get wrong. afterglow:

- **Never overwrites your `~/.zshrc`.** It appends one guarded `source` line and
  keeps everything else. Your PATH exports, work tooling and aliases — untouched.
- **Backs up every file it replaces** to `~/.afterglow-backup/<timestamp>/`.
- **Is idempotent.** Run it as often as you like; it only changes what drifted.
- **Uninstalls cleanly.** `./uninstall.sh` strips the block and restores your
  originals. Verified in CI — your `.zshrc` comes back byte-for-byte.
- **Asks before anything irreversible** — changing your login shell, replacing an
  existing git pager, overwriting a profile you wrote.

Every push runs the full install, verify, rerun and uninstall cycle in clean
Ubuntu, Fedora and Arch containers.

---

## Themes

One command switches Ghostty, Starship and lazygit together, so they can never
drift apart.

```bash
theme              # list them, with the active one marked
theme gruvbox      # switch everything
```

| | Terminal | Prompt | Feel |
|---|---|---|---|
| **neon** | Ghostty `Neon` | catppuccin-powerline | Near-black with glowing accents. The default. |
| **catppuccin** | `Catppuccin Mocha` | catppuccin-powerline | Soft pastels on deep plum. Everything matches exactly. |
| **gruvbox** | `Gruvbox Dark` | gruvbox-rainbow | Warm retro earth tones. Low contrast, easy for long sessions. |
| **tokyonight** | `TokyoNight` | tokyo-night | Cool blues and violets. Calm, high legibility. |

Adding your own is four files — see [CONTRIBUTING.md](CONTRIBUTING.md#adding-a-theme).

---

## What you get

### The tools

**`--tools core`** — the eight the setup actually needs:

| Tool | Replaces | You type |
|---|---|---|
| [eza](https://github.com/eza-community/eza) | `ls` | `ls`, `ll`, `lt` (tree) |
| [bat](https://github.com/sharkdp/bat) | `cat` | `cat main.ts` — syntax highlighted |
| [fd](https://github.com/sharkdp/fd) | `find` | `fd -e ts`, `fd -t d` |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | `cd` | `z proj` jumps to the dir you use most |
| [fzf](https://github.com/junegunn/fzf) | history search | `ctrl+r`, `ctrl+t`, `alt+c` |
| [git-delta](https://github.com/dandavison/delta) | git's diff pager | automatic on `git diff` |
| [lazygit](https://github.com/jesseduffield/lazygit) | typing git commands | `lg` |
| [starship](https://starship.rs) | the omz theme | the prompt |

**`--tools extended`** adds ripgrep, tmux (with a themed config), jq, direnv,
tldr and btop. **`--tools all`** adds atuin, yq, httpie, dust, procs and gh.

Plus [Oh My Zsh](https://ohmyz.sh) with 17 plugins — ghost-text suggestions from
history, live valid/invalid command colouring, `ESC ESC` for sudo, `x` to extract
any archive, and more. Full list in the [cheatsheet](docs/CHEATSHEET.md).

### The commands

**Core** — always installed:

```
cheatsheet / chs   the reference card (--comp for everything)
agdoctor           health-check every part of the setup
theme [name]       list themes, or switch the whole look
agupdate           git pull and reapply
mkcd <dir>         create a directory and cd into it
up [n]             cd up n levels
serve [port]       static HTTP server here, prints the LAN URL
ports              what's listening, with PID and process name
killport <port>    kill whatever is holding a port
fkill              fzf-pick a process and kill it
fe [query]         fzf-pick a file with a preview, open in $EDITOR
bak <file>         timestamped backup copy
sizeof [dir]       what's eating the disk
gprune             delete branches already merged into main
paths              $PATH one per line, dupes and dead entries flagged
reload             restart the shell in place
```

**Extras** — need the network, skip with `--no-extras`:

```
weather [city]     forecast in the terminal
cheat <cmd>        practical examples for any command
qr <text>          QR code in the terminal
gitignore <langs>  fetch a .gitignore
note [text]        timestamped scratch notes, stored locally
timer <mins>       countdown, then a notification
sysinfo            machine summary
dockerclean        reclaim docker disk space
```

All 24 exist in PowerShell too. Full reference with examples:
[docs/COMMANDS.md](docs/COMMANDS.md).

---

## Platform support

| | Terminal | Shell | Scripts |
|---|---|---|---|
| **macOS** | Ghostty | zsh + Oh My Zsh | `install.sh` · `uninstall.sh` · `doctor.sh` |
| **Linux** | Ghostty | zsh + Oh My Zsh | `install.sh` · `uninstall.sh` · `doctor.sh` |
| **Windows (WSL2)** | Ghostty | zsh + Oh My Zsh | `install.sh` · `uninstall.sh` · `doctor.sh` |
| **Windows (native)** | Windows Terminal | PowerShell + PSReadLine | `install.ps1` · `uninstall.ps1` · `doctor.ps1` |

**Ghostty has no native Windows build** — it ships macOS and Linux only. On
Windows you get either the full experience through WSL2, or the same tool stack
and all 24 commands in PowerShell with Windows Terminal and a matching colour
scheme. Both routes: [docs/WINDOWS.md](docs/WINDOWS.md).

---

## Layout

```
install.sh  · uninstall.sh  · doctor.sh    macOS + Linux
install.ps1 · uninstall.ps1 · doctor.ps1   Windows
config/
  zsh/afterglow.zsh                        the shell config that gets sourced
  zsh/functions.zsh                        cheatsheet + the core commands
  zsh/extras.zsh                           the network-dependent commands
  themes/*.theme                           the four looks
  themes/lazygit/*.yml                     matching lazygit palettes
  ghostty/config                           theme, font, padding, title handling
  starship/starship.toml                   fallback prompt config
  tmux/tmux.conf                           themed tmux
  git/delta.gitconfig                      what install.sh sets, for reference
  powershell/                              the PowerShell profile
  windows-terminal/schemes.json            colour schemes
extras/claude-code/                        optional: desktop alerts + statusline
docs/                                      the guide, and the GitHub Pages site
```

Nothing here is machine-specific. No PATH exports, no secrets, no telemetry, no
hostnames — just the terminal. CI fails the build if any of that sneaks in.

---

## Make it yours

- **Different theme:** `theme <name>`, or edit `config/themes/` to add one.
- **Different prompt:** `starship preset --list` shows them all.
- **Different font:** any [Nerd Font](https://nerdfonts.com) works — the icons
  need one, the family doesn't matter.
- **Fewer plugins:** trim the `plugins=(...)` array in
  `config/zsh/afterglow.zsh`. Keep `zsh-syntax-highlighting` last.

Then `./install.sh` again, or `agupdate` to pull and reapply in one go.

---

## Credits

Standing on [Ghostty](https://ghostty.org) · [Starship](https://starship.rs) ·
[Oh My Zsh](https://ohmyz.sh) · [Catppuccin](https://catppuccin.com) ·
[Gruvbox](https://github.com/morhetz/gruvbox) ·
[Tokyo Night](https://github.com/folke/tokyonight.nvim) ·
[Nerd Fonts](https://nerdfonts.com) · and the authors of eza, bat, fd, zoxide,
fzf, delta and lazygit.

MIT licensed — see [LICENSE](LICENSE). Take it, fork it, make it yours.
