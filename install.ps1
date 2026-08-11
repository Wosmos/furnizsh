#Requires -Version 5.1
<#
.SYNOPSIS
    furnizsh — installer for Windows / PowerShell.

.DESCRIPTION
    Installs the same tool stack as the Unix installer (starship, zoxide, fzf,
    eza, bat, fd, delta, lazygit), the PowerShell profile with matching aliases
    and helper commands, and the Windows Terminal colour schemes.

    Ghostty has no Windows build. For the real Ghostty experience, use WSL2 and
    run ./install.sh inside it — see docs/WINDOWS.md. This script sets up the
    native-PowerShell half.

    Safe by design: backs up anything it replaces to
    ~/.furnizsh-backup/<timestamp>/, and is idempotent.

.PARAMETER DryRun
    Print every action without changing anything.

.PARAMETER Yes
    Don't prompt for confirmation.

.PARAMETER Theme
    Which look to install: neon (default), catppuccin, gruvbox or tokyonight.
    Sets Starship, lazygit and the Windows Terminal scheme together. Switch
    later at any time with the `theme` command.

.PARAMETER Tools
    Which tool set to install:
      core     (default) starship fzf zoxide eza bat fd delta lazygit
      extended + ripgrep jq tldr btop
      all      + atuin yq httpie dust procs gh

.PARAMETER NoExtras
    Skip the network-dependent helper commands (weather, cheat, qr,
    gitignore, note, timer, sysinfo, dockerclean).

.PARAMETER NoFont
    Skip the JetBrains Mono Nerd Font install.

.PARAMETER NoTerminal
    Skip patching Windows Terminal's settings.json.

.EXAMPLE
    .\install.ps1 -DryRun

.EXAMPLE
    .\install.ps1 -Yes
#>

[CmdletBinding()]
param(
    [ValidateSet('neon', 'catppuccin', 'gruvbox', 'tokyonight')]
    [string]$Theme = 'neon',

    [ValidateSet('core', 'extended', 'all')]
    [string]$Tools = 'core',

    [switch]$DryRun,
    [switch]$Yes,
    [switch]$NoFont,
    [switch]$NoExtras,
    [switch]$NoTerminal
)

$ErrorActionPreference = 'Stop'

$RepoDir       = $PSScriptRoot
$BackupDir     = Join-Path $HOME ".furnizsh-backup\$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$ConfigDir     = Join-Path $HOME '.config'

# ------------------------------------------------------------
# Output helpers
# ------------------------------------------------------------
$C = @{
    Orange = "`e[38;2;250;179;135m"
    Yellow = "`e[38;2;249;226;175m"
    Green  = "`e[38;2;166;227;161m"
    Blue   = "`e[38;2;137;180;250m"
    Gray   = "`e[38;2;108;112;134m"
    Bold   = "`e[1m"
    Reset  = "`e[0m"
}

function Write-Step { param([string]$Message) Write-Host "`n$($C.Bold)$($C.Blue)==>$($C.Reset) $Message" }
function Write-Info { param([string]$Message) Write-Host "    $Message" }
function Write-Ok   { param([string]$Message) Write-Host "    $($C.Green)OK$($C.Reset)   $Message" }
function Write-Skip { param([string]$Message) Write-Host "    $($C.Gray)-    $Message$($C.Reset)" }
function Write-Warn { param([string]$Message) Write-Host "    $($C.Orange)!    $Message$($C.Reset)" }

function Invoke-Step {
    <# Run a scriptblock, or describe it under -DryRun. #>
    param([string]$Description, [scriptblock]$Action)
    if ($DryRun) {
        Write-Host "    $($C.Gray)[dry-run]$($C.Reset) $Description"
    } else {
        & $Action
    }
}

function Confirm-Action {
    param([string]$Message)
    if ($Yes -or $DryRun) { return $true }
    $reply = Read-Host "    $Message [y/N]"
    return $reply -match '^[yY]'
}

function Backup-File {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return }
    Invoke-Step "back up $Path" {
        New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
        Copy-Item -Path $Path -Destination (Join-Path $BackupDir (Split-Path $Path -Leaf)) -Force -Recurse
    }
    Write-Skip "backed up $(Split-Path $Path -Leaf)"
}

