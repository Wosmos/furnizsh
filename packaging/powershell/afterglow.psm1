<#
    afterglow — PowerShell module

    A thin wrapper over the payload scripts, so the Gallery install gives
    you real cmdlets rather than a folder of loose files.

        Install-Module afterglow -Scope CurrentUser
        Install-Afterglow -DryRun
        Install-Afterglow -Theme gruvbox -Tools extended

    Importing this module changes nothing. Setting up your shell only
    happens when you call Install-Afterglow yourself.
#>

Set-StrictMode -Version Latest

# The payload ships alongside this file, in payload\ next to the .psm1.
$script:PayloadRoot = Join-Path $PSScriptRoot 'payload'

function Get-PayloadScript {
    <# Resolve a payload script, with a clear error if the package is incomplete. #>
    param([Parameter(Mandatory)][string]$Name)

    $path = Join-Path $script:PayloadRoot $Name
    if (-not (Test-Path $path)) {
        throw "afterglow: missing payload file '$Name'. The module looks incomplete - try reinstalling it."
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
    $env:AFTERGLOW_SHARE = $script:PayloadRoot
    & $script @Parameters
}

function Install-Afterglow {
    <#
    .SYNOPSIS
        Set up the terminal: tools, PowerShell profile, theme and Windows Terminal schemes.

    .DESCRIPTION
        Backs up anything it replaces to ~/.afterglow-backup/<timestamp>/, is
        idempotent, and can be reversed with Uninstall-Afterglow.

    .PARAMETER Theme
        neon (default), catppuccin, gruvbox or tokyonight.

    .PARAMETER Tools
        core (default), extended or all.

    .PARAMETER DryRun
        Print every action without changing anything. Run this first.

    .EXAMPLE
        Install-Afterglow -DryRun

    .EXAMPLE
        Install-Afterglow -Theme gruvbox -Tools extended
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

function Uninstall-Afterglow {
    <#
    .SYNOPSIS
        Remove afterglow and optionally restore your previous config.

    .PARAMETER Restore
        Also restore the profile and configs from the most recent backup.

    .EXAMPLE
        Uninstall-Afterglow -DryRun

    .EXAMPLE
        Uninstall-Afterglow -Restore
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

function Test-Afterglow {
    <#
    .SYNOPSIS
        Health-check every part of the setup. Exits non-zero on failure, so it works in CI.

    .EXAMPLE
        Test-Afterglow
    #>
    [CmdletBinding()]
    param([switch]$Quiet)

    $params = @{}
    if ($Quiet) { $params['Quiet'] = $true }
    Invoke-PayloadScript -Name 'doctor.ps1' -Parameters $params
}

function Set-AfterglowTheme {
    <#
    .SYNOPSIS
        List afterglow themes, or switch to one.

    .EXAMPLE
        Set-AfterglowTheme            # list them

    .EXAMPLE
        Set-AfterglowTheme gruvbox    # switch
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('neon', 'catppuccin', 'gruvbox', 'tokyonight')]
        [string]$Name
    )

    $themesDir = Join-Path $script:PayloadRoot 'config\themes'

    if (-not $Name) {
        Write-Host "`nThemes  (Set-AfterglowTheme <name> to switch)`n"
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

function Get-AfterglowVersion {
    <#
    .SYNOPSIS
        Show the packaged version and, if set up, the installed one.
    #>
    [CmdletBinding()]
    param()

    $packaged = 'unknown'
    $versionFile = Join-Path $script:PayloadRoot 'VERSION'
    if (Test-Path $versionFile) { $packaged = (Get-Content $versionFile -Raw).Trim() }

    $installedFile = Join-Path $HOME '.config\afterglow\VERSION'
    $installed = if (Test-Path $installedFile) {
        (Get-Content $installedFile -Raw).Trim()
    } else {
        'not installed - run Install-Afterglow'
    }

    [PSCustomObject]@{
        Packaged  = $packaged
        Installed = $installed
        Payload   = $script:PayloadRoot
    }
}

# `afterglow` as a familiar entry point for anyone arriving from the docs.
Set-Alias -Name afterglow -Value Install-Afterglow

Export-ModuleMember `
    -Function Install-Afterglow, Uninstall-Afterglow, Test-Afterglow,
              Set-AfterglowTheme, Get-AfterglowVersion `
    -Alias afterglow
