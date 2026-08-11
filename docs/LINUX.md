# Linux

`./install.sh` handles Linux, but package names for these tools vary more
between distributions than for almost anything else. This page is the reference
for when the installer warns that something couldn't be found.

---

## The package-name problem

Three of these tools have naming trouble on Debian and Ubuntu:

| Tool | Debian/Ubuntu package | Binary installed as | Why |
|---|---|---|---|
| `fd` | `fd-find` | **`fdfind`** | `fd` was already taken by an unrelated package |
| `bat` | `bat` | **`batcat`** | same — `bat` collided with `bacula-console-qt` |
| `delta` | `git-delta` | `delta` | `delta` was taken by a different tool |

`config/zsh/afterglow.zsh` detects the renamed binaries and aliases both `bat`
and `cat` to `batcat`, and both `fd` and `find` to `fdfind` — so once installed,
everything works under the normal names regardless. `agdoctor` accepts either
name as a pass.

If you'd rather have the real names on `$PATH`:

```bash
mkdir -p ~/.local/bin
ln -s "$(command -v batcat)" ~/.local/bin/bat
ln -s "$(command -v fdfind)" ~/.local/bin/fd
```

---

## Per-distro

### Debian / Ubuntu

```bash
sudo apt update
sudo apt install -y zsh git curl unzip fzf zoxide bat fd-find git-delta
```

**eza** isn't in the Debian or Ubuntu archives (and its predecessor `exa` is
unmaintained — don't use it). Add the upstream repository:

```bash
sudo mkdir -p /etc/apt/keyrings
wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
  | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
  | sudo tee /etc/apt/sources.list.d/gierens.list
sudo apt update && sudo apt install -y eza
```

**lazygit** likewise isn't packaged. Grab the release binary:

```bash
LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" \
  | grep -Po '"tag_name": *"v\K[^"]*')
curl -Lo /tmp/lazygit.tar.gz \
  "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
tar xf /tmp/lazygit.tar.gz -C /tmp lazygit
sudo install /tmp/lazygit /usr/local/bin
```

**zoxide** in older Ubuntu repos is ancient. If `z` misbehaves, use the official
installer instead:

```bash
curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
```

**fzf** from apt is often below 0.48, which is when `fzf --zsh` was added.
afterglow falls back to `~/.fzf.zsh` automatically, but for the current version:

```bash
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf && ~/.fzf/install
```

### Fedora / RHEL

Everything is packaged and correctly named:

```bash
sudo dnf install -y zsh git curl unzip fzf zoxide bat fd-find git-delta eza lazygit
```

Note that Fedora's `fd-find` package *does* install the binary as `fd`, unlike
Debian's.

### Arch / Manjaro

Best-supported of the lot — everything including starship is in the official
repos:

```bash
sudo pacman -S --needed zsh git curl unzip fzf zoxide bat fd git-delta eza lazygit starship
```

Ghostty is in the AUR:

```bash
yay -S ghostty
```

### openSUSE

```bash
sudo zypper install zsh git curl unzip fzf zoxide bat fd git-delta lazygit
```

`eza` may need the `utilities` repository. `./install.sh` doesn't auto-detect
zypper — install the packages with the command above, then run
`./install.sh` and it'll skip straight to the config steps.

### Anything else

Starship and zoxide both have official one-line installers that work everywhere:

```bash
curl -sS https://starship.rs/install.sh | sh
curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
```

The rest publish static binaries on their GitHub releases pages.

---

## Ghostty

Ghostty doesn't ship official distro packages for everything — see
[ghostty.org/docs/install](https://ghostty.org/docs/install) for the current
state. As of writing: Arch via AUR, Nix via nixpkgs, community `.deb` builds for
Debian/Ubuntu, and building from source (Zig) everywhere else.

afterglow doesn't require Ghostty. The shell config, tools, prompt and commands
all work in any terminal — you just lose the specific Neon look. Alacritty,
Kitty, WezTerm and GNOME Terminal all work fine; set the font to
`JetBrainsMono Nerd Font Mono` and pick a dark theme.

---

## Fonts

No distro packages Nerd Fonts consistently. Install by hand:

```bash
mkdir -p ~/.local/share/fonts
cd ~/.local/share/fonts
curl -fLO https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
unzip -o JetBrainsMono.zip && rm JetBrainsMono.zip
fc-cache -fv
```

Verify:

```bash
fc-list | grep -i "jetbrainsmono nerd"
```

`./install.sh` does exactly this when it detects the font is missing.

---

## The login shell

Unlike macOS, most Linux distributions default to bash. The installer offers to
change it; by hand:

```bash
command -v zsh | sudo tee -a /etc/shells   # chsh only accepts listed shells
chsh -s "$(command -v zsh)"
```

Log out and back in — a new terminal tab isn't enough for a login-shell change
on most desktop environments.

---

## Truecolor

The Catppuccin palette needs 24-bit colour. Check:

```bash
printf "\033[38;2;250;179;135mIf this is orange, truecolor works\033[0m\n"
```

If it isn't, set `TERM=xterm-256color` and — if you're in tmux — add
`set -ga terminal-overrides ",*256col*:Tc"` to `~/.tmux.conf`. Some SSH sessions
and terminal multiplexers strip colour depth silently.

---

## Wayland vs X11

No difference to any of this. Ghostty supports both natively.