function Install-ConfigFile {
    param([string]$Source, [string]$Destination)

    if ((Test-Path $Destination) -and
        ((Get-FileHash $Source).Hash -eq (Get-FileHash $Destination).Hash)) {
        Write-Skip "$Destination already current"
        return
    }

    Backup-File $Destination
    Invoke-Step "copy $Source -> $Destination" {
        New-Item -ItemType Directory -Force -Path (Split-Path $Destination -Parent) | Out-Null
        Copy-Item -Path $Source -Destination $Destination -Force
    }
    Write-Ok $Destination
}

# ------------------------------------------------------------
# Package manager
# ------------------------------------------------------------
function Get-PackageManager {
    if (Get-Command winget -ErrorAction SilentlyContinue) { return 'winget' }
    if (Get-Command scoop  -ErrorAction SilentlyContinue) { return 'scoop' }
    if (Get-Command choco  -ErrorAction SilentlyContinue) { return 'choco' }
    return $null
}

function Install-ToolSet {
    Write-Step "Installing tools"

    $pkgManager = Get-PackageManager
    if (-not $pkgManager) {
        Write-Warn "No package manager found (winget, scoop or choco)."
        Write-Info "winget ships with Windows 11 and recent Windows 10 builds."
        Write-Info "Otherwise install scoop:  irm get.scoop.sh | iex"
        throw "no package manager available"
    }
    Write-Info "Using $pkgManager"

    # id-per-manager, because none of them agree on package names.
    # `Set` marks which tool set first includes each entry.
    $tools = @(
        @{ Name = 'starship'; winget = 'Starship.Starship';   scoop = 'starship';  choco = 'starship'  },
        @{ Name = 'zoxide';   winget = 'ajeetdsouza.zoxide';  scoop = 'zoxide';    choco = 'zoxide'    },
        @{ Name = 'fzf';      winget = 'junegunn.fzf';        scoop = 'fzf';       choco = 'fzf'       },
        @{ Name = 'eza';      winget = 'eza-community.eza';   scoop = 'eza';       choco = 'eza'       },
        @{ Name = 'bat';      winget = 'sharkdp.bat';         scoop = 'bat';       choco = 'bat'       },
        @{ Name = 'fd';       winget = 'sharkdp.fd';          scoop = 'fd';        choco = 'fd'        },
        @{ Name = 'delta';    winget = 'dandavison.delta';    scoop = 'delta';     choco = 'delta'     },
        @{ Name = 'lazygit';  winget = 'JesseDuffield.lazygit'; scoop = 'lazygit'; choco = 'lazygit'   },
        @{ Name = 'git';      winget = 'Git.Git';             scoop = 'git';       choco = 'git'       }
    )

    # tmux and direnv have no meaningful native-Windows equivalent, so the
    # extended set is smaller here than on the Unix side. docs/WINDOWS.md says so.
    if ($Tools -in @('extended', 'all')) {
        $tools += @(
            @{ Name = 'rg';    winget = 'BurntSushi.ripgrep.MSVC'; scoop = 'ripgrep'; choco = 'ripgrep' },
            @{ Name = 'jq';    winget = 'jqlang.jq';               scoop = 'jq';      choco = 'jq'      },
            @{ Name = 'tldr';  winget = 'tldr-pages.tlrc';         scoop = 'tlrc';    choco = 'tldr'    },
            @{ Name = 'btop';  winget = 'aristocratos.btop4win';   scoop = 'btop';    choco = 'btop'    }
        )
    }
    if ($Tools -eq 'all') {
        $tools += @(
            @{ Name = 'atuin';  winget = 'ellie.atuin';       scoop = 'atuin';  choco = 'atuin'  },
            @{ Name = 'yq';     winget = 'MikeFarah.yq';      scoop = 'yq';     choco = 'yq'     },
            @{ Name = 'http';   winget = 'httpie.httpie';     scoop = 'httpie'; choco = 'httpie' },
            @{ Name = 'dust';   winget = 'bootandy.dust';     scoop = 'dust';   choco = 'dust'   },
            @{ Name = 'procs';  winget = 'dalance.procs';     scoop = 'procs';  choco = 'procs'  },
            @{ Name = 'gh';     winget = 'GitHub.cli';        scoop = 'gh';     choco = 'gh'     }
        )
    }

    Write-Info "$($tools.Count) packages ($Tools set)"

    foreach ($tool in $tools) {
        if (Get-Command $tool.Name -ErrorAction SilentlyContinue) {
            Write-Skip "$($tool.Name) already installed"
            continue
        }

        $packageId = $tool[$pkgManager]
        Invoke-Step "$pkgManager install $packageId" {
            switch ($pkgManager) {
                'winget' { winget install --id $packageId --silent --accept-package-agreements --accept-source-agreements | Out-Null }
                'scoop'  { scoop install $packageId | Out-Null }
                'choco'  { choco install $packageId -y | Out-Null }
            }
        }
        Write-Ok $tool.Name
    }
}

