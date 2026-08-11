<#
    furnizsh — PowerShell module

    A thin wrapper over the payload scripts, so the Gallery install gives
    you real cmdlets rather than a folder of loose files.

        Install-Module furnizsh -Scope CurrentUser
        Install-Furnizsh -DryRun
        Install-Furnizsh -Theme gruvbox -Tools extended

    Importing this module changes nothing. Setting up your shell only
    happens when you call Install-Furnizsh yourself.
#>

Set-StrictMode -Version Latest

# The payload ships alongside this file, in payload\ next to the .psm1.
$script:PayloadRoot = Join-Path $PSScriptRoot 'payload'

function Get-PayloadScript {
    <# Resolve a payload script, with a clear error if the package is incomplete. #>
    param([Parameter(Mandatory)][string]$Name)

    $path = Join-Path $script:PayloadRoot $Name
    if (-not (Test-Path $path)) {
        throw "furnizsh: missing payload file '$Name'. The module looks incomplete - try reinstalling it."
    }
    return $path
}

function Invoke-PayloadScript {
    <# Run a payload script in-process so prompts, colour and -WhatIf-style output work. #>
    param(
        [Parameter(Mandatory)][string]$Name,
        [hashtable]$Parameters = @{}
    )

    $script = Get-PayloadScript $Name
    $env:FURNIZSH_SHARE = $script:PayloadRoot
    & $script @Parameters
}

function Install-Furnizsh {
    <#
    .SYNOPSIS
        Set up the terminal: tools, PowerShell profile, theme and Windows Terminal schemes.

    .DESCRIPTION
        Backs up anything it replaces to ~/.furnizsh-backup/<timestamp>/, is
        idempotent, and can be reversed with Uninstall-Furnizsh.

    .PARAMETER Theme
        neon (default), catppuccin, gruvbox or tokyonight.

    .PARAMETER Tools
        core (default), extended or all.

    .PARAMETER DryRun
        Print every action without changing anything. Run this first.

    .EXAMPLE
        Install-Furnizsh -DryRun

    .EXAMPLE
        Install-Furnizsh -Theme gruvbox -Tools extended
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

    $params = @{ Theme = $Theme; Tools = $Tools }
    foreach ($sw in 'DryRun', 'Yes', 'NoFont', 'NoExtras', 'NoTerminal') {
        if ($PSBoundParameters[$sw]) { $params[$sw] = $true }
    }
    Invoke-PayloadScript -Name 'install.ps1' -Parameters $params
}

function Uninstall-Furnizsh {
    <#
    .SYNOPSIS
        Remove furnizsh and optionally restore your previous config.

    .PARAMETER Restore
        Also restore the profile and configs from the most recent backup.

    .EXAMPLE
        Uninstall-Furnizsh -DryRun

    .EXAMPLE
        Uninstall-Furnizsh -Restore
    #>
    [CmdletBinding()]
    param(
        [switch]$DryRun,
        [switch]$Yes,
        [switch]$Restore,
        [switch]$Tools,
        [switch]$Schemes
    )

    $params = @{}
    foreach ($sw in 'DryRun', 'Yes', 'Restore', 'Tools', 'Schemes') {
        if ($PSBoundParameters[$sw]) { $params[$sw] = $true }
    }
    Invoke-PayloadScript -Name 'uninstall.ps1' -Parameters $params
}

function Test-Furnizsh {
    <#
    .SYNOPSIS
        Health-check every part of the setup. Exits non-zero on failure, so it works in CI.

    .EXAMPLE
        Test-Furnizsh
    #>
    [CmdletBinding()]
    param([switch]$Quiet)

    $params = @{}
    if ($Quiet) { $params['Quiet'] = $true }
    Invoke-PayloadScript -Name 'doctor.ps1' -Parameters $params
}

function Set-FurnizshTheme {
    <#
    .SYNOPSIS
        List furnizsh themes, or switch to one.

    .EXAMPLE
        Set-FurnizshTheme            # list them

    .EXAMPLE
        Set-FurnizshTheme gruvbox    # switch
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('neon', 'catppuccin', 'gruvbox', 'tokyonight')]
        [string]$Name
    )

    $themesDir = Join-Path $script:PayloadRoot 'config\themes'

    if (-not $Name) {
        Write-Host "`nThemes  (Set-FurnizshTheme <name> to switch)`n"
        foreach ($f in Get-ChildItem $themesDir -Filter *.theme | Sort-Object Name) {
            $label = (Select-String -Path $f.FullName -Pattern '^THEME_LABEL="(.*)"').Matches[0].Groups[1].Value
            Write-Host ("  {0,-12} {1}" -f $f.BaseName, $label)
        }
        Write-Host ""
        return
    }

    # A theme switch is an install with only the theme applied — one code
    # path, same backups, same validation.
    Invoke-PayloadScript -Name 'install.ps1' -Parameters @{
        Theme = $Name; Yes = $true; NoFont = $true
    }
}

function Get-FurnizshVersion {
    <#
    .SYNOPSIS
        Show the packaged version and, if set up, the installed one.
    #>
    [CmdletBinding()]
    param()

    $packaged = 'unknown'
    $versionFile = Join-Path $script:PayloadRoot 'VERSION'
    if (Test-Path $versionFile) { $packaged = (Get-Content $versionFile -Raw).Trim() }

    $installedFile = Join-Path $HOME '.config\furnizsh\VERSION'
    $installed = if (Test-Path $installedFile) {
        (Get-Content $installedFile -Raw).Trim()
    } else {
        'not installed - run Install-Furnizsh'
    }

    [PSCustomObject]@{
        Packaged  = $packaged
        Installed = $installed
        Payload   = $script:PayloadRoot
    }
}

# `furnizsh` as a familiar entry point for anyone arriving from the docs.
Set-Alias -Name furnizsh -Value Install-Furnizsh

Export-ModuleMember `
    -Function Install-Furnizsh, Uninstall-Furnizsh, Test-Furnizsh,
              Set-FurnizshTheme, Get-FurnizshVersion `
    -Alias furnizsh
