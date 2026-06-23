#Requires -Modules Pester
# Unit tests for install.ps1. We load only its *functions* (via AST) and the
# variant-resolution block, so nothing touches the real system.

BeforeAll {
    $installPath = (Resolve-Path (Join-Path $PSScriptRoot '..' 'install.ps1')).Path
    $src = Get-Content -Raw $installPath
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($src, [ref]$null, [ref]$null)
    foreach ($fn in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
        . ([scriptblock]::Create($fn.Extent.Text))
    }
    $variantStart = $src.IndexOf('# ---------- variant:')
    $variantEnd   = $src.IndexOf('# ---------- 1. dependencies ----------')
    $VariantBlock = $src.Substring($variantStart, $variantEnd - $variantStart)
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}

Describe 'Read-Choice' {
    It 'returns the default when stdin is redirected (no hang)' {
        Read-Choice -Prompt 'pick' -Default 'light' | Should -Be 'light'
    }
}

Describe 'Merge-SquintlessBlock' {
    BeforeAll { $snippet = "# >>> squintless >>>`nSet-Foo`n# <<< squintless <<<" }

    It 'appends a single block to plain content' {
        $r = Merge-SquintlessBlock -Current 'existing line' -Snippet $snippet
        ([regex]::Matches($r, [regex]::Escape('# >>> squintless >>>'))).Count | Should -Be 1
        $r | Should -Match 'Set-Foo'
    }
    It 'is idempotent - running twice leaves exactly one block' {
        $once  = Merge-SquintlessBlock -Current "pre`n" -Snippet $snippet
        $twice = Merge-SquintlessBlock -Current $once -Snippet $snippet
        ([regex]::Matches($twice, [regex]::Escape('# >>> squintless >>>'))).Count | Should -Be 1
        ([regex]::Matches($twice, [regex]::Escape('# <<< squintless <<<'))).Count | Should -Be 1
    }
    It 'preserves surrounding user content' {
        $r = Merge-SquintlessBlock -Current "line1`nline2" -Snippet $snippet
        $r | Should -Match 'line1'
        $r | Should -Match 'line2'
    }
    It 'replaces an old block body with the new one' {
        $old = Merge-SquintlessBlock -Current '' -Snippet "# >>> squintless >>>`nOLD`n# <<< squintless <<<"
        $new = Merge-SquintlessBlock -Current $old -Snippet "# >>> squintless >>>`nNEW`n# <<< squintless <<<"
        $new | Should -Match 'NEW'
        $new | Should -Not -Match 'OLD'
    }
}

Describe 'Variant resolution' {
    It 'resolves -Dark to the Tokyo Night Moon scheme' {
        $Dark = $true; $Light = $false
        . ([scriptblock]::Create($VariantBlock))
        $variant | Should -Be 'dark'
        $V.SchemeFile | Should -Be 'windows-terminal.scheme.dark.json'
        $V.ClaudeTheme | Should -Be 'dark'
    }
    It 'resolves -Light to the Gruvbox light scheme' {
        $Dark = $false; $Light = $true
        . ([scriptblock]::Create($VariantBlock))
        $variant | Should -Be 'light'
        $V.SchemeFile | Should -Be 'windows-terminal.scheme.json'
    }
    It 'defaults to light with no flags when stdin is redirected' {
        $Dark = $false; $Light = $false
        . ([scriptblock]::Create($VariantBlock))
        $variant | Should -Be 'light'
    }
    It 'prefers dark when both flags are supplied' {
        $Dark = $true; $Light = $true
        . ([scriptblock]::Create($VariantBlock))
        $variant | Should -Be 'dark'
    }
}

Describe 'Resolve-CcstatuslineCommand' {
    It 'prefers the bun binary when it exists' {
        Mock Test-Path { $true } -ParameterFilter { $Path -like '*.bun*ccstatusline.exe' }
        Mock Test-Path { $false }
        Resolve-CcstatuslineCommand | Should -Match 'ccstatusline\.exe'
    }
    It 'returns null when nothing is installed' {
        Mock Test-Path { $false }
        Mock Get-Command { $null }
        Resolve-CcstatuslineCommand | Should -BeNullOrEmpty
    }
}

Describe 'Generated Windows Terminal schemes' {
    It 'every scheme defines name + all 16 colors' {
        $req = @('name', 'background', 'foreground',
            'black', 'red', 'green', 'yellow', 'blue', 'purple', 'cyan', 'white',
            'brightBlack', 'brightRed', 'brightGreen', 'brightYellow',
            'brightBlue', 'brightPurple', 'brightCyan', 'brightWhite',
            'cursorColor', 'selectionBackground')
        foreach ($f in 'windows-terminal.scheme.json', 'windows-terminal.scheme.dark.json') {
            $d = Get-Content -Raw (Join-Path $RepoRoot 'config' $f) | ConvertFrom-Json
            foreach ($k in $req) { $d.PSObject.Properties.Name | Should -Contain $k }
        }
    }
}
