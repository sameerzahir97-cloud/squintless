#Requires -Version 7.0
<#
.SYNOPSIS
  Squintless - easy-on-the-eyes Gruvbox-light terminal + Claude Code setup.
  https://github.com/sameerzahir97-cloud/squintless

.DESCRIPTION
  Installs the tools and drops in the configs that make up Squintless:
    - Gruvbox-light Windows Terminal color scheme (+ optional font/render defaults)
    - JetBrains Mono Nerd Font
    - Themed PowerShell (PSReadLine colors + oh-my-posh prompt + zoxide/eza/bat/lazygit)
    - git-delta with the gruvbox-light syntax theme
    - (optional) Claude Code light theme + ccstatusline statusline

  Safe by design: backs up every file it touches, is idempotent (re-running won't
  duplicate anything), and only wires up tools that are present.

.PARAMETER WithTerminalDefaults
  Also apply the font / cellHeight / cursor / grayscale-AA defaults to Windows
  Terminal's profiles.defaults (tuned for a HiDPI/OLED display - see README).

.PARAMETER WithClaude
  Also set Claude Code theme:light and the ccstatusline statusline.

.PARAMETER SkipDeps
  Don't install any winget/bun packages; just place the configs.

.EXAMPLE
  irm https://raw.githubusercontent.com/sameerzahir97-cloud/squintless/main/install.ps1 | iex

.EXAMPLE
  .\install.ps1 -WithTerminalDefaults -WithClaude
#>
[CmdletBinding()]
param(
  [switch]$WithTerminalDefaults,
  [switch]$WithClaude,
  [switch]$SkipDeps
)

$ErrorActionPreference = 'Stop'
$RawBase = 'https://raw.githubusercontent.com/sameerzahir97-cloud/squintless/main'

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
        if ($LASTEXITCODE -eq 0) { Write-Ok "$($d.Name)" } else { Write-Warn2 "winget couldn't install $($d.Name) (exit $LASTEXITCODE) - install it manually later." }
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
  try { $haveFont = @(Get-ChildItem "$env:LOCALAPPDATA\Microsoft\Windows\Fonts","$env:WINDIR\Fonts" -Filter '*JetBrainsMono*' -ErrorAction SilentlyContinue).Count -gt 0 } catch {}
  if ($haveFont) { Write-Skip 'JetBrainsMono Nerd Font already present' }
  else {
    try { oh-my-posh font install JetBrainsMono | Out-Null; Write-Ok 'installed JetBrainsMono Nerd Font' }
    catch { Write-Warn2 'font auto-install failed - grab it from https://github.com/ryanoasis/nerd-fonts/releases (JetBrainsMono.zip)' }
  }
} else {
  Write-Warn2 'oh-my-posh not available to install the font - get JetBrainsMono.zip from https://github.com/ryanoasis/nerd-fonts/releases'
}

# ---------- 2. Windows Terminal color scheme ----------
Write-Step 'Windows Terminal color scheme'
$wtCandidates = @(
  "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
  "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",
  "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
)
$wtPath = $wtCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $wtPath) {
  Write-Warn2 'Windows Terminal settings.json not found. Open Windows Terminal once, then re-run (or add the scheme from config/windows-terminal.scheme.json manually).'
} else {
  $scheme = Get-SquintlessFile 'windows-terminal.scheme.json' | ConvertFrom-Json
  try {
    $raw = Get-Content -Raw -LiteralPath $wtPath
    $wt  = ConvertFrom-Jsonc $raw
    Backup-File $wtPath
    if (-not $wt.schemes) { $wt | Add-Member -NotePropertyName schemes -NotePropertyValue @() -Force }
    $kept = @($wt.schemes | Where-Object { $_.name -ne $scheme.name })
    $wt.schemes = @($kept + $scheme)
    if ($WithTerminalDefaults) {
      $defaults = Get-SquintlessFile 'windows-terminal.defaults.json' | ConvertFrom-Json
      if (-not $wt.profiles)          { $wt | Add-Member -NotePropertyName profiles -NotePropertyValue ([pscustomobject]@{}) -Force }
      if (-not $wt.profiles.defaults) { $wt.profiles | Add-Member -NotePropertyName defaults -NotePropertyValue ([pscustomobject]@{}) -Force }
      foreach ($p in $defaults.PSObject.Properties) {
        $wt.profiles.defaults | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value -Force
      }
      Write-Ok 'applied font / render defaults to profiles.defaults'
    } else {
      Write-Skip 'font/render defaults not applied (re-run with -WithTerminalDefaults). Set the scheme yourself: Settings > profile > Appearance > Color scheme > "Squintless (Gruvbox Light)"'
    }
    ($wt | ConvertTo-Json -Depth 32) | Set-Content -LiteralPath $wtPath -Encoding utf8
    Write-Ok "scheme installed -> $(Split-Path -Leaf $wtPath) (note: re-saving strips // comments; backup made)"
  } catch {
    Write-Warn2 "Couldn't safely edit settings.json ($($_.Exception.Message)). Add config/windows-terminal.scheme.json to your schemes manually - nothing was changed."
  }
}

