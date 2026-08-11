#Requires -Version 5.1
<#
.SYNOPSIS
    afterglow — uninstaller for Windows / PowerShell.

.DESCRIPTION
    Removes the afterglow PowerShell profile and optionally restores whatever
    was there before, unsets the git-delta config, and can strip the colour
    schemes from Windows Terminal.

    It does NOT uninstall the tools (starship, eza, bat, ...) or the PowerShell
    modules unless you pass -Tools — they're useful on their own and you
    probably want to keep them.

.PARAMETER DryRun
    Print every action without changing anything.

.PARAMETER Yes
    Don't prompt for confirmation.

.PARAMETER Restore
    Restore the profile and configs from the most recent backup.

.PARAMETER Tools
    Also uninstall the CLI tools and PowerShell modules (asks first).

.PARAMETER Schemes
    Also remove the afterglow colour schemes from Windows Terminal.

.EXAMPLE
    .\uninstall.ps1 -DryRun

.EXAMPLE
    .\uninstall.ps1 -Restore
#>

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Yes,
    [switch]$Restore,
    [switch]$Tools,
    [switch]$Schemes
)

$ErrorActionPreference = 'Stop'

$BackupRoot = Join-Path $HOME '.afterglow-backup'

$C = @{
    Orange = "`e[38;2;250;179;135m"
    Green  = "`e[38;2;166;227;161m"
    Blue   = "`e[38;2;137;180;250m"
    Gray   = "`e[38;2;108;112;134m"
    Bold   = "`e[1m"
    Reset  = "`e[0m"
}

function Write-Step { param([string]$m) Write-Host "`n$($C.Bold)$($C.Blue)==>$($C.Reset) $m" }
function Write-Info { param([string]$m) Write-Host "    $m" }
function Write-Ok   { param([string]$m) Write-Host "    $($C.Green)OK$($C.Reset)   $m" }
function Write-Skip { param([string]$m) Write-Host "    $($C.Gray)-    $m$($C.Reset)" }
function Write-Warn { param([string]$m) Write-Host "    $($C.Orange)!    $m$($C.Reset)" }

function Invoke-Step {
    param([string]$Description, [scriptblock]$Action)
    if ($DryRun) { Write-Host "    $($C.Gray)[dry-run]$($C.Reset) $Description" }
    else { & $Action }
}

function Confirm-Action {
    param([string]$Message)
    if ($Yes -or $DryRun) { return $true }
    return (Read-Host "    $Message [y/N]") -match '^[yY]'
}

function Get-NewestBackup {
    if (-not (Test-Path $BackupRoot)) { return $null }
    Get-ChildItem $BackupRoot -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1
}

# ------------------------------------------------------------
function Remove-AfterglowProfile {
    Write-Step "Removing the PowerShell profile"

    if (-not (Test-Path $PROFILE)) { Write-Skip "no profile at $PROFILE"; return }

    $content = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
    if ($content -notmatch 'afterglow') {
        Write-Warn "the profile at $PROFILE isn't afterglow's — leaving it alone"
        return
    }

    # Keep a safety copy regardless of what else happens.
    Invoke-Step "back up and remove $PROFILE" {
        Copy-Item $PROFILE "$PROFILE.afterglow-uninstall.bak" -Force
        Remove-Item $PROFILE -Force
    }
    Write-Ok "removed (pre-uninstall copy at $(Split-Path $PROFILE -Leaf).afterglow-uninstall.bak)"
}

function Restore-Backup {
    if (-not $Restore) { return }

    Write-Step "Restoring from backup"

    $newest = Get-NewestBackup
    if (-not $newest) { Write-Warn "no backups found under $BackupRoot"; return }

    Write-Info "Newest backup: $($newest.FullName)"
    Get-ChildItem $newest.FullName | ForEach-Object { Write-Info "  $($_.Name)" }

    Write-Warn "Restoring copies files back over your current config."
    if (-not (Confirm-Action "Restore them?")) { Write-Skip "left as-is"; return }

    # install.ps1 only ever backs up this fixed set, so an explicit table is
    # safer than trying to infer where each file came from.
    $map = @{
        'Microsoft.PowerShell_profile.ps1' = $PROFILE
        'starship.toml'                    = "$HOME\.config\starship.toml"
        'config.yml'                       = "$env:APPDATA\lazygit\config.yml"
        'settings.json'                    = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    }

    foreach ($file in Get-ChildItem $newest.FullName -File) {
        $dest = $map[$file.Name]
        if (-not $dest) { Write-Warn "don't know where $($file.Name) came from - skipping"; continue }

        Invoke-Step "restore $($file.Name) -> $dest" {
            New-Item -ItemType Directory -Force -Path (Split-Path $dest -Parent) | Out-Null
            Copy-Item $file.FullName -Destination $dest -Force
        }
        Write-Ok "restored $dest"
    }
}

