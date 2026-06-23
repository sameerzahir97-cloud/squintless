#Requires -Version 7.0
<#
.SYNOPSIS
  Squintless - easy-on-the-eyes terminal + Claude Code setup. Pick a palette:
  Gruvbox light (default) or Tokyo Night Moon (dark).
  https://github.com/sameer-zahir/squintless

.DESCRIPTION
  Installs the tools and drops in the configs that make up Squintless:
    - Windows Terminal color scheme - Gruvbox light or Tokyo Night Moon (+ optional font/render defaults)
    - JetBrains Mono Nerd Font
    - Themed PowerShell (PSReadLine colors + oh-my-posh prompt + zoxide/eza/bat/lazygit)
    - git-delta with a matching syntax theme (gruvbox-light / TwoDark)
    - (optional) Claude Code theme + ccstatusline statusline

  Light is the default; the installer asks light/dark when run interactively, or
  pass -Dark / -Light to choose explicitly. Safe by design: backs up every file it
  touches, is idempotent (re-running won't duplicate anything), and only wires up
  tools that are present.

.PARAMETER Dark
  Install the Tokyo Night Moon (dark) variant instead of Gruvbox light.

.PARAMETER Light
  Force the Gruvbox light variant (skip the interactive light/dark prompt).

.PARAMETER WithTerminalDefaults
  Also apply the font / cellHeight / cursor / antialiasing defaults to Windows
  Terminal's profiles.defaults (light = OLED-tuned grayscale, dark = ClearType - see README).

.PARAMETER WithClaude
  Also set the Claude Code theme (matching the variant) and the ccstatusline statusline.

.PARAMETER SkipDeps
  Don't install any winget/bun packages; just place the configs.

.PARAMETER Uninstall
  Reverse what the installer changed (PowerShell profile block, Windows Terminal
  color scheme, git-delta config, theme files) for either variant. Backs up before
  editing and leaves winget-installed tools in place.

.EXAMPLE
  irm https://raw.githubusercontent.com/sameer-zahir/squintless/main/install.ps1 | iex

.EXAMPLE
  $s = irm https://raw.githubusercontent.com/sameer-zahir/squintless/main/install.ps1
  & ([scriptblock]::Create($s)) -Dark -WithTerminalDefaults -WithClaude

.EXAMPLE
  $s = irm https://raw.githubusercontent.com/sameer-zahir/squintless/main/install.ps1
  & ([scriptblock]::Create($s)) -Uninstall
#>
[CmdletBinding()]
param(
  [switch]$Dark,
  [switch]$Light,
  [switch]$WithTerminalDefaults,
  [switch]$WithClaude,
  [switch]$SkipDeps,
  [switch]$Uninstall
)

# PowerShell 7+ is required. The #Requires line above is silently ignored when this
# script is run via `irm ... | iex`, so enforce it explicitly here. Use `return`
# (never `exit`) so the one-liner path doesn't close the user's window.
if ($PSVersionTable.PSVersion.Major -lt 7) {
  Write-Host "`n  Squintless needs PowerShell 7+ (you're on $($PSVersionTable.PSVersion))." -ForegroundColor Yellow
  Write-Host   "  Install it, then re-run this inside a PowerShell 7 window:`n" -ForegroundColor Yellow
  Write-Host   "    winget install --id Microsoft.PowerShell -e" -ForegroundColor Cyan
  Write-Host   "    pwsh   # then paste the install command again`n" -ForegroundColor DarkGray
  return
}

# Belt-and-suspenders for older TLS defaults (harmless no-op on PS7).
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { $null = $_ }

$ErrorActionPreference = 'Stop'
$SquintlessVersion = '1.1.0'   # keep in sync with ./VERSION and plugin.json (CI enforces)
$RawBase = 'https://raw.githubusercontent.com/sameer-zahir/squintless/main'

# ---------- pretty output ----------
function Write-Step($m) { Write-Host "`n==> $m" -ForegroundColor Cyan }
function Write-Ok($m)   { Write-Host "    [ok] $m" -ForegroundColor Green }
function Write-Skip($m) { Write-Host "    [skip] $m" -ForegroundColor DarkGray }
function Write-Warn2($m){ Write-Host "    [!] $m" -ForegroundColor Yellow }

Write-Host @"

  ____            _       _   _
 / ___|  __ _ _ _(_)_ _ | |_| | ___ ___ ___
 \___ \ / _` | | | | ' \|  _| |/ -_|_-<_-<
 |___/_/\__, |\_,_|_|_||_|\__|_|\___/__/__/  Easy on the eyes.
            |_|

"@ -ForegroundColor DarkYellow

# ---------- helpers ----------
# Return the content of a config file: prefer a local ./config copy (cloned repo),
# otherwise download it from GitHub raw (one-liner install).
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
function Get-SquintlessFile {
  param([Parameter(Mandatory)][string]$Name)
  $local = Join-Path $ScriptDir "config/$Name"
  if (Test-Path $local) { return Get-Content -Raw -LiteralPath $local }
  return (Invoke-RestMethod -Uri "$RawBase/config/$Name")
}

function Backup-File {
  param([Parameter(Mandatory)][string]$Path)
  if (Test-Path -LiteralPath $Path) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $bak = "$Path.squintless-$stamp.bak"
    Copy-Item -LiteralPath $Path -Destination $bak -Force
    Write-Ok "backed up -> $(Split-Path -Leaf $bak)"
  }
}

# strip // and /* */ comments so ConvertFrom-Json can read JSONC (e.g. WT settings)
function ConvertFrom-Jsonc {
  param([Parameter(Mandatory)][string]$Text)
  $noBlock = [regex]::Replace($Text, '/\*[\s\S]*?\*/', '')
  $noLine  = [regex]::Replace($noBlock, '(?m)^\s*//.*$', '')
  return $noLine | ConvertFrom-Json
}

# Prompt for input without hanging when stdin is redirected (irm|iex piped from a
# file, CI, non-console hosts). Returns $Default immediately if input is redirected
# or the host can't prompt; otherwise the typed answer (or $Default if empty).
function Read-Choice {
  param([Parameter(Mandatory)][string]$Prompt, [string]$Default = '')
  if ([Console]::IsInputRedirected) { return $Default }
  try {
    $r = Read-Host $Prompt
    if ([string]::IsNullOrWhiteSpace($r)) { return $Default } else { return $r }
  } catch { return $Default }
}

# Resolve a working ccstatusline statusLine command across bun / npm-global installs.
# Prefers the bun .exe; else invokes the npm-global JS entry via node (robust on
# Windows); else a PATH-resolved shim. Returns $null if none is found.
function Resolve-CcstatuslineCommand {
  $bun = "$env:USERPROFILE\.bun\bin\ccstatusline.exe"
  if (Test-Path $bun) { return '"' + ($bun -replace '\\', '/') + '"' }
  if (Get-Command npm -ErrorAction SilentlyContinue) {
    try {
      $root = (npm root -g 2>$null)
      if ($root) {
        $entry = Join-Path $root.Trim() 'ccstatusline\dist\ccstatusline.js'
        if (Test-Path $entry) { return 'node "' + ($entry -replace '\\', '/') + '"' }
      }
    } catch { $null = $_ }
  }
  $c = Get-Command ccstatusline -ErrorAction SilentlyContinue
  if ($c -and $c.Source) { return '"' + ($c.Source -replace '\\', '/') + '"' }
  return $null
}

# Insert or replace the marker-delimited Squintless block in profile text. Idempotent:
# re-running replaces the existing block in place rather than appending a duplicate.
function Merge-SquintlessBlock {
  param([AllowEmptyString()][string]$Current = '', [Parameter(Mandatory)][string]$Snippet)
  $startMarker = '# >>> squintless >>>'
  $endMarker   = '# <<< squintless <<<'
  $si = $Current.IndexOf($startMarker)
  $ei = $Current.IndexOf($endMarker)
  if ($si -ge 0 -and $ei -gt $si) {
    $before = $Current.Substring(0, $si)
    $after  = $Current.Substring($ei + $endMarker.Length)
    return ($before.TrimEnd() + "`n`n" + $Snippet.Trim() + "`n" + $after).TrimEnd() + "`n"
  }
  $sep = if ($Current.TrimEnd().Length -gt 0) { "`n`n" } else { '' }
  return $Current.TrimEnd() + $sep + $Snippet.Trim() + "`n"
}

