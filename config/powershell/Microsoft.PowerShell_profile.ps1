# ============================================================
#  afterglow — PowerShell profile
#  https://github.com/Wosmos/afterglow
#
#  The Windows half of the setup: same tools, same aliases, same
#  helper commands, same Starship prompt as the zsh version.
#
#  PSReadLine covers what zsh-autosuggestions and
#  zsh-syntax-highlighting do on the Unix side — it's built in.
#
#  Installed by install.ps1 to $PROFILE. Nothing here is
#  machine-specific: no PATH edits, no secrets.
# ============================================================

# ------------------------------------------------------------
# PSReadLine — history suggestions + syntax colours
# ------------------------------------------------------------
if (Get-Module -ListAvailable -Name PSReadLine) {
    Import-Module PSReadLine

    $psrlVersion = (Get-Module PSReadLine).Version

    Set-PSReadLineOption -EditMode Windows
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd
    Set-PSReadLineOption -BellStyle None

    # Ghost-text suggestions from history (the zsh-autosuggestions equivalent).
    # PredictionSource landed in 2.1, ListView in 2.2.
    if ($psrlVersion -ge [version]'2.1.0') {
        Set-PSReadLineOption -PredictionSource History
    }
    if ($psrlVersion -ge [version]'2.2.0') {
        Set-PSReadLineOption -PredictionViewStyle ListView
    }

    # Catppuccin Mocha syntax colours (the zsh-syntax-highlighting equivalent)
    Set-PSReadLineOption -Colors @{
        Command                = "#89b4fa"
        Parameter              = "#cba6f7"
        Operator               = "#f5c2e7"
        Variable               = "#f9e2af"
        String                 = "#a6e3a1"
        Number                 = "#fab387"
        Type                   = "#f9e2af"
        Comment                = "#6c7086"
        InlinePrediction       = "#6c7086"
    }

    # Up/Down filter history by what you've already typed —
    # the history-substring-search equivalent.
    Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Key Tab       -Function MenuComplete
}

# ------------------------------------------------------------
# Terminal-Icons — file-type glyphs in listings (needs the Nerd Font)
# ------------------------------------------------------------
if (Get-Module -ListAvailable -Name Terminal-Icons) {
    Import-Module Terminal-Icons
}

# ------------------------------------------------------------
# Modern CLI tool replacements
#
# Aliases beat functions in PowerShell's command resolution order,
# so the built-in ls/cat aliases have to be removed before our
# functions can claim those names.
# ------------------------------------------------------------
function Remove-BuiltinAlias {
    param([string]$Name)
    if (Test-Path "Alias:$Name") {
        Remove-Item "Alias:$Name" -Force -ErrorAction SilentlyContinue
    }
}

if (Get-Command eza -ErrorAction SilentlyContinue) {
    Remove-BuiltinAlias 'ls'
    # --icons=auto, not a bare --icons. Since eza 0.18 the flag takes an
    # optional WHEN value, so a bare --icons swallows the next argument and
    # `ls somedir` fails with "invalid value 'somedir' for '--icons [<WHEN>]'".
    function ls { eza --icons=auto @args }
    function ll { eza -la --icons=auto @args }
    function lt { eza --icons=auto --tree @args }
}

if (Get-Command bat -ErrorAction SilentlyContinue) {
    Remove-BuiltinAlias 'cat'
    function cat { bat @args }
}

if (Get-Command lazygit -ErrorAction SilentlyContinue) {
    function lg { lazygit @args }
}

# ------------------------------------------------------------
# zoxide — frecency-based cd. Use `z <partial-dir-name>`.
# ------------------------------------------------------------
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}

# ------------------------------------------------------------
# fzf — Ctrl+r history, Ctrl+t files, via PSFzf
# ------------------------------------------------------------
if ((Get-Command fzf -ErrorAction SilentlyContinue) -and
    (Get-Module -ListAvailable -Name PSFzf)) {
    Import-Module PSFzf
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
}

