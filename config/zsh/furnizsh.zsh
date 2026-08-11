# ============================================================
#  furnizsh — terminal setup
#  https://github.com/Wosmos/furnizsh
#
#  Sourced from ~/.zshrc by install.sh. Everything here is the
#  terminal environment only: no PATH exports, no secrets, no
#  machine-specific anything. Your own config stays in ~/.zshrc.
#
#  Every block is guarded — if a tool isn't installed yet, that
#  block is skipped silently instead of erroring on every prompt.
# ============================================================

FURNIZSH_DIR="${${(%):-%x}:A:h}"

# ------------------------------------------------------------
# Oh My Zsh
# ------------------------------------------------------------
export ZSH="${ZSH:-$HOME/.oh-my-zsh}"

if [[ -d "$ZSH" ]]; then
  # Theme is disabled — Starship (initialized at the bottom of this
  # file) renders the prompt instead. Leaving an omz theme set here
  # makes the two fight over $PROMPT.
  ZSH_THEME=""

  # Show timestamps in `history` output
  HIST_STAMPS="yyyy-mm-dd"

  # Case-insensitive tab completion
  CASE_SENSITIVE="false"
  HYPHEN_INSENSITIVE="true"

  # Auto-update oh-my-zsh every 13 days, prompt first
  zstyle ':omz:update' mode reminder
  zstyle ':omz:update' frequency 13

  # ----------------------------------------------------------
  # Plugins
  # NOTE: zsh-syntax-highlighting MUST be last — it wraps the ZLE
  # widgets defined by everything above it.
  #
  # There is deliberately no `z` plugin here: zoxide (below) does
  # the same job with frecency ranking and updates independently
  # of oh-my-zsh. Enabling both makes them fight over `z`.
  # ----------------------------------------------------------
  plugins=(
    git                        # tons of git aliases (gst, gco, gp, gl, ...)
    sudo                       # ESC ESC prepends "sudo" to current or last command
    history                    # `h` = history, `hs <term>` = search history
    history-substring-search   # type part of a command, Up/Down filters matches
    command-not-found          # suggests the package when a command isn't found
    colored-man-pages          # colorizes man pages
    extract                    # `x file.{zip,tar.gz,rar,7z,...}` extracts anything
    web-search                 # `google <query>`, `ddg <query>`, `github <query>`
    copypath                   # copies current dir path to clipboard
    copyfile                   # `copyfile <file>` copies file contents to clipboard
    copybuffer                 # ctrl-o copies the current command line to clipboard
    dirhistory                 # alt+left/right dir history, alt+up/down parent/child
    jsontools                  # pp_json, is_json, urlencode_json, urldecode_json
    npm                        # npm completion + aliases
    node                       # `node-docs <topic>` opens Node.js docs
    zsh-autosuggestions        # ghost-text from history; accept with -> or End
    zsh-syntax-highlighting    # real-time syntax highlighting — MUST BE LAST
  )

  # Platform-specific plugins, appended before oh-my-zsh loads.
  # `macos` and `brew` don't exist on Linux and error out if listed there.
  if [[ "$OSTYPE" == darwin* ]]; then
    plugins+=(macos)
    command -v brew >/dev/null 2>&1 && plugins+=(brew)
  fi

  source "$ZSH/oh-my-zsh.sh"
fi

# ------------------------------------------------------------
# Modern CLI tool replacements
#
# Each alias is guarded so a partial install doesn't leave you with
# a broken `ls`. On Debian/Ubuntu the binaries are named `fdfind`
# and `batcat` (name collisions with unrelated packages) — handled.
# ------------------------------------------------------------
if command -v eza >/dev/null 2>&1; then
  # `--icons=auto`, not a bare `--icons`. Since eza 0.18 the flag takes an
  # optional WHEN value, so a bare `--icons` swallows the next argument:
  # `ls somedir` becomes `eza --icons somedir` and errors with
  # "invalid value 'somedir' for '--icons [<WHEN>]'". Pinning the value
  # with = keeps paths working.
  alias ls='eza --icons=auto'
  alias ll='eza -la --icons=auto'
  alias lt='eza --icons=auto --tree'
fi

if command -v bat >/dev/null 2>&1; then
  alias cat='bat'
elif command -v batcat >/dev/null 2>&1; then
  alias cat='batcat'
  alias bat='batcat'
fi

if command -v fd >/dev/null 2>&1; then
  alias find='fd'
elif command -v fdfind >/dev/null 2>&1; then
  alias find='fdfind'
  alias fd='fdfind'
fi

command -v lazygit >/dev/null 2>&1 && alias lg='lazygit'

# ------------------------------------------------------------
# zoxide — frecency-based `cd`. Use `z <partial-dir-name>`.
# ------------------------------------------------------------
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"