# ---------- uninstall path ----------
if ($Uninstall) {
  Write-Step 'Uninstalling Squintless'
  $schemeNames = @('Squintless (Gruvbox Light)', 'Squintless (Tokyo Night Moon)')

  # 1. Remove the marker-delimited block from the PowerShell profile.
  $profilePath = $PROFILE.CurrentUserCurrentHost
  if (Test-Path -LiteralPath $profilePath) {
    $cur = Get-Content -Raw -LiteralPath $profilePath
    if ([string]::IsNullOrEmpty($cur)) { $cur = '' }
    $s = $cur.IndexOf('# >>> squintless >>>'); $e = $cur.IndexOf('# <<< squintless <<<')
    if ($s -ge 0 -and $e -gt $s) {
      Backup-File $profilePath
      $new = ($cur.Substring(0, $s).TrimEnd() + "`n" + $cur.Substring($e + '# <<< squintless <<<'.Length).TrimStart()).Trim()
      Set-Content -LiteralPath $profilePath -Value $(if ($new) { "$new`n" } else { '' }) -Encoding utf8
      Write-Ok 'removed Squintless block from $PROFILE'
    } else { Write-Skip 'no Squintless block found in $PROFILE' }
  }

  # 2. Remove the WT color scheme + unset profiles.defaults.colorScheme if it is ours.
  $wtPath = @(
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",
    "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
  ) | Where-Object { Test-Path $_ } | Select-Object -First 1
  if ($wtPath) {
    try {
      $wt = ConvertFrom-Jsonc (Get-Content -Raw -LiteralPath $wtPath)
      Backup-File $wtPath
      if ($wt.schemes) { $wt.schemes = @($wt.schemes | Where-Object { $_.name -notin $schemeNames }) }
      if ($wt.profiles -and $wt.profiles.defaults -and $wt.profiles.defaults.colorScheme -in $schemeNames) {
        $wt.profiles.defaults.PSObject.Properties.Remove('colorScheme') | Out-Null
      }
      ($wt | ConvertTo-Json -Depth 32) | Set-Content -LiteralPath $wtPath -Encoding utf8
      Write-Ok 'removed color scheme from Windows Terminal'
    } catch { Write-Warn2 'couldn''t edit settings.json - remove the Squintless scheme(s) manually.' }
  }

  # 3. Unset the git-delta config we added (other ~/.gitconfig settings untouched).
  if (Get-Command git -ErrorAction SilentlyContinue) {
    foreach ($k in 'core.pager','interactive.diffFilter','delta.navigate','delta.line-numbers','delta.light','delta.dark','delta.syntax-theme','merge.conflictStyle') {
      git config --global --unset $k 2>$null
    }
    Write-Ok 'unset git-delta config'
  }

  # 4. Remove theme files we placed (either variant).
  foreach ($t in 'squintless.omp.json', 'squintless.dark.omp.json') {
    $ompTarget = "$env:USERPROFILE\.config\ohmyposh\$t"
    if (Test-Path $ompTarget) { Remove-Item -LiteralPath $ompTarget -Force; Write-Ok "removed oh-my-posh theme ($t)" }
  }

  # 5. Remove the Windows Terminal scheme fragment (non-destructive delivery).
  $wtFragDir = "$env:LOCALAPPDATA\Microsoft\Windows Terminal\Fragments\squintless"
  if (Test-Path $wtFragDir) { Remove-Item -LiteralPath $wtFragDir -Recurse -Force; Write-Ok 'removed Windows Terminal scheme fragment' }

  # 6. Revert the Claude Code statusline we set (leave theme as-is; remove our ccstatusline config).
  $claudePath = "$env:USERPROFILE\.claude\settings.json"
  if (Test-Path $claudePath) {
    try {
      $cc = Get-Content -Raw -LiteralPath $claudePath | ConvertFrom-Json
      if ($cc.PSObject.Properties.Name -contains 'statusLine' -and "$($cc.statusLine.command)" -match 'ccstatusline') {
        Backup-File $claudePath
        $cc.PSObject.Properties.Remove('statusLine') | Out-Null
        ($cc | ConvertTo-Json -Depth 32) | Set-Content -LiteralPath $claudePath -Encoding utf8
        Write-Ok 'reverted Claude statusLine (theme left as-is)'
      }
    } catch { Write-Warn2 'couldn''t edit ~/.claude/settings.json - revert statusLine manually.' }
  }
  $ccCfg = "$env:USERPROFILE\.config\ccstatusline\settings.json"
  if (Test-Path $ccCfg) { Backup-File $ccCfg; Remove-Item -LiteralPath $ccCfg -Force; Write-Ok 'removed ccstatusline config' }

  Write-Host "`n==> Squintless uninstalled." -ForegroundColor Green
  Write-Host @"
    winget-installed tools (oh-my-posh, delta, zoxide, eza, bat, lazygit, bun) were left in place.
    Remove any you don't want with: winget uninstall --id <id>
    Note: -WithTerminalDefaults font/render tweaks (and any values they overwrote) are reverted
    only by restoring the newest settings.json.squintless-*.bak next to your Windows Terminal settings.
    Backups (*.squintless-*.bak) remain next to every edited file - restore one to fully revert.
"@ -ForegroundColor DarkGray
  return
}

