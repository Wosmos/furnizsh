# Cheatsheet

The written version of `cheatsheet --comp`. Run `chs` in your terminal for the
same thing, colourised, without leaving the shell.

---

## Themes

Four complete looks. `theme <name>` switches Ghostty, Starship and lazygit
together; `--theme <name>` picks the starting one at install time.

| Theme | Terminal | Prompt |
|---|---|---|
| `neon` *(default)* | Ghostty `Neon` | catppuccin-powerline |
| `catppuccin` | `Catppuccin Mocha` | catppuccin-powerline |
| `gruvbox` | `Gruvbox Dark` | gruvbox-rainbow |
| `tokyonight` | `TokyoNight` | tokyo-night |

The default:

- **Ghostty:** `Neon` — near-black background, glowing cyan/magenta/green
  accents. Plain default rendering, no shader. Both a bloom and a CRT shader were
  tried and reverted (blurry text, GPU lag) — see
  [SETUP.md](SETUP.md#optional-shader-effects).
- **Prompt:** Starship, `catppuccin-powerline` preset (`~/.config/starship.toml`).
  Deliberately a different palette from the Neon terminal theme — if you want them
  to match exactly, set Ghostty's theme to `catppuccin-mocha`.
- **Font:** JetBrainsMono Nerd Font Mono. Required for icons to render.
- **Tab/window title:** the current directory, set by a zsh `precmd` hook rather
  than Ghostty's default (which shows the running command).

---

## Oh My Zsh plugins

| Plugin | What it gives you |
|---|---|
| `git` | `gst` status, `ga` add, `gc` commit, `gco` checkout, `gcb` checkout -b, `gp` push, `gl` pull, `gd` diff, `glog` graph log — dozens more, see `alias \| grep '^g'` |
| `sudo` | press `ESC` `ESC` to prepend `sudo` to the current or last command |
| `history` | `h` = history, `hs <term>` = search history |
| `history-substring-search` | type part of a command, then Up/Down filters history to matches |
| `command-not-found` | suggests the package to install when a command isn't found |
| `colored-man-pages` | colourises man pages |
| `extract` | `x file.{zip,tar.gz,rar,7z,...}` extracts any archive format |
| `web-search` | `google <query>`, `ddg`, `stackoverflow`, `github` — opens a search in your browser |
| `copypath` | copies the current directory path to the clipboard |
| `copyfile` | `copyfile <file>` copies the file's contents to the clipboard |
| `copybuffer` | `ctrl+o` copies the current command line to the clipboard |
| `dirhistory` | `alt+←`/`→` back/forward through visited dirs, `alt+↑`/`↓` parent/child |
| `jsontools` | `pp_json`, `is_json`, `urlencode_json`, `urldecode_json` |
| `npm` / `node` | completion, aliases, `node-docs <topic>` |
| `macos` *(macOS)* | `ofd` open Finder here, `cdf` cd to Finder's front window, `showfiles`/`hidefiles` |
| `brew` *(macOS)* | Homebrew completion and aliases |
| `zsh-autosuggestions` | ghost-text suggestion from history as you type — `→` or `End` accepts it all, `alt+F` / `ctrl+→` accepts one word |
| `zsh-syntax-highlighting` | colours commands green/red as valid/invalid while typing — **must be last in the plugin array** |

---

## Tools

| Tool | Replaces | Usage |
|---|---|---|
| **Starship** | the Oh My Zsh theme | prompt engine; config at `~/.config/starship.toml` |
| **zoxide** | `cd`, omz `z` | `z <partial-dir>` jumps to a frecency-ranked match · `zi` interactive picker · `zoxide query` / `zoxide remove <path>` manage the database |
| **fzf** | plain history search | `ctrl+r` fuzzy history · `ctrl+t` fuzzy file search (inserts the path) · `alt+c` fuzzy cd |
| **eza** | `ls` | `ls` · `ll` long+all · `lt` tree · raw: `eza --icons=auto --long --header --git` |
| **bat** | `cat` | `cat <file>` syntax highlighted with line numbers · `bat -A` show whitespace · `bat --diff` · `bat --list-themes` |
| **fd** | `find` | `find` · `fd -e ts` by extension · `fd -H` include hidden · `fd -t d` directories only |
| **git-delta** | git's diff pager | automatic on `git diff` / `show` / `log -p` · `n`/`N` jump between files in the pager · `q` quits |
| **lazygit** | typing raw git commands | `lg` opens the TUI · `space` stage/unstage · `c` commit · `P` push · `p` pull · arrows switch panels · `enter` drills in · `?` shows every keybind in-app · `q`/`esc` back out |

---

## afterglow commands

| Command | What it does |
|---|---|
| `cheatsheet` / `chs` | this reference (`--comp` for the full version) |
| `agdoctor` | health-check every part of the setup |
| `theme [name]` | list themes, or switch Ghostty + Starship + lazygit together |
| `agupdate` | git pull the repo and reapply the setup |
| `mkcd <dir>` | create a directory and cd into it |
| `up [n]` | cd up n levels |
| `serve [port]` | static HTTP server here, prints the LAN URL |
| `ports` | everything listening, with PID and process name |
| `killport <port>` | kill whatever is holding a port |
| `fkill` | fzf-pick a process and kill it |
| `fe [query]` | fzf-pick a file with a preview, open in `$EDITOR` |
| `bak <file>` | timestamped backup copy |
| `sizeof [dir]` | biggest items in a directory |
| `gprune` | delete branches already merged into the default branch |
| `paths` | `$PATH` one per line, dupes and dead entries flagged |
| `reload` | restart the shell in place |

**Extras** — need the network, omitted with `--no-extras`:

| Command | What it does |
|---|---|
| `weather [city]` | forecast in the terminal |
| `cheat <cmd>` | practical examples for any command |
| `qr <text>` | QR code in the terminal |
| `gitignore <langs>` | fetch a `.gitignore` |
| `note [text]` | timestamped scratch notes, stored locally |
| `timer <mins>` | countdown, then a notification |
| `sysinfo` | machine summary |
| `dockerclean` | reclaim docker disk space |

Full reference with examples: [COMMANDS.md](COMMANDS.md).

---

## Ghostty keybinds

All defaults — nothing is remapped by this setup.

| Category | Shortcuts |
|---|---|
| **Window / Tab** | `cmd+n` new window · `cmd+t` new tab · `cmd+w` close tab · `cmd+shift+w` close window · `cmd+alt+shift+w` close all windows · `cmd+shift+]`/`[` next/prev tab · `ctrl+tab`/`ctrl+shift+tab` next/prev tab · `cmd+1`..`8` jump to tab N · `cmd+9` last tab |
| **Splits** | `cmd+d` split right · `cmd+shift+d` split down · `cmd+]`/`[` next/prev split · `cmd+alt+arrows` move focus · `cmd+ctrl+arrows` resize · `cmd+ctrl+=` equalize · `cmd+shift+enter` zoom split |
| **Search** | `cmd+f` start search · `cmd+shift+f` or `esc` end · `cmd+g`/`cmd+shift+g` next/prev result · `cmd+e` search selection · `cmd+a` select all |
| **Font / display** | `cmd+=`/`cmd+-` font size · `cmd+0` reset · `cmd+enter` fullscreen |
| **Scroll / prompt nav** | `cmd+home`/`end` top/bottom · `cmd+pgup`/`pgdn` page · `cmd+↑`/`↓` jump to previous/next shell prompt |
| **Misc** | `cmd+,` open config · `cmd+k` clear screen · `cmd+v` paste · `cmd+q` quit |
| **Line editing** | `cmd+←`/`→` line start/end · `cmd+backspace` delete to line start · `alt+←`/`→` jump one word |

On Linux, substitute `ctrl+shift` for `cmd` in most of these — see
[Ghostty's keybind docs](https://ghostty.org/docs/config/keybind).

---

## Claude Code notifications

Optional extra, only if you use Claude Code. `cc-alert.sh` fires a desktop alert
on task completion and on permission/waiting prompts, muted while you're already
looking at the terminal hosting the session.

Full environment-variable reference: `head -40 ~/.claude/hooks/cc-alert.sh`, or
[extras/claude-code/README.md](../extras/claude-code/README.md).

---

## Files this setup touches

| Path | What |
|---|---|
| `~/.zshrc` | **appended to** — one guarded `source` block, nothing else changed |
| `~/.config/afterglow/afterglow.zsh` | created — the shell config |
| `~/.config/afterglow/functions.zsh` | created — the helper commands |
| `~/.config/starship.toml` | created — Catppuccin Powerline preset |
| `~/.config/ghostty/config` | created — theme, font, title handling |
| `~/Library/Application Support/lazygit/config.yml` | created — Catppuccin Mocha theme (`~/.config/lazygit/` on Linux) |
| global git config | `core.pager`, `interactive.diffFilter`, `delta.navigate` set via `git config` |
| `~/.oh-my-zsh/custom/plugins/` | two plugins cloned in |
| `~/.afterglow-backup/<timestamp>/` | created — copies of anything that was replaced |

`./uninstall.sh` reverses all of it.
