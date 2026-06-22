# >>> squintless >>>
# Squintless - easy-on-the-eyes Gruvbox-light terminal.
# https://github.com/sameer-zahir/squintless
# This block is managed by Squintless. Edit between the markers or remove the whole block to uninstall.

Import-Module PSReadLine -ErrorAction SilentlyContinue

# Gruvbox-light syntax colors. Kept in its own try-block: Set-PSReadLineOption -Colors
# is safe even in redirected/non-interactive hosts, unlike -PredictionSource below.
try {
  Set-PSReadLineOption -Colors @{
    Command          = "`e[38;2;7;102;120m"    # blue   #076678
    Parameter        = "`e[38;2;66;123;88m"    # aqua   #427b58
    Operator         = "`e[38;2;175;58;3m"     # orange #af3a03
    Variable         = "`e[38;2;143;63;113m"   # purple #8f3f71
    String           = "`e[38;2;121;116;14m"   # green  #79740e
    Number           = "`e[38;2;143;63;113m"   # purple #8f3f71
    Comment          = "`e[38;2;146;131;116m"  # gray   #928374
    Keyword          = "`e[38;2;157;0;6m"      # red    #9d0006
    Type             = "`e[38;2;181;118;20m"   # yellow #b57614
    Member           = "`e[38;2;60;56;54m"     # fg     #3c3836
    InlinePrediction = "`e[38;2;168;153;132m"  # gray   #a89984
  }
} catch {}

# History-based inline prediction (separate try - throws in some redirected hosts).
try {
  Set-PSReadLineOption -PredictionSource History -PredictionViewStyle InlineView
  Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
} catch {}

# oh-my-posh prompt (Squintless Gruvbox-light theme)
$squintlessTheme = "$env:USERPROFILE\.config\ohmyposh\squintless.omp.json"
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
if (Get-Command bat     -ErrorAction SilentlyContinue) { $env:BAT_THEME = 'gruvbox-light' }
if (Get-Command lazygit -ErrorAction SilentlyContinue) { Set-Alias lg lazygit }
# <<< squintless <<<