# ---------- variant: light (Gruvbox) or dark (Tokyo Night Moon) ----------
if ($Dark -and $Light) { Write-Warn2 'both -Dark and -Light supplied - using dark.'; $Light = $false }
if     ($Dark)  { $variant = 'dark' }
elseif ($Light) { $variant = 'light' }
else {
  if (-not [Console]::IsInputRedirected) {
    Write-Host "`n  Which Squintless palette?" -ForegroundColor Cyan
    Write-Host '    [L] Light - Gruvbox light, soft #F2E5BC (the default)' -ForegroundColor DarkGray
    Write-Host '    [D] Dark  - Tokyo Night Moon, deep #222436' -ForegroundColor DarkGray
  }
  $ans = Read-Choice '  Choose (L/D)' 'light'
  $variant = if ($ans -match '^(d|dark)$') { 'dark' } else { 'light' }
}

$V = if ($variant -eq 'dark') {
  @{
    Label        = 'Tokyo Night Moon (dark)'
    SchemeFile   = 'windows-terminal.scheme.dark.json'
    DefaultsFile = 'windows-terminal.defaults.dark.json'
    OmpFile      = 'squintless.dark.omp.json'
    OmpTarget    = 'squintless.dark.omp.json'
    ProfileFile  = 'powershell-profile.dark.snippet.ps1'
    DeltaLight   = $false
    SyntaxTheme  = 'TwoDark'
    ClaudeTheme  = 'dark'
  }
} else {
  @{
    Label        = 'Gruvbox Light'
    SchemeFile   = 'windows-terminal.scheme.json'
    DefaultsFile = 'windows-terminal.defaults.json'
    OmpFile      = 'squintless.omp.json'
    OmpTarget    = 'squintless.omp.json'
    ProfileFile  = 'powershell-profile.snippet.ps1'
    DeltaLight   = $true
    SyntaxTheme  = 'gruvbox-light'
    ClaudeTheme  = 'light'
  }
}
Write-Host "  Variant: $($V.Label)" -ForegroundColor DarkYellow

