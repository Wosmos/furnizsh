<#
    afterglow — PowerShell module manifest

    Published to the PowerShell Gallery, which is the native channel on
    Windows (winget wants an installer or a compiled binary; this is neither).

        Install-Module afterglow -Scope CurrentUser
        Install-Afterglow

    The release workflow substitutes ModuleVersion from VERSION.
#>

@{
    RootModule        = 'afterglow.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'b6f4a2c1-8d3e-4f7a-9c5b-2e1d0a8f6b34'

    Author            = 'Wosmos'
    CompanyName       = 'Wosmos'
    Copyright         = '(c) 2026 Wosmos. MIT licensed.'

    Description       = 'A neon terminal in one command - Ghostty + zsh + Starship on Unix, PowerShell + Windows Terminal on Windows. Four matched themes, 24 helper commands.'

    PowerShellVersion = '5.1'

    FunctionsToExport = @(
        'Install-Afterglow',
        'Uninstall-Afterglow',
        'Test-Afterglow',
        'Set-AfterglowTheme',
        'Get-AfterglowVersion'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @('afterglow')

    PrivateData = @{
        PSData = @{
            Tags         = @('terminal', 'dotfiles', 'shell', 'starship', 'prompt',
                             'setup', 'catppuccin', 'gruvbox', 'tokyonight',
                             'Windows', 'Linux', 'MacOS')
            LicenseUri   = 'https://github.com/Wosmos/afterglow/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/Wosmos/afterglow'
            ReleaseNotes = 'https://github.com/Wosmos/afterglow/blob/main/CHANGELOG.md'
        }
    }
}