# ------------------------------------------------------------
# Window title = current directory
# ------------------------------------------------------------
function prompt {
    $Host.UI.RawUI.WindowTitle = (Get-Location).Path.Replace($HOME, '~')
    # Starship (initialized at the bottom) overwrites the rest of this.
    "PS $($executionContext.SessionState.Path.CurrentLocation)$('>' * ($nestedPromptLevel + 1)) "
}

# ============================================================
#  afterglow commands — the PowerShell ports
# ============================================================

$script:AGColors = @{
    Orange = "`e[38;2;250;179;135m"
    Yellow = "`e[38;2;249;226;175m"
    Blue   = "`e[38;2;137;180;250m"
    Green  = "`e[38;2;166;227;161m"
    Gray   = "`e[38;2;108;112;134m"
    Text   = "`e[38;2;205;214;244m"
    Bold   = "`e[1m"
    Reset  = "`e[0m"
}

function cheatsheet {
    <#
    .SYNOPSIS
      Print the afterglow terminal reference. -Full for the exhaustive version.
    #>
    param([switch]$Full)

    $c = $script:AGColors
    Write-Host ""
    Write-Host "$($c.Bold)$($c.Blue)afterglow cheatsheet$($c.Reset)  $($c.Text)(PowerShell)$($c.Reset)"
    Write-Host ""

    Write-Host "$($c.Bold)$($c.Orange)Tools$($c.Reset)"
    Write-Host "  $($c.Yellow)zoxide$($c.Reset)      z <partial-dir>          frecency-based cd"
    Write-Host "  $($c.Yellow)fzf$($c.Reset)         Ctrl+r / Ctrl+t          fuzzy history / files"
    Write-Host "  $($c.Yellow)eza$($c.Reset)         ls, ll, lt               icons + tree view"
    Write-Host "  $($c.Yellow)bat$($c.Reset)         cat <file>               syntax-highlighted cat"
    Write-Host "  $($c.Yellow)fd$($c.Reset)          fd <pattern>             faster file search"
    Write-Host "  $($c.Yellow)git-delta$($c.Reset)   git diff / show          side-by-side colored diffs"
    Write-Host "  $($c.Yellow)lazygit$($c.Reset)     lg                       full git TUI"
    Write-Host ""

    Write-Host "$($c.Bold)$($c.Orange)afterglow commands$($c.Reset)"
    Write-Host "  $($c.Yellow)mkcd$($c.Reset) <dir>    make + enter a dir        $($c.Yellow)up$($c.Reset) [n]          cd up n levels"
    Write-Host "  $($c.Yellow)serve$($c.Reset) [port]  static server here        $($c.Yellow)ports$($c.Reset)           what's listening"
    Write-Host "  $($c.Yellow)killport$($c.Reset) <p>  free a port               $($c.Yellow)fkill$($c.Reset)           fzf-pick + kill a process"
    Write-Host "  $($c.Yellow)fe$($c.Reset) [query]    fzf-pick + edit a file    $($c.Yellow)bak$($c.Reset) <file>      timestamped backup"
    Write-Host "  $($c.Yellow)sizeof$($c.Reset) [dir]  what's eating the disk    $($c.Yellow)gclean$($c.Reset)          prune merged branches"
    Write-Host "  $($c.Yellow)paths$($c.Reset)         `$env:PATH, one per line   $($c.Yellow)reload$($c.Reset)          restart PowerShell"
    Write-Host "  $($c.Yellow)agdoctor$($c.Reset)      health-check the setup"
    Write-Host ""

    if ($Full) {
        Write-Host "$($c.Bold)$($c.Orange)PSReadLine keys$($c.Reset)"
        Write-Host "  Right / End         accept the ghost-text suggestion"
        Write-Host "  Up / Down           filter history by what you've typed"
        Write-Host "  Tab                 menu completion"
        Write-Host "  Ctrl+r / Ctrl+t     fuzzy history / file search (PSFzf)"
        Write-Host "  F2                  toggle inline vs list prediction view"
        Write-Host ""
        Write-Host "$($c.Bold)$($c.Orange)Windows Terminal keys$($c.Reset)"
        Write-Host "  ctrl+shift+t        new tab            alt+shift+d     split pane"
        Write-Host "  ctrl+shift+w        close pane         alt+arrows      move focus"
        Write-Host "  ctrl+tab            next tab           ctrl+shift+f    search"
        Write-Host "  ctrl+alt+1..9       jump to tab N      ctrl+, settings"
        Write-Host ""
        Write-Host "$($c.Gray)Ghostty is macOS/Linux only — see docs/WINDOWS.md for the WSL2 route.$($c.Reset)"
        Write-Host ""
    }

    Write-Host "$($c.Text)Docs: https://wosmos.github.io/afterglow$($c.Reset)"
    Write-Host ""
}
Set-Alias chs cheatsheet