function Reset-GitDelta {
    Write-Step "git-delta"

    if ((git config --global core.pager 2>$null) -ne 'delta') {
        Write-Skip "delta isn't the configured pager"
        return
    }
    if (-not (Confirm-Action "Unset delta as your git pager?")) { Write-Skip "left as-is"; return }

    Invoke-Step "git config --global --unset core.pager (and friends)" {
        git config --global --unset core.pager 2>$null
        git config --global --unset interactive.diffFilter 2>$null
        git config --global --unset delta.navigate 2>$null
    }
    Write-Ok "unset"
}

function Remove-TerminalSchemes {
    if (-not $Schemes) { return }

    Write-Step "Windows Terminal colour schemes"

    $settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    if (-not (Test-Path $settingsPath)) { Write-Skip "Windows Terminal settings not found"; return }

    if (-not (Confirm-Action "Remove the 'Catppuccin Mocha' and 'Afterglow Neon' schemes?")) {
        Write-Skip "kept"; return
    }

    Invoke-Step "strip afterglow schemes from settings.json" {
        Copy-Item $settingsPath "$settingsPath.afterglow-uninstall.bak" -Force
        $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
        $ours = @('Catppuccin Mocha', 'Afterglow Neon')
        $settings.schemes = @($settings.schemes | Where-Object { $ours -notcontains $_.name })
        $settings | ConvertTo-Json -Depth 32 | Set-Content $settingsPath -Encoding UTF8
    }
    Write-Ok "removed"
    Write-Warn "any profile still set to one of those schemes will fall back to its default"
}

function Remove-Tools {
    if (-not $Tools) { return }

    Write-Step "Uninstalling tools"
    Write-Warn "This removes starship, zoxide, eza, bat, fd, delta, lazygit and fzf."
    Write-Warn "They're useful outside afterglow — you probably want to keep them."
    if (-not (Confirm-Action "Uninstall them anyway?")) { Write-Skip "kept"; return }

    $ids = @(
        @{ winget = 'Starship.Starship';      scoop = 'starship' },
        @{ winget = 'ajeetdsouza.zoxide';     scoop = 'zoxide'   },
        @{ winget = 'junegunn.fzf';           scoop = 'fzf'      },
        @{ winget = 'eza-community.eza';      scoop = 'eza'      },
        @{ winget = 'sharkdp.bat';            scoop = 'bat'      },
        @{ winget = 'sharkdp.fd';             scoop = 'fd'       },
        @{ winget = 'dandavison.delta';       scoop = 'delta'    },
        @{ winget = 'JesseDuffield.lazygit';  scoop = 'lazygit'  }
    )

    $pkg = if (Get-Command winget -ErrorAction SilentlyContinue) { 'winget' }
           elseif (Get-Command scoop -ErrorAction SilentlyContinue) { 'scoop' }
           else { $null }

    if (-not $pkg) { Write-Warn "no winget or scoop found — remove them by hand"; return }

    foreach ($id in $ids) {
        Invoke-Step "$pkg uninstall $($id[$pkg])" {
            if ($pkg -eq 'winget') { winget uninstall --id $id['winget'] --silent 2>$null | Out-Null }
            else { scoop uninstall $id['scoop'] 2>$null | Out-Null }
        }
    }
    Write-Ok "tools removed"

    if (Confirm-Action "Also remove the Terminal-Icons and PSFzf modules?") {
        foreach ($m in @('Terminal-Icons', 'PSFzf')) {
            Invoke-Step "Uninstall-Module $m" { Uninstall-Module $m -AllVersions -Force -ErrorAction SilentlyContinue }
        }
        Write-Ok "modules removed"
        Write-Info "PSReadLine is left alone — Windows ships and depends on it."
    }
}

# ------------------------------------------------------------
Write-Host "`n$($C.Bold)$($C.Blue)  afterglow uninstall$($C.Reset)  $($C.Gray)(PowerShell)$($C.Reset)"
if ($DryRun) { Write-Host "`n  $($C.Bold)$($C.Orange)DRY RUN - nothing will be changed.$($C.Reset)" }

try {
    Remove-AfterglowProfile
    Restore-Backup
    Reset-GitDelta
    Remove-TerminalSchemes
    Remove-Tools

    Write-Step "Done"
    if ($DryRun) {
        Write-Info "That was a dry run. Rerun without -DryRun to apply."
    } else {
        Write-Info "Open a new PowerShell window for the change to take effect."
        if (Test-Path $BackupRoot) {
            Write-Info "Your backups are still at $BackupRoot - delete them when you're happy."
        }
    }
    Write-Host ""
}
catch {
    Write-Host "`n$($C.Bold)$($C.Orange)error:$($C.Reset) $($_.Exception.Message)`n"
    exit 1
}