# ---------- 1. dependencies ----------
$deps = @(
  @{ Name = 'oh-my-posh'; Id = 'JanDeDobbeleer.OhMyPosh'; Cmd = 'oh-my-posh' }
  @{ Name = 'git-delta';  Id = 'dandavison.delta';        Cmd = 'delta' }
  @{ Name = 'zoxide';     Id = 'ajeetdsouza.zoxide';      Cmd = 'zoxide' }
  @{ Name = 'eza';        Id = 'eza-community.eza';        Cmd = 'eza' }
  @{ Name = 'bat';        Id = 'sharkdp.bat';             Cmd = 'bat' }
  @{ Name = 'lazygit';    Id = 'jesseduffield.lazygit';   Cmd = 'lazygit' }
  @{ Name = 'bun';        Id = 'Oven-sh.Bun';             Cmd = 'bun' }
)

if ($SkipDeps) {
  Write-Step 'Dependencies (skipped via -SkipDeps)'
} else {
  Write-Step 'Installing dependencies (winget)'
  if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Warn2 'winget not found. Install "App Installer" from the Microsoft Store, then re-run. Skipping deps.'
  } else {
    foreach ($d in $deps) {
      if (Get-Command $d.Cmd -ErrorAction SilentlyContinue) {
        Write-Skip "$($d.Name) already installed"
      } else {
        Write-Host "    installing $($d.Name)..." -ForegroundColor DarkGray
        winget install --id $d.Id -e --source winget --accept-package-agreements --accept-source-agreements --disable-interactivity | Out-Null
        $code = $LASTEXITCODE
        # winget updates the machine/user PATH, not this live session - APPEND any new entries
        # (overwriting $env:Path would drop process-only shims like fnm/nvm node).
        foreach ($p in ((([Environment]::GetEnvironmentVariable('Path', 'Machine')), ([Environment]::GetEnvironmentVariable('Path', 'User')) -join ';') -split ';')) {
          if ($p -and (($env:Path -split ';') -notcontains $p)) { $env:Path += ";$p" }
        }
        if ($code -eq 0 -and (Get-Command $d.Cmd -ErrorAction SilentlyContinue)) { Write-Ok "$($d.Name)" }
        elseif ($code -eq 0) { Write-Warn2 "$($d.Name): winget reported success but '$($d.Cmd)' isn't on PATH yet - open a new shell, or install it manually." }
        else { Write-Warn2 "winget couldn't install $($d.Name) (exit $code) - install it manually later." }
      }
    }
  }
}