function agdoctor {
    <#
    .SYNOPSIS
      Health-check every part of the afterglow setup.
    #>
    $c = $script:AGColors
    $failures = 0

    function Test-Item {
        param([string]$Label, [string]$Note, [scriptblock]$Check)
        $pass = $false
        try { $pass = [bool](& $Check) } catch { $pass = $false }
        if ($pass) {
            Write-Host ("  {0}OK{1}   {2}" -f $c.Green, $c.Reset, $Label)
        } else {
            Write-Host ("  {0}FAIL{1} {2}  {3}{4}{5}" -f $c.Orange, $c.Reset, $Label, $c.Gray, $Note, $c.Reset)
            $script:failures++
        }
    }

    $script:failures = 0
    Write-Host ""
    Write-Host "$($c.Bold)$($c.Blue)afterglow doctor$($c.Reset)"
    Write-Host ""

    Write-Host "$($c.Bold)$($c.Orange)Tools$($c.Reset)"
    foreach ($tool in @('starship', 'zoxide', 'fzf', 'eza', 'bat', 'fd', 'delta', 'lazygit', 'git')) {
        Test-Item $tool "not on PATH - see docs/WINDOWS.md" { Get-Command $tool -ErrorAction SilentlyContinue }
    }

    Write-Host ""
    Write-Host "$($c.Bold)$($c.Orange)Modules$($c.Reset)"
    Test-Item "PSReadLine >= 2.2" "Install-Module PSReadLine -Force" {
        (Get-Module -ListAvailable PSReadLine | Sort-Object Version -Descending |
            Select-Object -First 1).Version -ge [version]'2.2.0'
    }
    Test-Item "Terminal-Icons" "Install-Module Terminal-Icons" { Get-Module -ListAvailable Terminal-Icons }
    Test-Item "PSFzf"          "Install-Module PSFzf"          { Get-Module -ListAvailable PSFzf }

    Write-Host ""
    Write-Host "$($c.Bold)$($c.Orange)Config$($c.Reset)"
    Test-Item "profile installed"  "rerun install.ps1"  { Test-Path $PROFILE }
    Test-Item "starship.toml"      "missing ~/.config/starship.toml" { Test-Path "$HOME/.config/starship.toml" }
    Test-Item "delta as git pager" "git config --global core.pager delta" {
        (git config --global core.pager 2>$null) -eq 'delta'
    }

    Write-Host ""
    Write-Host "$($c.Gray)If these are boxes, the Nerd Font isn't active in your terminal:$($c.Reset)"
    Write-Host "     "
    Write-Host ""

    if ($script:failures -eq 0) {
        Write-Host "$($c.Bold)$($c.Green)All good.$($c.Reset) Run $($c.Yellow)cheatsheet$($c.Reset) for the reference."
    } else {
        Write-Host "$($c.Bold)$($c.Orange)$($script:failures) check(s) failed.$($c.Reset) See https://wosmos.github.io/afterglow"
    }
    Write-Host ""
}

function mkcd {
    <#  .SYNOPSIS  Create a directory (including parents) and cd into it.  #>
    param([Parameter(Mandatory)][string]$Path)
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
    Set-Location $Path
}