# ------------------------------------------------------------
# fzf — ctrl+r history, ctrl+t files, alt+c cd into a picked dir
#
# `fzf --zsh` needs fzf >= 0.48. Older builds ship shell snippets
# on disk instead, so fall back to those.
# ------------------------------------------------------------
if command -v fzf >/dev/null 2>&1; then
  if fzf --zsh >/dev/null 2>&1; then
    source <(fzf --zsh)
  else
    [[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh
  fi
fi

# ------------------------------------------------------------
# Terminal title = current directory, in both tabs and windows.
#
# Ghostty's own shell-integration title feature shows the running
# command name rather than the folder, so it's turned off in
# config/ghostty/config in favour of this hook.
# ------------------------------------------------------------
autoload -Uz add-zsh-hook
_furnizsh_set_title() {
  print -Pn '\e]2;%~\a'
}
add-zsh-hook precmd _furnizsh_set_title

# ------------------------------------------------------------
# history-substring-search keybindings
#
# Bound after oh-my-zsh loads so the widgets exist. The $terminfo
# codes cover terminals that send application-mode arrow keys;
# the raw escapes cover the rest.
# ------------------------------------------------------------
if (( $+widgets[history-substring-search-up] )); then
  bindkey '^[[A' history-substring-search-up
  bindkey '^[[B' history-substring-search-down
  [[ -n "${terminfo[kcuu1]}" ]] && bindkey "${terminfo[kcuu1]}" history-substring-search-up
  [[ -n "${terminfo[kcud1]}" ]] && bindkey "${terminfo[kcud1]}" history-substring-search-down
  bindkey -M vicmd 'k' history-substring-search-up
  bindkey -M vicmd 'j' history-substring-search-down
fi

# ------------------------------------------------------------
# Extended tools, all optional. Installed with `--tools extended`
# or `--tools all`; each block is skipped if the tool isn't there.
# ------------------------------------------------------------

# ripgrep — `rg` is used as-is, but make it feed fzf's file search
# so ctrl+t respects .gitignore.
if command -v rg >/dev/null 2>&1; then
  export FZF_DEFAULT_COMMAND='rg --files --hidden --glob "!.git/*"'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
fi

# atuin — replaces ctrl+r with a searchable, syncable history.
# Loaded after fzf so it wins the binding, which is the point of it.
if command -v atuin >/dev/null 2>&1; then
  eval "$(atuin init zsh --disable-up-arrow)"
fi

# direnv — per-directory environment loading. Must come after
# everything that defines precmd hooks.
command -v direnv >/dev/null 2>&1 && eval "$(direnv hook zsh)"

# zoxide already covers `cd`; these are just quality-of-life aliases
# for extended tools when they happen to be installed.
command -v procs >/dev/null 2>&1 && alias ps='procs'
command -v btop  >/dev/null 2>&1 && alias top='btop'
command -v tldr  >/dev/null 2>&1 && alias help='tldr'

# ------------------------------------------------------------
# Oh My Zsh's plugins define aliases, and zsh refuses to define a
# function whose name is already an alias — it's a parse error that
# aborts the rest of the file, silently taking every command after
# it with it. (The git plugin's `gprune` cost us exactly that.)
# Clear any collision before the definitions are parsed. This has to
# live here, not in functions.zsh, so it runs in an earlier parse unit.
# ------------------------------------------------------------
for _furnizsh_name in \
  cheatsheet chs agdoctor doctor theme agupdate mkcd up serve ports \
  killport fkill fe bak sizeof gprune paths reload \
  weather cheat qr gitignore note timer sysinfo dockerclean
do
  unalias "$_furnizsh_name" 2>/dev/null
done
unset _furnizsh_name

# ------------------------------------------------------------
# Helper commands — cheatsheet/chs, agdoctor, theme, agupdate,
# mkcd, up, serve, ports, killport, fkill, fe, bak, sizeof,
# gprune, paths, reload.  Full reference: docs/COMMANDS.md
# ------------------------------------------------------------
[[ -f "$FURNIZSH_DIR/functions.zsh" ]] && source "$FURNIZSH_DIR/functions.zsh"

# Optional network-dependent extras: weather, cheat, qr, gitignore,
# note, timer, sysinfo, dockerclean. Absent if installed with
# --no-extras.
[[ -f "$FURNIZSH_DIR/extras.zsh" ]] && source "$FURNIZSH_DIR/extras.zsh"

# ------------------------------------------------------------
# Starship prompt — must stay last so nothing further down
# overrides the PROMPT it sets.
# ------------------------------------------------------------
command -v starship >/dev/null 2>&1 && eval "$(starship init zsh)"