# ---------- 3. oh-my-posh theme ----------
Write-Step 'oh-my-posh prompt theme'
$ompDir = "$env:USERPROFILE\.config\ohmyposh"
New-Item -ItemType Directory -Force -Path $ompDir | Out-Null
$ompTarget = Join-Path $ompDir 'squintless.omp.json'
if (Test-Path $ompTarget) { Backup-File $ompTarget }
Get-SquintlessFile 'squintless.omp.json' | Set-Content -LiteralPath $ompTarget -Encoding utf8
Write-Ok "theme -> $ompTarget"

# ---------- 4. PowerShell profile ----------
Write-Step 'PowerShell profile'
$profilePath = $PROFILE.CurrentUserCurrentHost
$profileDir = Split-Path -Parent $profilePath
New-Item -ItemType Directory -Force -Path $profileDir | Out-Null
if (-not (Test-Path $profilePath)) { New-Item -ItemType File -Path $profilePath | Out-Null }
$snippet = Get-SquintlessFile 'powershell-profile.snippet.ps1'
$current = Get-Content -Raw -LiteralPath $profilePath
if ([string]::IsNullOrEmpty($current)) { $current = '' }
Backup-File $profilePath
$startMarker = '# >>> squintless >>>'
$endMarker   = '# <<< squintless <<<'
$si = $current.IndexOf($startMarker)
$ei = $current.IndexOf($endMarker)
if ($si -ge 0 -and $ei -gt $si) {
  $before = $current.Substring(0, $si)
  $after  = $current.Substring($ei + $endMarker.Length)
  $updated = ($before.TrimEnd() + "`n`n" + $snippet.Trim() + "`n" + $after).TrimEnd() + "`n"
  Write-Ok 'updated existing Squintless block'
} else {
  $sep = if ($current.TrimEnd().Length -gt 0) { "`n`n" } else { '' }
  $updated = $current.TrimEnd() + $sep + $snippet.Trim() + "`n"
  Write-Ok 'appended Squintless block'
}
Set-Content -LiteralPath $profilePath -Value $updated -Encoding utf8

# ---------- 5. git-delta ----------
Write-Step 'git-delta (gruvbox-light)'
if (Get-Command git -ErrorAction SilentlyContinue) {
  Backup-File "$env:USERPROFILE\.gitconfig"   # honour the "backs up every file it touches" promise
  git config --global core.pager delta
  git config --global interactive.diffFilter 'delta --color-only'
  git config --global delta.navigate true
  git config --global delta.line-numbers true
  git config --global delta.light true
  git config --global delta.syntax-theme gruvbox-light
  git config --global merge.conflictStyle zdiff3
  Write-Ok 'configured delta in ~/.gitconfig'
} else {
  Write-Warn2 'git not found - skipping delta config'
}

# ---------- 6. Claude Code (optional) ----------
$doClaude = $WithClaude
if (-not $doClaude -and ([Environment]::UserInteractive)) {
  $ans = Read-Host 'Apply Claude Code light theme + ccstatusline statusline? (y/N)'
  $doClaude = ($ans -match '^(y|yes)$')
}
if ($doClaude) {
  Write-Step 'Claude Code (light theme + statusline)'
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
      $cc | Add-Member -NotePropertyName theme -NotePropertyValue 'light' -Force
      $ccBin = "$env:USERPROFILE\.bun\bin\ccstatusline.exe" -replace '\\','/'
      $sl = [pscustomobject]@{ type = 'command'; command = $ccBin; padding = 0 }
      $cc | Add-Member -NotePropertyName statusLine -NotePropertyValue $sl -Force
      ($cc | ConvertTo-Json -Depth 32) | Set-Content -LiteralPath $claudePath -Encoding utf8
      Write-Ok 'set Claude theme:light + statusLine (other settings untouched)'
    } catch { Write-Warn2 "Couldn't edit ~/.claude/settings.json safely - set theme:light + statusLine manually." }
  } else {
    Write-Warn2 '~/.claude/settings.json not found - run Claude Code once, then re-run with -WithClaude.'
  }
}

# ---------- done ----------
Write-Host "`n==> Squintless installed." -ForegroundColor Green
Write-Host @"
    Next:
      1. Close and reopen Windows Terminal (fonts/scheme apply on a fresh window).
      2. If you skipped -WithTerminalDefaults, pick "Squintless (Gruvbox Light)" under
         Settings > your profile > Appearance, and set the font to "JetBrainsMono NFM".
      3. Tuned for a HiDPI/OLED laptop. On a standard LCD, in Windows Terminal set
         antialiasingMode "cleartype", cellHeight ~1.0-1.15, font size 11-12. See the README.

    Backups (*.squintless-*.bak) sit next to every file that was changed.
    Loved it? Star the repo - it helps a lot: https://github.com/sameerzahir97-cloud/squintless
"@ -ForegroundColor DarkGray