function Install-ModuleSet {
    Write-Step "Installing PowerShell modules"

    # PSReadLine gives us the equivalent of zsh-autosuggestions +
    # zsh-syntax-highlighting. Terminal-Icons is the eza-icons equivalent
    # for native PowerShell listings. PSFzf wires fzf to Ctrl+r / Ctrl+t.
    $modules = @(
        @{ Name = 'PSReadLine';     MinVersion = '2.2.0' },
        @{ Name = 'Terminal-Icons'; MinVersion = $null   },
        @{ Name = 'PSFzf';          MinVersion = $null   }
    )

    foreach ($module in $modules) {
        $installed = Get-Module -ListAvailable -Name $module.Name |
                     Sort-Object Version -Descending | Select-Object -First 1

        if ($installed -and (-not $module.MinVersion -or $installed.Version -ge [version]$module.MinVersion)) {
            Write-Skip "$($module.Name) already installed ($($installed.Version))"
            continue
        }

        Invoke-Step "Install-Module $($module.Name)" {
            Install-Module -Name $module.Name -Scope CurrentUser -Force -AllowClobber -SkipPublisherCheck
        }
        Write-Ok $module.Name
    }
}

function Install-NerdFont {
    if ($NoFont) { Write-Skip "skipping font (-NoFont)"; return }

    Write-Step "JetBrains Mono Nerd Font"

    $installedFonts = @()
    try {
        $installedFonts = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\Windows\Fonts", "$env:WINDIR\Fonts" `
                            -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
    } catch {
        # Either font directory can be missing or unreadable on a locked-down
        # machine. That only means we can't prove the font is present, so fall
        # through and install it — the install is idempotent either way.
        Write-Verbose "Could not enumerate font directories: $($_.Exception.Message)"
    }

    if ($installedFonts -match 'JetBrainsMono.*Nerd') {
        Write-Skip "already installed"
        return
    }

    $pkgManager = Get-PackageManager
    if ($pkgManager -eq 'scoop') {
        Invoke-Step "scoop install nerd-fonts/JetBrainsMono-NF-Mono" {
            scoop bucket add nerd-fonts 2>$null | Out-Null
            scoop install nerd-fonts/JetBrainsMono-NF-Mono | Out-Null
        }
        Write-Ok "installed via scoop"
        return
    }

    # winget/choco don't reliably carry Nerd Fonts, so download the release zip.
    Invoke-Step "download + install JetBrainsMono Nerd Font" {
        $tmp = Join-Path $env:TEMP "furnizsh-font-$(Get-Random)"
        New-Item -ItemType Directory -Force -Path $tmp | Out-Null
        $zip = Join-Path $tmp 'JetBrainsMono.zip'

        Invoke-WebRequest -Uri 'https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip' `
                          -OutFile $zip -UseBasicParsing
        Expand-Archive -Path $zip -DestinationPath $tmp -Force

        # Copying into the per-user font dir and registering it avoids
        # needing an elevated shell.
        $userFontDir = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
        New-Item -ItemType Directory -Force -Path $userFontDir | Out-Null

        Get-ChildItem $tmp -Filter '*.ttf' | ForEach-Object {
            Copy-Item $_.FullName -Destination $userFontDir -Force
            New-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts' `
                             -Name "$($_.BaseName) (TrueType)" `
                             -Value (Join-Path $userFontDir $_.Name) `
                             -PropertyType String -Force | Out-Null
        }
        Remove-Item $tmp -Recurse -Force
    }
    Write-Ok "installed (restart your terminal to pick it up)"
}

