# Windows

## The honest constraint first

**Ghostty has no Windows build.** It ships for macOS and Linux only, and the
project has said Windows support isn't on the near-term roadmap. Any guide
telling you to `winget install ghostty` is wrong.

So there are two routes, and they're genuinely different products:

| | Route A — WSL2 | Route B — native PowerShell |
|---|---|---|
| Terminal | **Ghostty**, the real thing | Windows Terminal |
| Shell | zsh + Oh My Zsh | PowerShell 7 + PSReadLine |
| Tools | all of them | all of them |
| Helper commands | all 24 | all 24 |
| Installer | `./install.sh` | `.\install.ps1` |
| Feels like | identical to macOS/Linux | very close, not identical |
| Catch | your work lives in the Linux filesystem | no Ghostty, no Oh My Zsh plugins |

**Route A if** you do Linux-flavoured development anyway (Docker, Node, Python,
anything with a Makefile). It's the full setup with nothing missing.

**Route B if** you work in the Windows filesystem with Windows tooling — .NET,
Visual Studio, PowerShell scripting. Route A's file-crossing penalty would hurt
more than the missing Ghostty.

You can run both. They don't conflict.

---

## Route A — WSL2 (recommended)

### 1. Install WSL2

In an **admin** PowerShell:

```powershell
wsl --install
```

That enables the feature, installs Ubuntu and sets WSL2 as the default. Reboot,
then set a UNIX username and password when Ubuntu first launches.

Already have WSL? Make sure it's version 2:

```powershell
wsl --list --verbose
wsl --set-version Ubuntu 2
```

### 2. Install Ghostty inside WSL