function up {
    <#  .SYNOPSIS  cd up N levels (default 1).  #>
    param([int]$Levels = 1)
    if ($Levels -lt 1) { $Levels = 1 }
    Set-Location (('..\' * $Levels).TrimEnd('\'))
}

function serve {
    <#  .SYNOPSIS  Static HTTP server in the current directory.  #>
    param([int]$Port = 8000)

    $py = (Get-Command python -ErrorAction SilentlyContinue) ??
          (Get-Command python3 -ErrorAction SilentlyContinue)
    if (-not $py) { Write-Error "serve: python not found"; return }

    $lan = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
            Select-Object -First 1).IPAddress

    $c = $script:AGColors
    Write-Host "$($c.Gray)Serving $((Get-Location).Path)$($c.Reset)"
    Write-Host "  local   $($c.Green)http://localhost:$Port$($c.Reset)"
    if ($lan) { Write-Host "  network $($c.Green)http://${lan}:$Port$($c.Reset)" }
    Write-Host ""
    & $py.Source -m http.server $Port
}

function ports {
    <#  .SYNOPSIS  Everything currently listening, with PID and process name.  #>
    Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
        Select-Object LocalAddress, LocalPort, OwningProcess,
            @{ Name = 'Process'; Expression = {
                (Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName
            }} |
        Sort-Object LocalPort |
        Format-Table -AutoSize
}

function killport {
    <#  .SYNOPSIS  Kill whatever is holding a TCP port.  #>
    param([Parameter(Mandatory)][int]$Port)

    $c = $script:AGColors
    $owners = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
              Select-Object -ExpandProperty OwningProcess -Unique

    if (-not $owners) {
        Write-Host "$($c.Gray)Nothing listening on port $Port.$($c.Reset)"
        return
    }

    foreach ($processId in $owners) {
        $proc = Get-Process -Id $processId -ErrorAction SilentlyContinue
        try {
            Stop-Process -Id $processId -Force -ErrorAction Stop
            Write-Host "$($c.Orange)Killed$($c.Reset) $($proc.ProcessName) (pid $processId) on port $Port"
        } catch {
            Write-Host "$($c.Gray)Could not kill pid $processId - try an elevated shell.$($c.Reset)"
        }
    }
}

function fkill {
    <#  .SYNOPSIS  fzf-pick one or more processes and kill them.  #>
    if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) {
        Write-Error "fkill: fzf not installed"; return
    }

    $c = $script:AGColors
    $picked = Get-Process |
        Sort-Object -Property WS -Descending |
        ForEach-Object { "{0,-8} {1,-30} {2,10:N0} KB" -f $_.Id, $_.ProcessName, ($_.WS / 1KB) } |
        fzf --multi --height 60% --reverse --header 'tab = select multiple, enter = kill'

    foreach ($line in $picked) {
        $procId = ($line -split '\s+')[0]
        try {
            Stop-Process -Id $procId -Force -ErrorAction Stop
            Write-Host "$($c.Orange)killed$($c.Reset) $procId"
        } catch {
            Write-Host "$($c.Gray)could not kill $procId$($c.Reset)"
        }
    }
}

function fe {
    <#  .SYNOPSIS  fzf-pick a file with a preview and open it in $env:EDITOR.  #>
    param([string]$Query = '')

    if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) {
        Write-Error "fe: fzf not installed"; return
    }

    $preview = if (Get-Command bat -ErrorAction SilentlyContinue) {
        'bat --style=numbers --color=always {}'
    } else { 'type {}' }

    $files = if (Get-Command fd -ErrorAction SilentlyContinue) {
        fd --type f --hidden --exclude .git
    } else {
        Get-ChildItem -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch '\\\.git\\' } |
            ForEach-Object { $_.FullName }
    }

    $file = $files | fzf --query $Query --height 70% --reverse `
                         --preview $preview --preview-window 'right:60%'

    if ($file) {
        $editor = if ($env:EDITOR) { $env:EDITOR } else { 'notepad' }
        & $editor $file
    }
}

function bak {
    <#  .SYNOPSIS  Timestamped backup copy alongside the original.  #>
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path $Path)) { Write-Error "bak: $Path not found"; return }
    $dest = "$($Path.TrimEnd('\'))." + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.bak'
    Copy-Item -Path $Path -Destination $dest -Recurse -Force
    Write-Host "$($script:AGColors.Gray)->$($script:AGColors.Reset) $dest"
}

function sizeof {
    <#  .SYNOPSIS  Biggest items in a directory, largest first.  #>
    param([string]$Path = '.')

    Get-ChildItem -Path $Path -Force -ErrorAction SilentlyContinue | ForEach-Object {
        $bytes = if ($_.PSIsContainer) {
            (Get-ChildItem $_.FullName -Recurse -File -Force -ErrorAction SilentlyContinue |
                Measure-Object -Property Length -Sum).Sum
        } else { $_.Length }

        [PSCustomObject]@{
            Size  = switch ($bytes) {
                { $_ -ge 1GB } { '{0:N1} GB' -f ($_ / 1GB); break }
                { $_ -ge 1MB } { '{0:N1} MB' -f ($_ / 1MB); break }
                { $_ -ge 1KB } { '{0:N1} KB' -f ($_ / 1KB); break }
                default        { "$_ B" }
            }
            Bytes = [long]$bytes
            Name  = $_.Name
        }
    } | Sort-Object Bytes -Descending | Select-Object -First 20 Size, Name | Format-Table -AutoSize
}

function gclean {
    <#  .SYNOPSIS  Delete local branches already merged into the default branch.  #>
    $c = $script:AGColors

    git rev-parse --is-inside-work-tree 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Error "gclean: not inside a git repository"; return }

    $default = (git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>$null) -replace '^origin/', ''
    if (-not $default) {
        foreach ($candidate in @('main', 'master', 'trunk')) {
            git show-ref --verify --quiet "refs/heads/$candidate" 2>$null
            if ($LASTEXITCODE -eq 0) { $default = $candidate; break }
        }
    }
    if (-not $default) { Write-Error "gclean: could not determine the default branch"; return }

    $protected = @($default, 'main', 'master', 'develop', 'trunk')
    $stale = git branch --merged $default --format='%(refname:short)' |
             Where-Object { $_ -and $protected -notcontains $_ }

    if (-not $stale) {
        Write-Host "$($c.Gray)Nothing to prune - no branches merged into $default.$($c.Reset)"
        return
    }

    Write-Host "$($c.Gray)Merged into ${default}, safe to delete:$($c.Reset)"
    $stale | ForEach-Object { Write-Host "  $($c.Yellow)$_$($c.Reset)" }

    $reply = Read-Host "`nDelete $($stale.Count) branch(es)? [y/N]"
    if ($reply -notmatch '^[yY]') { Write-Host "Aborted."; return }

    $stale | ForEach-Object { git branch -d $_ }
}