function Install-Profile {
    Write-Step "Installing the PowerShell profile"

    $source = Join-Path $RepoDir 'config\powershell\Microsoft.PowerShell_profile.ps1'
    if (-not (Test-Path $source)) { throw "profile not found at $source" }

    if (Test-Path $PROFILE) {
        $existing = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
        if ($existing -and $existing -notmatch 'furnizsh') {
            Write-Warn "You already have a PowerShell profile with your own content."
            Write-Info "It will be backed up to $BackupDir before being replaced."
            if (-not (Confirm-Action "Replace it?")) { Write-Skip "left as-is"; return }
        }
    }

    if ($NoExtras) {
        # Strip the marked extras block rather than shipping dead code.
        if ($DryRun) {
            Write-Host "    $($C.Gray)[dry-run]$($C.Reset) install profile without the extras block"
        } else {
            Backup-File $PROFILE
            $lines = Get-Content $source
            $keep = @(); $inExtras = $false
            foreach ($line in $lines) {
                if ($line -match '^# >>> furnizsh extras >>>') { $inExtras = $true; continue }
                if ($line -match '^# <<< furnizsh extras <<<') { $inExtras = $false; continue }
                if (-not $inExtras) { $keep += $line }
            }
            New-Item -ItemType Directory -Force -Path (Split-Path $PROFILE -Parent) | Out-Null
            Set-Content -Path $PROFILE -Value $keep -Encoding UTF8
            Write-Ok "$PROFILE  (without extras)"
        }
    } else {
        Install-ConfigFile -Source $source -Destination $PROFILE
    }
}