Ghostty is a Linux GUI app here, running through WSLg (the GUI support built
into WSL2 on Windows 11 and recent Windows 10 builds). Follow
[ghostty.org/docs/install](https://ghostty.org/docs/install) for your
distribution — on Ubuntu that's the community `.deb` or building from source.

Verify WSLg works first:

```bash
sudo apt install -y x11-apps && xeyes
```

If a pair of googly eyes appears on your Windows desktop, GUI apps work.

### 3. Install afterglow

Inside WSL:

```bash
git clone https://github.com/Wosmos/afterglow.git
cd afterglow
./install.sh
```

Then see [LINUX.md](LINUX.md) — Ubuntu renames `fd` to `fdfind` and `bat` to
`batcat`, and doesn't package `eza` at all on older releases.

### 4. Fonts

WSLg uses the Windows font stack, so install the Nerd Font on the **Windows**
side (see Route B step 3 below) and Ghostty inside WSL will find it.

### Keep your files in the Linux filesystem

Work in `~/projects`, not `/mnt/c/Users/you/projects`. Crossing the filesystem
boundary is slow — often 10× or worse on file-heavy operations like `npm
install` or `git status` in a big repo. Access your Linux files from Windows via
`\\wsl$\Ubuntu\home\you\` in Explorer when you need to.

---

## Route B — native PowerShell

### 1. PowerShell 7

The Windows-bundled "Windows PowerShell 5.1" works, but 7 is what you want.

```powershell
winget install Microsoft.PowerShell
```

### 2. Windows Terminal

Ships with Windows 11. On Windows 10:

```powershell
winget install Microsoft.WindowsTerminal
```

### 3. Run the installer

```powershell
git clone https://github.com/Wosmos/afterglow.git
cd afterglow
.\install.ps1 -DryRun    # see what it would do
.\install.ps1
```

Same options as the Unix installer, in PowerShell form:

```powershell
.\install.ps1 -Theme gruvbox -Tools extended
.\install.ps1 -Tools all -Yes
.\install.ps1 -Theme catppuccin -NoExtras
```

`-Theme` takes `neon` (default), `catppuccin`, `gruvbox` or `tokyonight`.
`-Tools` takes `core` (default), `extended` or `all`.

**The extended set is smaller on Windows.** `tmux` and `direnv` have no
meaningful native equivalent, so `-Tools extended` installs ripgrep, jq, tldr
and btop; `all` adds atuin, yq, httpie, dust, procs and gh. Use WSL2 if you
want tmux.

If the script is blocked, PowerShell's execution policy is stopping it. Allow
signed-and-local scripts for your user:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

Or run it once without changing the policy:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

The installer:

- installs starship, zoxide, fzf, eza, bat, fd, delta, lazygit and git via
  winget (or scoop/choco if that's what you have)
- installs the PSReadLine, Terminal-Icons and PSFzf modules
- installs JetBrains Mono Nerd Font into your per-user font directory — no
  admin rights needed
- writes the PowerShell profile with all the aliases and helper commands
- adds the colour schemes to Windows Terminal's `settings.json`
- backs up anything it replaces to `~\.afterglow-backup\<timestamp>\`

### 4. Point Windows Terminal at the theme

`ctrl+,` → your PowerShell profile → Appearance:

- **Color scheme:** `Catppuccin Mocha` (matches the prompt exactly) or
  `Afterglow Neon` (closer to the Ghostty look)
- **Font face:** `JetBrainsMono Nerd Font Mono`

### 5. Verify

```powershell
.\doctor.ps1     # standalone — works before the profile is loaded
agdoctor         # same checks, from any session once installed
cheatsheet       # the reference card
```

`doctor.ps1` exits non-zero on failure, so it works in CI:

```powershell
.\doctor.ps1 -Quiet; if ($LASTEXITCODE -eq 0) { "setup intact" }
```

### Uninstalling

```powershell
.\uninstall.ps1 -DryRun     # see what it would do
.\uninstall.ps1             # remove the profile, unset the git pager
.\uninstall.ps1 -Restore    # also restore your previous config from backup
```

Extra switches: `-Schemes` also strips the colour schemes from Windows
Terminal, `-Tools` also uninstalls the CLI tools and the Terminal-Icons /
PSFzf modules (it asks first, and never touches PSReadLine — Windows ships
and depends on it).

The three Windows scripts mirror the Unix ones exactly:

| Windows | macOS / Linux | Does |
|---|---|---|
| `install.ps1` | `install.sh` | install everything, backing up what it replaces |
| `uninstall.ps1` | `uninstall.sh` | remove it, optionally restoring from backup |
| `doctor.ps1` | `doctor.sh` | health-check every part of the setup |

---

## What's different in PowerShell

**PSReadLine replaces two zsh plugins.** `-PredictionSource History` gives you
the ghost-text that `zsh-autosuggestions` provides, and `Set-PSReadLineOption
-Colors` gives you the live syntax colouring that `zsh-syntax-highlighting`
does. Both are configured in the profile. `F2` toggles between inline and list
prediction views.

**No Oh My Zsh.** There's no equivalent, so the plugin-provided niceties are
gone: no `ESC ESC` for sudo, no `x` extract command, no `copypath`, no
`dirhistory`. The `git` plugin's aliases are the biggest loss — if you want
them, [posh-git](https://github.com/dahlbyk/posh-git) covers some ground.

**All 24 afterglow commands work**, ported to PowerShell — `cheatsheet`,
`agdoctor`, `theme`, `agupdate`, `mkcd`, `up`, `serve`, `ports`, `killport`,
`fkill`, `fe`, `bak`, `sizeof`, `gprune`, `paths`, `reload`, plus the eight
extras (`weather`, `cheat`, `qr`, `gitignore`, `note`, `timer`, `sysinfo`,
`dockerclean`).

Two spelling differences: `cheatsheet -Full` instead of `--comp`, and
`gitignore -Write` instead of `-w`.

**`theme` covers less on Windows.** With no Ghostty, it switches Starship and
lazygit and tells you which Windows Terminal scheme to pick in `ctrl+,` —
Windows Terminal has no supported way to change a profile's scheme from a
running shell.

**Aliases beat functions in PowerShell's resolution order**, which is why the
profile explicitly removes the built-in `ls` and `cat` aliases before defining
its own functions with those names. If you see the built-in behaviour coming
back, something re-imported those aliases after the profile ran.

**Starship works identically.** Same `starship.toml`, same preset, same look.

---

## Troubleshooting

**Icons are boxes.** The Nerd Font isn't set in Windows Terminal, or the font
name is wrong. It must be `JetBrainsMono Nerd Font Mono` — plain `JetBrains
Mono` is a different, icon-free font. Restart Windows Terminal fully after
installing a font; it caches the list.

**`agdoctor` says PSReadLine is too old.** Windows ships an old bundled version
that can't self-update while loaded. From an elevated PowerShell:

```powershell
Install-Module PSReadLine -Force -SkipPublisherCheck -AllowPrerelease
```

Then restart the terminal.

**The profile doesn't load.** `$PROFILE` differs between PowerShell 5.1 and 7 —
`echo $PROFILE` tells you which file the shell you're in actually reads. The
installer writes to whichever one it was run from, so run it from PowerShell 7.

**winget can't find a package.** IDs change. Search with
`winget search <name>`, or install [scoop](https://scoop.sh) — the installer
prefers it when present and its package names are more stable:

```powershell
irm get.scoop.sh | iex
```

**Colours look flat.** Windows Terminal supports truecolor, but the legacy
`conhost` console host doesn't. Make sure you're launching PowerShell *inside*
Windows Terminal, not the standalone console window.
