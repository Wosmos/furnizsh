#Requires -Version 5.1
<#
.SYNOPSIS
    furnizsh — health check for Windows / PowerShell.

.DESCRIPTION
    Verifies every part of the setup and tells you the exact command to fix
    whatever is missing. This is the standalone version; once the profile is
    installed, `fzdoctor` does the same thing from inside any PowerShell
    session.

    Exits 0 if everything passes, 1 otherwise — safe to use in CI.

.PARAMETER Quiet
    Only print failures and the summary.

.EXAMPLE
    .\doctor.ps1

.EXAMPLE
    .\doctor.ps1 -Quiet
#>

[CmdletBinding()]
param([switch]$Quiet)

$C = @{
    Orange = "`e[38;2;250;179;135m"
    Yellow = "`e[38;2;249;226;175m"
    Green  = "`e[38;2;166;227;161m"
    Blue   = "`e[38;2;137;180;250m"
    Gray   = "`e[38;2;108;112;134m"
    Bold   = "`e[1m"
    Reset  = "`e[0m"
}

$script:Failures = 0

function Write-Section {
    param([string]$Title)
    if (-not $Quiet) { Write-Host "`n$($C.Bold)$($C.Orange)$Title$($C.Reset)" }
}

function Test-Item {
    <# Label, the fix to print on failure, and a scriptblock that must be truthy. #>
    param([string]$Label, [string]$Fix, [scriptblock]$Check)

    $pass = $false
    try { $pass = [bool](& $Check) } catch { $pass = $false }

    if ($pass) {
        if (-not $Quiet) { Write-Host ("  {0}OK{1}   {2}" -f $C.Green, $C.Reset, $Label) }
    } else {
        Write-Host ("  {0}FAIL{1} {2,-28} {3}{4}{5}" -f $C.Orange, $C.Reset, $Label, $C.Gray, $Fix, $C.Reset)
        $script:Failures++
    }
}

if (-not $Quiet) { Write-Host "`n$($C.Bold)$($C.Blue)  furnizsh doctor$($C.Reset)  $($C.Gray)(PowerShell)$($C.Reset)" }

# ------------------------------------------------------------
Write-Section "Tools"
# ------------------------------------------------------------
foreach ($tool in @('git', 'starship', 'zoxide', 'fzf', 'eza', 'bat', 'fd', 'delta', 'lazygit')) {
    Test-Item $tool "not on PATH - rerun .\install.ps1" { Get-Command $tool -ErrorAction SilentlyContinue }
}

# ------------------------------------------------------------
Write-Section "PowerShell"
# ------------------------------------------------------------
Test-Item "PowerShell 7+" "winget install Microsoft.PowerShell" {
    $PSVersionTable.PSVersion.Major -ge 7
}

Test-Item "PSReadLine >= 2.2" "Install-Module PSReadLine -Force -SkipPublisherCheck" {
    $m = Get-Module -ListAvailable PSReadLine | Sort-Object Version -Descending | Select-Object -First 1
    $m -and $m.Version -ge [version]'2.2.0'
}
Test-Item "Terminal-Icons" "Install-Module Terminal-Icons -Scope CurrentUser" {
    Get-Module -ListAvailable Terminal-Icons
}
Test-Item "PSFzf" "Install-Module PSFzf -Scope CurrentUser" {
    Get-Module -ListAvailable PSFzf
}

Test-Item "profile installed" "rerun .\install.ps1" { Test-Path $PROFILE }
Test-Item "profile is furnizsh's" "rerun .\install.ps1" {
    (Test-Path $PROFILE) -and ((Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue) -match 'furnizsh')
}

# ------------------------------------------------------------
Write-Section "Config"
# ------------------------------------------------------------
Test-Item "starship.toml" "rerun .\install.ps1" { Test-Path "$HOME\.config\starship.toml" }
Test-Item "lazygit theme"  "rerun .\install.ps1" { Test-Path "$env:APPDATA\lazygit\config.yml" }
Test-Item "delta is the git pager" "git config --global core.pager delta" {
    (git config --global core.pager 2>$null) -eq 'delta'
}

# ------------------------------------------------------------
Write-Section "Terminal"
# ------------------------------------------------------------
$wtSettings = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
Test-Item "Windows Terminal" "winget install Microsoft.WindowsTerminal" { Test-Path $wtSettings }
Test-Item "colour schemes added" "rerun .\install.ps1 (or add them by hand)" {
    (Test-Path $wtSettings) -and
    ((Get-Content $wtSettings -Raw -ErrorAction SilentlyContinue) -match 'Catppuccin Mocha|Furnizsh Neon')
}

Test-Item "JetBrainsMono Nerd Font" "rerun .\install.ps1 (installs it per-user)" {
    $dirs = @("$env:LOCALAPPDATA\Microsoft\Windows\Fonts", "$env:WINDIR\Fonts")
    @(Get-ChildItem $dirs -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match 'JetBrainsMono.*NerdFont|JetBrainsMonoNerdFont' }).Count -gt 0
}

if (-not $Quiet) {
    Write-Host "`n  $($C.Gray)Truecolor check - three distinct pastel blocks:$($C.Reset)"
    Write-Host "    `e[48;2;250;179;135m   `e[0m`e[48;2;166;227;161m   `e[0m`e[48;2;137;180;250m   `e[0m"
    Write-Host "`n  $($C.Gray)Nerd Font check - these should be icons, not boxes:$($C.Reset)"
    Write-Host "         "
}

# ------------------------------------------------------------
if ($script:Failures -eq 0) {
    if (-not $Quiet) {
        Write-Host "`n$($C.Bold)$($C.Green)  All good.$($C.Reset) Run $($C.Yellow)cheatsheet$($C.Reset) for the reference.`n"
    }
    exit 0
} else {
    Write-Host "`n$($C.Bold)$($C.Orange)  $($script:Failures) check(s) failed.$($C.Reset) Docs: https://wosmos.github.io/furnizsh`n"
    exit 1
}