function paths {
    <#  .SYNOPSIS  $env:PATH one entry per line; flags duplicates and missing dirs.  #>
    $c = $script:AGColors
    $seen = @{}
    foreach ($dir in ($env:PATH -split ';' | Where-Object { $_ })) {
        if ($seen.ContainsKey($dir)) {
            Write-Host ("{0}{1,-50} dup{2}" -f $c.Gray, $dir, $c.Reset)
        } elseif (-not (Test-Path $dir)) {
            Write-Host ("{0}{1,-50} missing{2}" -f $c.Orange, $dir, $c.Reset)
        } else {
            Write-Host ("{0}{1}{2}" -f $c.Text, $dir, $c.Reset)
        }
        $seen[$dir] = $true
    }
}

function reload {
    <#  .SYNOPSIS  Restart PowerShell, picking up profile changes.  #>
    Write-Host "$($script:AGColors.Gray)Reloading PowerShell...$($script:AGColors.Reset)"
    $exe = (Get-Process -Id $PID).Path
    Start-Process -FilePath $exe -ArgumentList '-NoLogo'
    exit
}

# ============================================================
#  theme — switch the whole look in one command
#
#  Ghostty has no Windows build, so on this side "theme" means
#  Starship + lazygit + the Windows Terminal colour scheme.
# ============================================================
$script:AGHome = Join-Path $HOME '.config\afterglow'