# Font: install JetBrains Mono Nerd Font via oh-my-posh (pulls from the official Nerd Fonts releases)
Write-Step 'JetBrains Mono Nerd Font'
if ($SkipDeps) {
  Write-Skip 'skipped via -SkipDeps'
} elseif (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
  $haveFont = $false
  try { $haveFont = @(Get-ChildItem "$env:LOCALAPPDATA\Microsoft\Windows\Fonts","$env:WINDIR\Fonts" -Filter '*JetBrainsMono*' -ErrorAction SilentlyContinue).Count -gt 0 } catch { $null = $_ }
  if ($haveFont) { Write-Skip 'JetBrainsMono Nerd Font already present' }
  else {
    try { oh-my-posh font install JetBrainsMono | Out-Null; Write-Ok 'installed JetBrainsMono Nerd Font' }
    catch { Write-Warn2 'font auto-install failed - grab it from https://github.com/ryanoasis/nerd-fonts/releases (JetBrainsMono.zip)' }
  }
} else {
  Write-Warn2 'oh-my-posh not available to install the font - get JetBrainsMono.zip from https://github.com/ryanoasis/nerd-fonts/releases'
}

# ---------- 2. Windows Terminal color scheme (delivered as a Fragment) ----------
Write-Step 'Windows Terminal color scheme'
$scheme = Get-SquintlessFile $V.SchemeFile | ConvertFrom-Json

# Preferred path: drop the scheme into a Windows Terminal Fragment. This never rewrites
# the user's settings.json schemes, so their JSONC comments survive and uninstall is a
# clean directory delete. (Fragments can't set the global default scheme, so activation
# below still writes one colorScheme line to settings.json.)
$wtFragDir = "$env:LOCALAPPDATA\Microsoft\Windows Terminal\Fragments\squintless"
$fragWritten = $false
try {
  New-Item -ItemType Directory -Force -Path $wtFragDir | Out-Null
  $fragName = if ($variant -eq 'dark') { 'dark.json' } else { 'light.json' }
  $fragment = [pscustomobject]@{ '$schema' = 'https://aka.ms/terminal-profiles-schema'; schemes = @($scheme) }
  ($fragment | ConvertTo-Json -Depth 32) | Set-Content -LiteralPath (Join-Path $wtFragDir $fragName) -Encoding utf8
  Write-Ok "scheme fragment -> Fragments\squintless\$fragName (settings.json schemes untouched)"
  $fragWritten = $true
} catch {
  Write-Warn2 "couldn't write the WT fragment ($($_.Exception.Message)) - will embed in settings.json instead."
}

