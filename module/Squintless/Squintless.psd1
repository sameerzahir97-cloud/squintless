@{
    RootModule        = 'Squintless.psm1'
    ModuleVersion     = '1.1.0'
    GUID              = 'b3a9c1e7-5d42-4f8b-9e10-7a6c2d4b8f31'
    Author            = 'Sameer Zahir'
    CompanyName       = 'Sameer Zahir'
    Copyright         = '(c) 2026 Sameer Zahir. MIT License.'
    Description       = 'Easy on the eyes - a one-command, eye-strain-optimized terminal + Claude Code setup (Gruvbox light or Tokyo Night Moon dark). Invoke-Squintless runs the installer; supports -Dark/-Light, -WithTerminalDefaults, -WithClaude, -SkipDeps, -Uninstall.'
    PowerShellVersion = '7.0'
    FunctionsToExport = @('Invoke-Squintless')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags         = @('terminal', 'theme', 'gruvbox', 'tokyo-night', 'eye-strain', 'accessibility', 'oh-my-posh', 'windows-terminal', 'dark-theme', 'light-theme')
            LicenseUri   = 'https://github.com/sameer-zahir/squintless/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/sameer-zahir/squintless'
            ReleaseNotes = 'https://github.com/sameer-zahir/squintless/releases'
        }
    }
}