function Get-AfterglowTheme {
    $marker = Join-Path $script:AGHome 'current-theme'
    if (Test-Path $marker) { (Get-Content $marker -Raw).Trim() } else { 'neon' }
}

function theme {
    <#
    .SYNOPSIS
      List afterglow themes, or switch to one.
    .EXAMPLE
      theme            # list, with the active one marked
    .EXAMPLE
      theme gruvbox    # switch starship + lazygit + Windows Terminal
    #>
    param([string]$Name)

    $c = $script:AGColors
    $themesDir = Join-Path $script:AGHome 'themes'

    if (-not (Test-Path $themesDir)) {
        Write-Error "theme: no themes installed at $themesDir - rerun .\install.ps1"
        return
    }

    $current = Get-AfterglowTheme

    # The .theme files are plain KEY="value" lines, shared with the Unix side.
    function Read-ThemeFile {
        param([string]$Path)
        $t = @{}
        foreach ($line in Get-Content $Path) {
            if ($line -match '^\s*([A-Z_]+)="(.*)"\s*$') { $t[$Matches[1]] = $Matches[2] }
        }
        return $t
    }

    if (-not $Name) {
        Write-Host ""
        Write-Host "$($c.Bold)$($c.Blue)Themes$($c.Reset)  $($c.Gray)(theme <name> to switch)$($c.Reset)"
        Write-Host ""
        foreach ($f in Get-ChildItem $themesDir -Filter *.theme | Sort-Object Name) {
            $t  = Read-ThemeFile $f.FullName
            $id = $f.BaseName
            if ($id -eq $current) {
                Write-Host ("  {0}*{1} {2}{3,-12}{4} {5,-20} {6}{7}{8}" -f `
                    $c.Green, $c.Reset, $c.Bold, $id, $c.Reset, $t.THEME_LABEL, $c.Gray, $t.THEME_BLURB, $c.Reset)
            } else {
                Write-Host ("  {0}-{1} {2}{3,-12}{4} {5,-20} {6}{7}{8}" -f `
                    $c.Gray, $c.Reset, $c.Yellow, $id, $c.Reset, $t.THEME_LABEL, $c.Gray, $t.THEME_BLURB, $c.Reset)
            }
        }
        Write-Host ""
        return
    }

    $themeFile = Join-Path $themesDir "$Name.theme"
    if (-not (Test-Path $themeFile)) {
        Write-Error "theme: unknown theme '$Name'. Run ``theme`` to list them."
        return
    }
    $t = Read-ThemeFile $themeFile

    Write-Host ""
    Write-Host "$($c.Gray)Switching to $($c.Bold)$($t.THEME_LABEL)$($c.Reset)"

    # --- Starship. --force is required: it refuses to overwrite otherwise. ---
    if (Get-Command starship -ErrorAction SilentlyContinue) {
        $out = Join-Path $HOME '.config\starship.toml'
        New-Item -ItemType Directory -Force -Path (Split-Path $out -Parent) | Out-Null
        starship preset $t.STARSHIP_PRESET --force -o $out 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  $($c.Green)OK$($c.Reset) starship $($c.Gray)$($t.STARSHIP_PRESET)$($c.Reset)"
        } else {
            Write-Host "  $($c.Orange)!$($c.Reset) starship has no preset '$($t.STARSHIP_PRESET)' - prompt unchanged"
        }
    }

    # --- lazygit ---
    $lgSrc = Join-Path $themesDir "lazygit\$($t.LAZYGIT_PALETTE).yml"
    if (Test-Path $lgSrc) {
        $lgDest = Join-Path $env:APPDATA 'lazygit\config.yml'
        New-Item -ItemType Directory -Force -Path (Split-Path $lgDest -Parent) | Out-Null
        Copy-Item $lgSrc $lgDest -Force
        Write-Host "  $($c.Green)OK$($c.Reset) lazygit  $($c.Gray)$($t.LAZYGIT_PALETTE)$($c.Reset)"
    }

    New-Item -ItemType Directory -Force -Path $script:AGHome | Out-Null
    Set-Content -Path (Join-Path $script:AGHome 'current-theme') -Value $Name -NoNewline

    Write-Host ""
    Write-Host "$($c.Gray)Set the matching Windows Terminal scheme in ctrl+, if you want the"
    Write-Host "terminal colours to follow too. Run $($c.Yellow)reload$($c.Reset)$($c.Gray) for the new prompt.$($c.Reset)"
    Write-Host ""
}