# Activate the scheme (and migrate away any legacy embedded copy). Backed up first.
$wtCandidates = @(
  "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
  "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",
  "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
)
$wtPath = $wtCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $wtPath) {
  Write-Warn2 'Windows Terminal settings.json not found. Open Windows Terminal once, then re-run (the fragment is already in place if it wrote above).'
} else {
  try {
    $wt = ConvertFrom-Jsonc (Get-Content -Raw -LiteralPath $wtPath)
    Backup-File $wtPath
    if (-not $wt.profiles)          { $wt | Add-Member -NotePropertyName profiles -NotePropertyValue ([pscustomobject]@{}) -Force }
    if (-not $wt.profiles.defaults) { $wt.profiles | Add-Member -NotePropertyName defaults -NotePropertyValue ([pscustomobject]@{}) -Force }
    if ($fragWritten) {
      # Fragment owns the scheme now; drop any legacy embedded copy of the same name.
      if ($wt.schemes) { $wt.schemes = @($wt.schemes | Where-Object { $_.name -ne $scheme.name }) }
    } else {
      # Fallback: embed the scheme directly in settings.json (previous behavior).
      if (-not $wt.schemes) { $wt | Add-Member -NotePropertyName schemes -NotePropertyValue @() -Force }
      $wt.schemes = @(@($wt.schemes | Where-Object { $_.name -ne $scheme.name }) + $scheme)
    }
    $wt.profiles.defaults | Add-Member -NotePropertyName colorScheme -NotePropertyValue $scheme.name -Force
    Write-Ok "set `"$($scheme.name)`" as the active color scheme"
    if ($WithTerminalDefaults) {
      # Also apply the variant's font / cellHeight / cursor / antialiasing settings.
      $defaults = Get-SquintlessFile $V.DefaultsFile | ConvertFrom-Json
      foreach ($p in $defaults.PSObject.Properties) {
        $wt.profiles.defaults | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value -Force
      }
      Write-Ok 'applied font / render tuning to profiles.defaults'
    } else {
      Write-Skip 'font tuning skipped - re-run with -WithTerminalDefaults for the OLED-tuned font (size/cellHeight)'
    }
    ($wt | ConvertTo-Json -Depth 32) | Set-Content -LiteralPath $wtPath -Encoding utf8
    Write-Ok "activated in $(Split-Path -Leaf $wtPath)"
  } catch {
    Write-Warn2 "Couldn't edit settings.json ($($_.Exception.Message)). The fragment is installed - pick `"$($scheme.name)`" in Windows Terminal settings."
  }
}

# ---------- 3. oh-my-posh theme ----------
Write-Step 'oh-my-posh prompt theme'
$ompDir = "$env:USERPROFILE\.config\ohmyposh"
New-Item -ItemType Directory -Force -Path $ompDir | Out-Null
$ompTarget = Join-Path $ompDir $V.OmpTarget
if (Test-Path $ompTarget) { Backup-File $ompTarget }
Get-SquintlessFile $V.OmpFile | Set-Content -LiteralPath $ompTarget -Encoding utf8
Write-Ok "theme -> $ompTarget"

# ---------- 4. PowerShell profile ----------
Write-Step 'PowerShell profile'
$profilePath = $PROFILE.CurrentUserCurrentHost
$profileDir = Split-Path -Parent $profilePath
New-Item -ItemType Directory -Force -Path $profileDir | Out-Null
if (-not (Test-Path $profilePath)) { New-Item -ItemType File -Path $profilePath | Out-Null }
$snippet = Get-SquintlessFile $V.ProfileFile
$current = Get-Content -Raw -LiteralPath $profilePath
if ([string]::IsNullOrEmpty($current)) { $current = '' }
Backup-File $profilePath
$hadBlock = $current.Contains('# >>> squintless >>>')
$updated = Merge-SquintlessBlock -Current $current -Snippet $snippet
Set-Content -LiteralPath $profilePath -Value $updated -Encoding utf8
if ($hadBlock) { Write-Ok 'updated existing Squintless block' } else { Write-Ok 'appended Squintless block' }

