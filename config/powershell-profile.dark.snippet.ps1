# >>> squintless >>>
# Squintless - easy-on-the-eyes Tokyo Night Moon (dark) terminal.
# https://github.com/sameer-zahir/squintless
# This block is managed by Squintless. Edit between the markers or remove the whole block to uninstall.

Import-Module PSReadLine -ErrorAction SilentlyContinue

# Tokyo Night Moon syntax colors. Kept in its own try-block: Set-PSReadLineOption -Colors
# is safe even in redirected/non-interactive hosts, unlike -PredictionSource below.
try {
  Set-PSReadLineOption -Colors @{
    Command          = "`e[38;2;130;170;255m"  # blue    #82aaff
    Parameter        = "`e[38;2;79;214;190m"   # teal    #4fd6be
    Operator         = "`e[38;2;255;150;108m"  # orange  #ff966c
    Variable         = "`e[38;2;192;153;255m"  # magenta #c099ff
    String           = "`e[38;2;195;232;141m"  # green   #c3e88d
    Number           = "`e[38;2;192;153;255m"  # magenta #c099ff
    Comment          = "`e[38;2;99;109;166m"   # gray    #636da6
    Keyword          = "`e[38;2;255;117;127m"  # red     #ff757f
    Type             = "`e[38;2;255;199;119m"  # yellow  #ffc777
    Member           = "`e[38;2;200;211;245m"  # fg      #c8d3f5
    InlinePrediction = "`e[38;2;84;92;126m"    # dim     #545c7e
  }
} catch {}

# History-based inline prediction (separate try - throws in some redirected hosts).
try {
  Set-PSReadLineOption -PredictionSource History -PredictionViewStyle InlineView
  Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
} catch {}

# oh-my-posh prompt (Squintless Tokyo Night Moon theme)
$squintlessTheme = "$env:USERPROFILE\.config\ohmyposh\squintless.dark.omp.json"
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
  if (Test-Path $squintlessTheme) { oh-my-posh init pwsh --config $squintlessTheme | Invoke-Expression }
  else { oh-my-posh init pwsh | Invoke-Expression }
}

# Modern CLI tools (only wire up what's installed)
if (Get-Command zoxide  -ErrorAction SilentlyContinue) { Invoke-Expression (& { (zoxide init powershell | Out-String) }) }
if (Get-Command eza     -ErrorAction SilentlyContinue) {
  function ll { eza -la --git --icons --group-directories-first @args }
  function lt { eza --tree --level=2 --icons --git-ignore @args }
}
if (Get-Command bat     -ErrorAction SilentlyContinue) { $env:BAT_THEME = 'TwoDark' }
if (Get-Command lazygit -ErrorAction SilentlyContinue) { Set-Alias lg lazygit }
# <<< squintless <<<