function agupdate {
    <#  .SYNOPSIS  git pull the afterglow repo and reapply it.  #>
    $c = $script:AGColors
    $repo = if ($env:AFTERGLOW_REPO) { $env:AFTERGLOW_REPO } else { Join-Path $HOME 'Documents\GitHub\afterglow' }

    if (-not (Test-Path (Join-Path $repo '.git'))) {
        Write-Error "agupdate: no afterglow checkout at $repo. Set `$env:AFTERGLOW_REPO."
        return
    }
    Write-Host "$($c.Gray)Updating $repo$($c.Reset)"
    git -C $repo pull --ff-only
    if ($LASTEXITCODE -ne 0) { Write-Error "agupdate: pull failed"; return }
    & (Join-Path $repo 'install.ps1') -Yes
    Write-Host "$($c.Green)OK$($c.Reset) updated - run $($c.Yellow)reload$($c.Reset)"
}

# >>> afterglow extras >>>
# ============================================================
#  Extras — the network-dependent helpers, matching extras.zsh
#  install.ps1 -NoExtras strips everything between these markers.
# ============================================================

function weather {
    <#  .SYNOPSIS  Forecast in the terminal (wttr.in).  #>
    param([Parameter(ValueFromRemainingArguments)][string[]]$Location)
    $where = ($Location -join '+')
    try { (Invoke-WebRequest -Uri "https://wttr.in/${where}?F" -UserAgent 'curl' -TimeoutSec 10).Content }
    catch { Write-Error "weather: could not reach wttr.in" }
}

function cheat {
    <#  .SYNOPSIS  Practical examples for any command (cheat.sh).  #>
    param([Parameter(Mandatory)][string]$Command,
          [Parameter(ValueFromRemainingArguments)][string[]]$Search)
    $topic = $Command
    if ($Search) { $topic += '~' + ($Search -join '+') }
    try { (Invoke-WebRequest -Uri "https://cheat.sh/$topic" -UserAgent 'curl' -TimeoutSec 10).Content }
    catch { Write-Error "cheat: could not reach cheat.sh" }
}

function qr {
    <#  .SYNOPSIS  Render a QR code in the terminal (qrenco.de).  #>
    param([Parameter(Mandatory, ValueFromRemainingArguments)][string[]]$Text)
    try {
        (Invoke-WebRequest -Uri 'https://qrenco.de/' -Method Post -UserAgent 'curl' `
            -Body @{ text = ($Text -join ' ') } -TimeoutSec 10).Content
    } catch { Write-Error "qr: could not reach qrenco.de" }
}

function gitignore {
    <#  .SYNOPSIS  Fetch a .gitignore. -Write saves it instead of printing.  #>
    param([Parameter(Mandatory)][string]$Languages, [switch]$Write)
    try {
        $body = (Invoke-WebRequest -TimeoutSec 10 `
            -Uri "https://www.toptal.com/developers/gitignore/api/$($Languages -replace '\s','')").Content
    } catch { Write-Error "gitignore: could not reach the generator"; return }

    if ($Write) {
        if (Test-Path .gitignore) { Add-Content .gitignore $body } else { Set-Content .gitignore $body }
        Write-Host "$($script:AGColors.Green)OK$($script:AGColors.Reset) wrote .gitignore ($Languages)"
    } else { $body }
}

