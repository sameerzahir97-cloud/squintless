# Squintless - a thin launcher for the installer.
#
# The module deliberately holds no installer logic: Invoke-Squintless fetches the
# canonical install.ps1 from the repo and runs it with the same parameters, so the
# PowerShell Gallery package can never drift from the script everyone else runs.
#
#   Install-Module Squintless
#   Invoke-Squintless -Dark -WithClaude

function Invoke-Squintless {
    [CmdletBinding()]
    param(
        [switch]$Dark,
        [switch]$Light,
        [switch]$WithTerminalDefaults,
        [switch]$WithClaude,
        [switch]$SkipDeps,
        [switch]$Uninstall
    )
    $url = 'https://raw.githubusercontent.com/sameer-zahir/squintless/main/install.ps1'
    $script = Invoke-RestMethod -Uri $url
    & ([scriptblock]::Create($script)) @PSBoundParameters
}

Export-ModuleMember -Function Invoke-Squintless