# ---------- 5. git-delta ----------
Write-Step "git-delta ($($V.SyntaxTheme))"
if (Get-Command git -ErrorAction SilentlyContinue) {
  Backup-File "$env:USERPROFILE\.gitconfig"   # honour the "backs up every file it touches" promise
  git config --global core.pager delta
  git config --global interactive.diffFilter 'delta --color-only'
  git config --global delta.navigate true
  git config --global delta.line-numbers true
  if ($V.DeltaLight) {
    git config --global delta.light true
    git config --global --unset delta.dark 2>$null
  } else {
    git config --global delta.dark true
    git config --global --unset delta.light 2>$null
  }
  git config --global delta.syntax-theme $V.SyntaxTheme
  git config --global merge.conflictStyle zdiff3
  Write-Ok 'configured delta in ~/.gitconfig'
} else {
  Write-Warn2 'git not found - skipping delta config'
}

# ---------- 6. Claude Code (optional) ----------
$doClaude = $WithClaude
if (-not $doClaude) {
  $ans = Read-Choice "Apply Claude Code $($V.ClaudeTheme) theme + ccstatusline statusline? (y/N)" 'n'
  $doClaude = ($ans -match '^(y|yes)$')
}
if ($doClaude) {
  Write-Step "Claude Code ($($V.ClaudeTheme) theme + statusline)"
  # ccstatusline binary
  if (Get-Command bun -ErrorAction SilentlyContinue) { bun install -g ccstatusline | Out-Null; Write-Ok 'ccstatusline (bun)' }
  elseif (Get-Command npm -ErrorAction SilentlyContinue) { npm install -g ccstatusline | Out-Null; Write-Ok 'ccstatusline (npm)' }
  else { Write-Warn2 'no bun/npm - install ccstatusline yourself: npm i -g ccstatusline' }

  $ccDir = "$env:USERPROFILE\.config\ccstatusline"
  New-Item -ItemType Directory -Force -Path $ccDir | Out-Null
  $ccTarget = Join-Path $ccDir 'settings.json'
  if (Test-Path $ccTarget) { Backup-File $ccTarget }
  Get-SquintlessFile 'ccstatusline.settings.json' | Set-Content -LiteralPath $ccTarget -Encoding utf8
  Write-Ok "ccstatusline config -> $ccTarget"

  $claudePath = "$env:USERPROFILE\.claude\settings.json"
  if (Test-Path $claudePath) {
    try {
      $cc = Get-Content -Raw -LiteralPath $claudePath | ConvertFrom-Json
      Backup-File $claudePath
      $cc | Add-Member -NotePropertyName theme -NotePropertyValue $V.ClaudeTheme -Force
      $ccCmd = Resolve-CcstatuslineCommand
      if ($ccCmd) {
        $sl = [pscustomobject]@{ type = 'command'; command = $ccCmd; padding = 0 }
        $cc | Add-Member -NotePropertyName statusLine -NotePropertyValue $sl -Force
        ($cc | ConvertTo-Json -Depth 32) | Set-Content -LiteralPath $claudePath -Encoding utf8
        Write-Ok "set Claude theme:$($V.ClaudeTheme) + statusLine (other settings untouched)"
      } else {
        ($cc | ConvertTo-Json -Depth 32) | Set-Content -LiteralPath $claudePath -Encoding utf8
        Write-Warn2 "set theme:$($V.ClaudeTheme), but the ccstatusline binary wasn't found - run 'npm i -g ccstatusline' and set statusLine manually."
      }
    } catch { Write-Warn2 "Couldn't edit ~/.claude/settings.json safely - set theme:$($V.ClaudeTheme) + statusLine manually." }
  } else {
    Write-Warn2 '~/.claude/settings.json not found - run Claude Code once, then re-run with -WithClaude.'
  }
}

# ---------- done ----------
Write-Host "`n==> Squintless v$SquintlessVersion installed ($($V.Label))." -ForegroundColor Green
Write-Host @"
    Next:
      1. Close and reopen Windows Terminal (the scheme/font apply on a fresh window).
      2. The Squintless color scheme is applied automatically. For the full look, set your
         font to a JetBrains Mono Nerd Font (or re-run with -WithTerminalDefaults to do it for you).
      3. -WithTerminalDefaults: the light defaults target a HiDPI/OLED laptop (grayscale AA);
         the dark defaults use ClearType at size 15. Tweak antialiasingMode / size for your panel - see the README.

    Backups (*.squintless-*.bak) sit next to every file that was changed.
    Loved it? Star the repo - it helps a lot: https://github.com/sameer-zahir/squintless
"@ -ForegroundColor DarkGray