function Install-Config {
    Write-Step "Installing config  (theme: $Theme)"

    $agHome = Join-Path $HOME '.config\furnizsh'

    # Every theme ships, so `theme <name>` can switch later without the repo.
    New-Item -ItemType Directory -Force -Path (Join-Path $agHome 'themes\lazygit') | Out-Null
    foreach ($f in Get-ChildItem (Join-Path $RepoDir 'config\themes') -Filter *.theme) {
        Install-ConfigFile -Source $f.FullName -Destination (Join-Path $agHome "themes\$($f.Name)")
    }
    foreach ($f in Get-ChildItem (Join-Path $RepoDir 'config\themes\lazygit') -Filter *.yml) {
        Install-ConfigFile -Source $f.FullName -Destination (Join-Path $agHome "themes\lazygit\$($f.Name)")
    }

    # Read the selected theme's settings out of its .theme file.
    $themeFile = Join-Path $RepoDir "config\themes\$Theme.theme"
    $t = @{}
    foreach ($line in Get-Content $themeFile) {
        if ($line -match '^\s*([A-Z_]+)="(.*)"\s*$') { $t[$Matches[1]] = $Matches[2] }
    }

    # --- Starship: generated from the preset (--force, it won't overwrite otherwise) ---
    $starshipOut = Join-Path $ConfigDir 'starship.toml'
    if ($DryRun) {
        Write-Host "    $($C.Gray)[dry-run]$($C.Reset) starship preset $($t.STARSHIP_PRESET) -o $starshipOut"
    } elseif (Get-Command starship -ErrorAction SilentlyContinue) {
        Backup-File $starshipOut
        New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null
        starship preset $t.STARSHIP_PRESET --force -o $starshipOut 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "$starshipOut  ($($t.STARSHIP_PRESET))"
        } else {
            Write-Warn "starship has no preset '$($t.STARSHIP_PRESET)' — using the bundled config"
            Copy-Item (Join-Path $RepoDir 'config\starship\starship.toml') $starshipOut -Force
        }
    } else {
        Install-ConfigFile -Source (Join-Path $RepoDir 'config\starship\starship.toml') -Destination $starshipOut
    }

    # --- lazygit reads from %APPDATA%\lazygit on Windows ---
    Install-ConfigFile -Source (Join-Path $RepoDir "config\themes\lazygit\$($t.LAZYGIT_PALETTE).yml") `
                       -Destination (Join-Path $env:APPDATA 'lazygit\config.yml')

    if (-not $DryRun) {
        New-Item -ItemType Directory -Force -Path $agHome | Out-Null
        Set-Content -Path (Join-Path $agHome 'current-theme') -Value $Theme -NoNewline
    }
}

function Set-GitDelta {
    Write-Step "Configuring git-delta"

    if (-not (Get-Command delta -ErrorAction SilentlyContinue) -and -not $DryRun) {
        Write-Warn "delta not installed — skipping"
        return
    }

    $current = git config --global core.pager 2>$null
    if ($current -eq 'delta') { Write-Skip "already configured"; return }
    if ($current) {
        Write-Warn "core.pager is currently '$current'"
        if (-not (Confirm-Action "Replace it with delta?")) { Write-Skip "left as-is"; return }
    }

    Invoke-Step "git config --global core.pager delta" {
        git config --global core.pager 'delta'
        git config --global interactive.diffFilter 'delta --color-only'
        git config --global delta.navigate 'true'
    }
    Write-Ok "delta set as the git pager"
}

function Set-WindowsTerminal {
    if ($NoTerminal) { Write-Skip "skipping Windows Terminal (-NoTerminal)"; return }

    Write-Step "Windows Terminal colour schemes"

    $settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    if (-not (Test-Path $settingsPath)) {
        Write-Skip "Windows Terminal settings not found — add the schemes by hand"
        Write-Info "See config\windows-terminal\schemes.json"
        return
    }

    $schemesFile = Join-Path $RepoDir 'config\windows-terminal\schemes.json'
    $ours = (Get-Content $schemesFile -Raw | ConvertFrom-Json).schemes

    Backup-File $settingsPath

    Invoke-Step "merge schemes into Windows Terminal settings.json" {
        $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
        if (-not $settings.schemes) {
            $settings | Add-Member -NotePropertyName schemes -NotePropertyValue @() -Force
        }

        $existingNames = @($settings.schemes | ForEach-Object { $_.name })
        $added = 0
        foreach ($scheme in $ours) {
            if ($existingNames -notcontains $scheme.name) {
                $settings.schemes += $scheme
                $added++
            }
        }

        $settings | ConvertTo-Json -Depth 32 | Set-Content $settingsPath -Encoding UTF8
        Write-Host "    $($C.Gray)added $added scheme(s)$($C.Reset)"
    }

    Write-Ok "schemes available"
    Write-Info "Set them in Windows Terminal: ctrl+, -> your PowerShell profile ->"
    Write-Info "  Appearance -> Color scheme: 'Catppuccin Mocha'"
    Write-Info "  Appearance -> Font face:    'JetBrainsMono Nerd Font Mono'"
}

# ------------------------------------------------------------
# main
# ------------------------------------------------------------
Write-Host "`n$($C.Bold)$($C.Blue)  furnizsh$($C.Reset)  $($C.Gray)a neon terminal, in one command$($C.Reset)"
Write-Host "  $($C.Gray)https://github.com/Wosmos/furnizsh$($C.Reset)"

if ($DryRun) { Write-Host "`n  $($C.Bold)$($C.Orange)DRY RUN - nothing will be changed.$($C.Reset)" }

Write-Host "`n  $($C.Gray)theme$($C.Reset)   $Theme"
Write-Host "  $($C.Gray)tools$($C.Reset)   $Tools"

Write-Host "`n  $($C.Gray)Ghostty has no Windows build. This installs the PowerShell half of$($C.Reset)"
Write-Host "  $($C.Gray)the setup. For real Ghostty + zsh, see docs\WINDOWS.md (WSL2).$($C.Reset)"

try {
    Install-ToolSet
    Install-ModuleSet
    Install-NerdFont
    Install-Config
    Install-Profile
    Set-GitDelta
    Set-WindowsTerminal

    Write-Step "Done"
    if ($DryRun) {
        Write-Info "That was a dry run. Rerun without -DryRun to apply."
    } else {
        if (Test-Path $BackupDir) { Write-Info "Backups: $BackupDir" }
        Write-Info "Open a new PowerShell window, then run:"
        Write-Host "      $($C.Yellow)cheatsheet$($C.Reset)   the reference"
        Write-Host "      $($C.Yellow)agdoctor$($C.Reset)     verify every piece of the setup"
    }
    Write-Host ""
}
catch {
    Write-Host "`n$($C.Bold)$($C.Orange)error:$($C.Reset) $($_.Exception.Message)`n"
    exit 1
}
