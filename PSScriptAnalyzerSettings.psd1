@{
    Severity     = @('Error', 'Warning')
    ExcludeRules = @(
        # The installer's UX is deliberately colored, user-facing console output;
        # Write-Host is correct here (output must not leak into the pipeline).
        'PSAvoidUsingWriteHost'
    )
}
