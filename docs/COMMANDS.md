# Commands

The helper commands furnizsh adds, beyond what the tools and plugins give you.
All of them exist in both zsh (`config/zsh/functions.zsh`) and PowerShell
(`config/powershell/Microsoft.PowerShell_profile.ps1`) with the same names and
the same behaviour.

| | |
|---|---|
| [`cheatsheet` / `chs`](#cheatsheet--chs) | the reference card |
| [`agdoctor`](#agdoctor) | health-check the setup |
| [`theme`](#theme-name) | switch the whole look |
| [`agupdate`](#agupdate) | update furnizsh |
| [`mkcd`](#mkcd-dir) | create a directory and enter it |
| [`up`](#up-n) | cd up N levels |
| [`serve`](#serve-port) | static HTTP server here |
| [`ports`](#ports) | what's listening |
| [`killport`](#killport-port) | free a port |
| [`fkill`](#fkill) | fzf-pick and kill a process |
| [`fe`](#fe-query) | fzf-pick and edit a file |
| [`bak`](#bak-file) | timestamped backup |
| [`sizeof`](#sizeof-dir) | what's eating the disk |
| [`gprune`](#gprune) | prune merged branches |
| [`paths`](#paths) | `$PATH`, readably |
| [`reload`](#reload) | restart the shell |

**Extras** — these need the network, and are skipped with `--no-extras`:

| | |
|---|---|
| [`weather`](#weather-location) | forecast in the terminal |
| [`cheat`](#cheat-command) | examples for any command |
| [`qr`](#qr-text) | QR code in the terminal |
| [`gitignore`](#gitignore-langs) | fetch a `.gitignore` |
| [`note`](#note-text) | timestamped scratch notes |
| [`timer`](#timer-minutes-label) | countdown + notification |
| [`sysinfo`](#sysinfo) | machine summary |
| [`dockerclean`](#dockerclean) | reclaim docker disk space |

---

## `cheatsheet` / `chs`

Prints a colourised reference card without leaving the terminal.

```bash
chs                # short daily-use summary
cheatsheet --comp  # everything: every plugin, every tool flag, every keybind
```

`--full`, `-a` and `--all` are accepted as aliases for `--comp`.

The written version of the full output is [CHEATSHEET.md](CHEATSHEET.md).

---

## `agdoctor`

Checks every part of the setup — tools on `$PATH`, the login shell, Oh My Zsh
and its plugins, every config file, git's pager, the Nerd Font — and prints a
✓/✗ line for each with the fix command for anything missing.

```bash
agdoctor
```

Also available before the shell config is installed, as `./doctor.sh` in the
repo. That version exits non-zero on failure, so it works in CI:

```bash
./doctor.sh --quiet && echo "setup intact"
```

`doctor` is aliased to `agdoctor` unless something else on your system already
owns that name.

---

## `theme [name]`

Switch the entire look in one command. Ghostty, Starship and lazygit all change
together, which is the point — set individually they drift apart within a week.

```bash
theme              # list them, with the active one marked
theme gruvbox      # switch
```

| Theme | Terminal | Prompt |
|---|---|---|
| `neon` | Ghostty `Neon` | catppuccin-powerline |
| `catppuccin` | `Catppuccin Mocha` | catppuccin-powerline |
| `gruvbox` | `Gruvbox Dark` | gruvbox-rainbow |
| `tokyonight` | `TokyoNight` | tokyo-night |

Ghostty reloads on save, so the terminal colours change immediately. The prompt
needs a `reload`.

Before writing anything it checks the theme actually exists on your Ghostty
build (`ghostty +list-themes`) — names occasionally get re-cased between
releases — and leaves the config alone rather than writing a broken value.

On Windows there's no Ghostty, so `theme` covers Starship and lazygit and points
you at the matching Windows Terminal scheme.

---

## `agupdate`

Update furnizsh to the latest release.

```bash
agupdate
```

The same thing is available as `furnizsh update`, which works in any shell —
`agupdate` is just the zsh-side name for it. Both run the same script.

```bash
furnizsh update            # update
furnizsh update --check    # only report whether one is available
```

It first checks the current release and stops early if you are already on it.
Otherwise it updates using whichever channel you installed from — `install.sh`
records that at install time, so this works the same whether you used the
bootstrap script, Homebrew, npm or a git checkout:

| Installed via | What `agupdate` runs |
|---|---|
| bootstrap script | re-runs the installer from the site |
| Homebrew | `brew update && brew upgrade furnizsh` |
| npm | `npm install -g furnizsh` |
| git checkout | `git pull --ff-only`, then `install.sh --yes` |

If it cannot tell (an install predating this, or a hand-copied config) it prints
the four commands and exits non-zero rather than guessing.

Run `reload` afterwards to pick up the new shell config.

## `mkcd <dir>`

Create a directory, including parents, and cd into it. The thing you actually
meant when you typed `mkdir -p foo/bar/baz && cd foo/bar/baz`.

```bash
mkcd projects/2026/experiment
```

---

## `up [n]`

Go up N directory levels. Default 1.

```bash
up      # cd ..
up 3    # cd ../../..
```

---

## `serve [port]`

Static HTTP server rooted at the current directory. Default port 8000. Prints
both the localhost URL and the LAN URL, so you can open it on your phone.

```bash
serve
serve 3000
```

Needs `python3` (`python` on Windows). Ctrl+C stops it.

---

## `ports`

Everything currently listening, with the port, PID and process name — so you can
answer "what's already on 3000?" without remembering the `lsof` incantation.

```bash
ports
```

Uses `lsof` where available, falls back to `ss` on Linux and
`Get-NetTCPConnection` on Windows.

---

## `killport <port>`

Kill whatever is holding a port. The other half of the "port 3000 is already in
use" problem.

```bash
killport 3000
```

Prints the process name it killed. If nothing is listening it says so and does
nothing. If the process belongs to another user you'll need sudo — it'll tell
you.

---

## `fkill`

Fuzzy-pick a process from an fzf list and kill it. Tab selects several.

```bash
fkill        # SIGTERM (15)
fkill 9      # SIGKILL
```

Prefer this to `killport` when you know the app's name but not its port.

---

## `fe [query]`

Fuzzy-pick a file with a syntax-highlighted preview pane and open it in
`$EDITOR`. Optionally seed the search.

```bash
fe              # browse everything under the current dir
fe component    # start filtered to "component"
```

Uses `fd` for the file list and `bat` for the preview when they're available,
falling back to `find` and `cat`. `.git` is excluded. Set `$EDITOR` first, or it
defaults to `vi` (`notepad` on Windows).

---

## `bak <file>`

Timestamped backup copy alongside the original. For when you're about to edit
something and want a five-second undo.

```bash
bak nginx.conf
# -> nginx.conf.20260811-143022.bak
```

Works on directories too (copies recursively, preserving attributes).

---

## `sizeof [dir]`

The 20 biggest items in a directory, human-readable, largest first. Directories
are totalled recursively. Default is the current directory.

```bash
sizeof
sizeof ~/Downloads
```

The fast answer to "why is my disk full".

---

## `gprune`

Delete local branches that are already merged into the default branch.

```bash
gprune
```

It works out the default branch from `origin/HEAD`, falling back to whichever of
`main`, `master` or `trunk` exists. `main`, `master`, `develop` and `trunk` are
never deleted. It lists what it found and **asks before deleting anything**, and
uses `git branch -d` (not `-D`), so git refuses anything not genuinely merged.

---

## `paths`

`$PATH`, one entry per line, with duplicates marked `dup` and non-existent
directories marked `missing`.

```bash
paths
```

Far more readable than `echo $PATH`, and it surfaces the dead entries that
accumulate as you install and remove tools.

---

## `reload`

Restart the shell in place, picking up config changes.

```bash
reload
```

Equivalent to `exec zsh -l`. Note this is a *restart*, not a `source` — your
shell variables and directory stack reset, which is usually what you want after
editing shell config, since re-sourcing can double-apply things like PATH
exports.

---

## Adding your own

Put them in `config/zsh/functions.zsh` and rerun `./install.sh` to copy them
into place. Two conventions worth following:

- Use the `$FURNIZSH_C` colour map rather than raw escape codes, so your output
  matches the rest.
- Guard external tools with `command -v` and print a usage line on bad input —
  every command here does, which is why a partial install degrades instead of
  spewing errors.

---

# Extras

These call an external service, which is why they're separable — install with
`--no-extras` to leave them out entirely. Nothing private is sent: the queries
are command names, city names and language names. `note` writes locally only.

## `weather [location]`

```bash
weather              # geolocates by IP
weather lahore
weather "new york"
```

## `cheat <command>`

Practical examples for any CLI tool — the thing you actually wanted instead of a
man page.

```bash
cheat tar
cheat git/rebase
cheat ffmpeg resize
```

`tldr` does the same thing offline if you installed `--tools extended`.

## `qr <text>`

Renders a QR code as terminal output. Handy for getting a `serve` URL onto your
phone.

```bash
serve 3000
qr http://192.168.1.5:3000
```

## `gitignore <langs>`

```bash
gitignore node,macos,vscode        # print it
gitignore -w node,macos,vscode     # write ./.gitignore (appends if it exists)
```

## `note [text]`

Timestamped scratch notes in a single local file.

```bash
note "the retry backoff is wrong in worker.ts"
note -l        # last 20 lines
note           # open in $EDITOR
```

Stored at `~/.furnizsh-notes.md`, or wherever `$FURNIZSH_NOTES` points.

## `timer <minutes> [label]`

Counts down in place, then fires a desktop notification and a beep.

```bash
timer 25 pomodoro
timer 5 tea
```

## `sysinfo`

OS, host, CPU, cores, memory, uptime, disk, shell, terminal and the active
theme.

```bash
sysinfo
```

## `dockerclean`

Shows current docker disk usage, explains exactly what will be removed, and asks
before doing it. **Named volumes are never touched** — your database data is
safe.

```bash
dockerclean
```
