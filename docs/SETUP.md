# Setup guide

The manual version of what `./install.sh` does. Follow this if you'd rather
understand and apply each piece yourself, if you're cherry-picking parts, or if
the installer failed somewhere and you want to finish by hand.

Everything here is idempotent — safe to redo.

**Contents**

1. [Prerequisites](#1-prerequisites)
2. [Install the packages](#2-install-the-packages)
3. [Oh My Zsh and its custom plugins](#3-oh-my-zsh-and-its-custom-plugins)
4. [Make zsh your login shell](#4-make-zsh-your-login-shell)
5. [The shell config](#5-the-shell-config)
6. [Starship](#6-starship)
7. [Ghostty](#7-ghostty)
8. [git + delta](#8-git--delta)
9. [lazygit](#9-lazygit)
10. [Claude Code extras (optional)](#10-claude-code-extras-optional)
11. [Verification](#verification)
12. [Troubleshooting](#troubleshooting)

---

## 1. Prerequisites

**macOS** — Homebrew:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

On Apple Silicon the installer will tell you to add brew to your PATH. Do that
before continuing.

**Linux** — you need `git`, `curl`, `unzip` and a working package manager
(apt, dnf or pacman). See [LINUX.md](LINUX.md) for the per-distro package names,
which differ more than you'd expect.

**Windows** — see [WINDOWS.md](WINDOWS.md). Ghostty has no Windows build, so
you either use WSL2 (and follow this guide inside it) or take the PowerShell
route.

---

## 2. Install the packages

**macOS:**

```bash
brew install starship zsh-autosuggestions zsh-syntax-highlighting \
             fzf zoxide eza bat fd git-delta lazygit

brew install --cask font-jetbrains-mono-nerd-font
brew install --cask ghostty
```

**Linux** — package names vary; see [LINUX.md](LINUX.md). The short version:

```bash
# Debian / Ubuntu — note fd and bat are renamed here
sudo apt install zsh git curl fzf zoxide bat fd-find git-delta

# Fedora
sudo dnf install zsh git curl fzf zoxide bat fd-find git-delta eza lazygit

# Arch
sudo pacman -S zsh git curl fzf zoxide bat fd git-delta eza lazygit starship
```

The font matters. Without a Nerd Font, every icon in the prompt and in `eza`
output renders as an empty box. Download JetBrains Mono from
[nerdfonts.com](https://www.nerdfonts.com/font-downloads), unzip into
`~/.local/share/fonts`, then `fc-cache -f`.

---

## 3. Oh My Zsh and its custom plugins

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

> If you already have a `~/.zshrc` you care about, run it as
> `KEEP_ZSHRC=yes sh -c "$(curl -fsSL ...)"` — otherwise the installer moves your
> file aside and writes its own.

Then clone the two plugins:

```bash
git clone https://github.com/zsh-users/zsh-autosuggestions \
  ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

git clone https://github.com/zsh-users/zsh-syntax-highlighting \
  ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
```

**Why clone them when Homebrew already has them?** Because Oh My Zsh's
`plugins=(...)` array only looks inside `$ZSH_CUSTOM/plugins`. The Homebrew
formulae install the scripts somewhere else entirely and expect you to `source`
them by absolute path. Cloning is what makes the plugin array work, and it keeps
them updating independently of brew.

---

## 4. Make zsh your login shell

Skipped by most guides, which assume macOS Catalina or later where zsh is
already the default. Check first:

```bash
echo $SHELL
```

If that isn't `/bin/zsh` or similar:

```bash
# The shell must be listed in /etc/shells before chsh will accept it
command -v zsh | sudo tee -a /etc/shells
chsh -s "$(command -v zsh)"
```

Log out and back in, or just open a new terminal.

---

## 5. The shell config

Copy this repo's shell config into place:

```bash
mkdir -p ~/.config/afterglow
cp config/zsh/afterglow.zsh config/zsh/functions.zsh ~/.config/afterglow/
```

Then add **one line** to the bottom of `~/.zshrc`:

```bash
[ -f "$HOME/.config/afterglow/afterglow.zsh" ] && source "$HOME/.config/afterglow/afterglow.zsh"
```

That's the whole wiring. Keeping it in a separate file rather than pasting a
few hundred lines into `~/.zshrc` means you can update it with `git pull` and
your own config never gets tangled up in it.

### What's in there

`afterglow.zsh` sets up, in order:

**Oh My Zsh** with `ZSH_THEME=""`. The theme must be empty — Starship renders
the prompt, and if an omz theme is also set the two fight over `$PROMPT` and you
get a mangled result.

**The plugin array.** Two rules:

- `zsh-syntax-highlighting` **must be last**. It wraps the ZLE widgets defined
  by everything above it; anything loaded afterwards won't be highlighted.
- **No `z` plugin.** zoxide provides `z` too, with frecency ranking. Enabling
  both means whichever loads last wins, unpredictably.

**Aliases** for the modern tools, each guarded by a `command -v` check so a
partial install doesn't leave you with a broken `ls`. On Debian/Ubuntu the
binaries are `fdfind` and `batcat` — the config detects that and aliases around
it.

**zoxide and fzf** initialization.

**A `precmd` hook** that sets the terminal title to the current directory:

```bash
autoload -Uz add-zsh-hook
_afterglow_set_title() { print -Pn '\e]2;%~\a' }
add-zsh-hook precmd _afterglow_set_title
```

This pairs with turning off Ghostty's own title feature in step 7. Ghostty's
default shows the *running command*; this shows the *folder*, in both tabs and
windows, which is far more useful when you have eight tabs open.

**history-substring-search keybindings** so Up/Down filter your history by
whatever you've already typed rather than walking it blindly.

**The helper commands**, sourced from `functions.zsh` — see
[COMMANDS.md](COMMANDS.md).

**`starship init zsh`, last.** It must be the final thing that touches the
prompt. If you later add prompt-related config to `~/.zshrc`, put it *above* the
afterglow block.

---

## 6. Starship

```bash
starship preset catppuccin-powerline --force -o ~/.config/starship.toml
```

**`--force` matters.** `starship preset -o` refuses to overwrite an existing
config and exits non-zero. Without it, every attempt after the first silently
leaves your prompt unchanged.

That's the whole config — the preset is complete, no hand-editing needed. This
repo's `config/starship/starship.toml` is that preset verbatim, so you can copy
it instead if you'd rather not depend on the preset name staying stable.

Or let afterglow do it: `theme gruvbox` sets the Ghostty theme, the Starship
preset and the lazygit palette together, so they can't drift apart. `theme` with
no argument lists what's available.

Want something else entirely? `starship preset --list` shows all of them. If you switch
the Ghostty theme too, `Gruvbox Dark` + `gruvbox-rainbow` is another pre-matched
pair. Per-module tweaks: <https://starship.rs/config/>.

---

## 7. Ghostty

Copy `config/ghostty/config` to `~/.config/ghostty/config`, or write it by hand:

```
theme = Neon

font-family = JetBrainsMono Nerd Font Mono
font-size = 14

window-padding-x = 10
window-padding-y = 10

cursor-style = block
cursor-style-blink = true

shell-integration-features = no-title,cursor,no-sudo,no-ssh-env,no-ssh-terminfo,path
```

Ghostty reloads on save, and `cmd+,` opens this file.

**On the theme name:** run `ghostty +list-themes` to confirm `Neon` is still
exact on your version — theme names occasionally get re-cased between releases.
Other bundled options in the same register: `Synthwave`, `Cyberpunk`, `Retro`
(pure green phosphor), `Retro Legends`. If you'd rather the terminal match the
prompt exactly, use `catppuccin-mocha`.

**On `shell-integration-features`:** the `no-title` is the important part — it
disables Ghostty's own title handling in favour of the zsh hook from step 5. The
rest of that list is Ghostty's defaults, spelled out.

### Optional: shader effects

Not used by this setup, documented because people ask.

```bash
mkdir -p ~/.config/ghostty/shaders
curl -fsSL "https://raw.githubusercontent.com/0xhckr/ghostty-shaders/main/bloom.glsl" \
  -o ~/.config/ghostty/shaders/bloom.glsl
```

Then add `custom-shader = ~/.config/ghostty/shaders/bloom.glsl` to the config.

Both a bloom shader and a full CRT scanline/warp shader were tried on this setup
and reverted. Bloom blurs text — that's not a tuning problem, it's what bloom
*does*: it blends neighbouring bright pixels into each other, and text is made
of bright pixels on a dark background. The CRT shader looked great and cost
enough GPU to make scrolling visibly stutter. Worth trying once; you probably
won't keep it.

---

## 8. git + delta

```bash
git config --global core.pager "delta"
git config --global interactive.diffFilter "delta --color-only"
git config --global delta.navigate "true"
```

Using `git config` rather than editing `~/.gitconfig` by hand means nothing else
in that file gets disturbed. `navigate = true` gives you `n` / `N` to jump
between files inside the pager; `q` quits.

Optional extras, if you want them — see `config/git/delta.gitconfig`:

```bash
git config --global delta.side-by-side true
git config --global delta.line-numbers true
git config --global merge.conflictstyle zdiff3
```

---

## 9. lazygit

Config path is version- and OS-dependent. Ask lazygit itself:

```bash
lazygit --print-config-dir
```

Typically `~/Library/Application Support/lazygit` on macOS and
`~/.config/lazygit` on Linux. Copy `config/lazygit/config.yml` there as
`config.yml`. It sets `nerdFontsVersion: "3"`, icons on, and the Catppuccin
Mocha palette so lazygit matches the prompt.

If a future lazygit release renames any theme keys, `lazygit --config` dumps the
full current schema.

---

## 10. Claude Code extras (optional)

Only relevant if you use [Claude Code](https://claude.com/claude-code). See
[../extras/claude-code/README.md](../extras/claude-code/README.md) — desktop
notifications when a task finishes or needs your permission, and a statusline
showing model, context use and cost.

Entirely optional and entirely separate from the terminal setup.

---

## Verification

Run `./doctor.sh` (or `agdoctor` once the shell config is loaded) — it checks
every item below automatically and tells you the fix command for anything
missing.

Or by hand:

- [ ] A new Ghostty window shows the Neon theme with sharp text — no blur, no
      scanlines, no typing or scroll lag
- [ ] The Starship prompt renders icons, not empty boxes (this is the Nerd Font check)
- [ ] The tab/window title shows the current folder, and updates when you `cd`
- [ ] Typing a partial command shows grey ghost-text from history
- [ ] A valid vs. an invalid command name are coloured differently as you type
- [ ] `ctrl+r` opens the fzf history search
- [ ] After visiting a few directories, `z <partial-name>` jumps to one
- [ ] `ls`, `cat <file>` and `find` produce eza / bat / fd output
- [ ] `git diff` in any repo shows delta's colourised diff
- [ ] `lg` opens lazygit, themed, with icons rendering
- [ ] `cheatsheet` prints the short reference, `cheatsheet --comp` the full one
- [ ] `agdoctor` comes back all-green

---

## Troubleshooting

**Icons show as boxes (□ or ▯).** The Nerd Font isn't active. Check it's
installed (`ls ~/Library/Fonts | grep -i jetbrains` on macOS, `fc-list | grep -i
"jetbrains.*nerd"` on Linux) and that your terminal's font is set to
`JetBrainsMono Nerd Font Mono` exactly — the plain `JetBrains Mono` is a
different, icon-free font.

**The prompt looks broken or doubled.** An Oh My Zsh theme is still set. Confirm
`ZSH_THEME=""` and that `starship init zsh` runs after `source $ZSH/oh-my-zsh.sh`.

**Syntax highlighting doesn't work.** `zsh-syntax-highlighting` isn't last in the
plugin array, or something after it redefines a ZLE widget.

**`z` doesn't jump.** Either the omz `z` plugin is enabled and conflicting with
zoxide, or zoxide hasn't learned any directories yet — it needs you to `cd`
around a bit first.

**`command not found: eza` (or bat/fd) on Debian/Ubuntu.** The binaries are
`batcat` and `fdfind` there, and eza often isn't packaged at all. See
[LINUX.md](LINUX.md).

**Colours look washed out or wrong.** Your terminal isn't in truecolor mode.
`./doctor.sh` prints three pastel blocks — if they look identical or muddy,
check `echo $TERM` (should be `xterm-256color` or `xterm-ghostty`) and that
you're not inside a tmux session that's stripping colour.

**Something's broken and I want out.** `./uninstall.sh` — and
`./uninstall.sh --restore` to also put your previous configs back from
`~/.afterglow-backup/`.