function note {
    <#  .SYNOPSIS  Timestamped scratch notes, stored locally.  #>
    param([Parameter(ValueFromRemainingArguments)][string[]]$Text, [switch]$List)

    $file = if ($env:AFTERGLOW_NOTES) { $env:AFTERGLOW_NOTES } else { Join-Path $HOME '.afterglow-notes.md' }
    if (-not (Test-Path $file)) { Set-Content $file "# notes`n" }

    if ($List)      { Get-Content $file -Tail 20 }
    elseif (-not $Text) { & $(if ($env:EDITOR) { $env:EDITOR } else { 'notepad' }) $file }
    else {
        Add-Content $file ("- {0}  {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), ($Text -join ' '))
        Write-Host "$($script:AGColors.Green)OK$($script:AGColors.Reset) noted"
    }
}

function timer {
    <#  .SYNOPSIS  Countdown, then a notification.  #>
    param([Parameter(Mandatory)][double]$Minutes,
          [Parameter(ValueFromRemainingArguments)][string[]]$Label)

    $c = $script:AGColors
    $name = if ($Label) { $Label -join ' ' } else { 'timer' }
    $end  = (Get-Date).AddMinutes($Minutes)

    Write-Host "$($c.Bold)$name$($c.Reset) - $Minutes min. ctrl+c to cancel."
    while ((Get-Date) -lt $end) {
        $left = $end - (Get-Date)
        Write-Host -NoNewline ("`r  {0}{1:mm\:ss} remaining{2} " -f $c.Gray, $left, $c.Reset)
        Start-Sleep -Seconds 1
    }
    Write-Host ("`r{0}OK {1} done{2}{3}" -f $c.Green, $name, $c.Reset, (' ' * 20))
    [console]::beep(880, 400)
}

function sysinfo {
    <#  .SYNOPSIS  A compact summary of the machine.  #>
    $c  = $script:AGColors
    $os = Get-CimInstance Win32_OperatingSystem
    $cs = Get-CimInstance Win32_ComputerSystem
    $cpu = (Get-CimInstance Win32_Processor | Select-Object -First 1)
    $disk = Get-PSDrive C -ErrorAction SilentlyContinue

    function Row { param($k, $v) Write-Host ("  {0}{1,-12}{2} {3}" -f $c.Yellow, $k, $c.Reset, $v) }

    Write-Host ""
    Write-Host "$($c.Bold)$($c.Blue)sysinfo$($c.Reset)"
    Write-Host ""
    Row 'os'      "$($os.Caption) $($os.Version)"
    Row 'host'    $env:COMPUTERNAME
    Row 'cpu'     $cpu.Name.Trim()
    Row 'cores'   "$($cpu.NumberOfLogicalProcessors) logical"
    Row 'memory'  ("{0:N0} GB" -f ($cs.TotalPhysicalMemory / 1GB))
    Row 'uptime'  ((Get-Date) - $os.LastBootUpTime).ToString('d\d\ hh\h\ mm\m')
    if ($disk) { Row 'disk' ("{0:N0} GB free of {1:N0} GB" -f ($disk.Free / 1GB), (($disk.Free + $disk.Used) / 1GB)) }
    Row 'shell'   "PowerShell $($PSVersionTable.PSVersion)"
    Row 'theme'   (Get-AfterglowTheme)
    Write-Host ""
}

function dockerclean {
    <#  .SYNOPSIS  Reclaim disk from docker. Named volumes are never touched.  #>
    $c = $script:AGColors
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { Write-Error "dockerclean: docker not installed"; return }
    docker info 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Error "dockerclean: docker isn't running"; return }

    Write-Host "`n$($c.Bold)Current usage$($c.Reset)"
    docker system df
    Write-Host "`n$($c.Gray)Removes stopped containers, unused networks, dangling images and build cache."
    Write-Host "Named volumes are NOT touched - your database data is safe.$($c.Reset)"
    if ((Read-Host "`nProceed? [y/N]") -notmatch '^[yY]') { Write-Host "Aborted."; return }
    docker system prune -f
    Write-Host "`n$($c.Green)OK$($c.Reset) done`n"
}

# <<< afterglow extras <<<

# ------------------------------------------------------------
# Starship prompt — must stay last so nothing below overrides
# the prompt function it defines.
# ------------------------------------------------------------
if (Get-Command starship -ErrorAction SilentlyContinue) {
    $ENV:STARSHIP_CONFIG = "$HOME\.config\starship.toml"
    Invoke-Expression (&starship init powershell)
}
