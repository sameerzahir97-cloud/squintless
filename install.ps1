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

.PARAMETER Uninstall
  Reverse what the installer changed (PowerShell profile block, Windows Terminal
  color scheme, git-delta config, theme files). Backs up before editing and leaves
  winget-installed tools in place.

.EXAMPLE
  irm https://raw.githubusercontent.com/sameerzahir97-cloud/squintless/main/install.ps1 | iex

.EXAMPLE
  .\install.ps1 -WithTerminalDefaults -WithClaude

.EXAMPLE
  $s = irm https://raw.githubusercontent.com/sameerzahir97-cloud/squintless/main/install.ps1
  & ([scriptblock]::Create($s)) -Uninstall
#>
[CmdletBinding()]
param(
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
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}

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

# ---------- uninstall path ----------
if ($Uninstall) {
  Write-Step 'Uninstalling Squintless'
  $schemeName = 'Squintless (Gruvbox Light)'

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
      if ($wt.schemes) { $wt.schemes = @($wt.schemes | Where-Object { $_.name -ne $schemeName }) }
      if ($wt.profiles -and $wt.profiles.defaults -and $wt.profiles.defaults.colorScheme -eq $schemeName) {
        $wt.profiles.defaults.PSObject.Properties.Remove('colorScheme') | Out-Null
      }
      ($wt | ConvertTo-Json -Depth 32) | Set-Content -LiteralPath $wtPath -Encoding utf8
      Write-Ok 'removed color scheme from Windows Terminal'
    } catch { Write-Warn2 "couldn't edit settings.json - remove the `"$schemeName`" scheme manually." }
  }

  # 3. Unset the git-delta config we added (other ~/.gitconfig settings untouched).
  if (Get-Command git -ErrorAction SilentlyContinue) {
    foreach ($k in 'core.pager','interactive.diffFilter','delta.navigate','delta.line-numbers','delta.light','delta.syntax-theme','merge.conflictStyle') {
      git config --global --unset $k 2>$null
    }
    Write-Ok 'unset git-delta config'
  }

  # 4. Remove theme files we placed.
  $ompTarget = "$env:USERPROFILE\.config\ohmyposh\squintless.omp.json"
  if (Test-Path $ompTarget) { Remove-Item -LiteralPath $ompTarget -Force; Write-Ok 'removed oh-my-posh theme' }

  Write-Host "`n==> Squintless uninstalled." -ForegroundColor Green
  Write-Host @"
    winget-installed tools (oh-my-posh, delta, zoxide, eza, bat, lazygit, bun) were left in place.
    Remove any you don't want with: winget uninstall --id <id>
    Backups (*.squintless-*.bak) remain next to every edited file - restore one to fully revert.
"@ -ForegroundColor DarkGray
  return
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
    # Always make the scheme active so the basic one-liner is visibly applied.
    # profiles.defaults.colorScheme applies to every profile that doesn't override its
    # own colorScheme (the common case) and is non-destructive - backup made above.
    if (-not $wt.profiles)          { $wt | Add-Member -NotePropertyName profiles -NotePropertyValue ([pscustomobject]@{}) -Force }
    if (-not $wt.profiles.defaults) { $wt.profiles | Add-Member -NotePropertyName defaults -NotePropertyValue ([pscustomobject]@{}) -Force }
    $wt.profiles.defaults | Add-Member -NotePropertyName colorScheme -NotePropertyValue $scheme.name -Force
    Write-Ok "set `"$($scheme.name)`" as the active color scheme"
    if ($WithTerminalDefaults) {
      # Also apply the OLED-tuned font / cellHeight / cursor / grayscale-AA settings.
      $defaults = Get-SquintlessFile 'windows-terminal.defaults.json' | ConvertFrom-Json
      foreach ($p in $defaults.PSObject.Properties) {
        $wt.profiles.defaults | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value -Force
      }
      Write-Ok 'applied OLED font / render tuning to profiles.defaults'
    } else {
      Write-Skip 'font tuning skipped - re-run with -WithTerminalDefaults for the OLED-tuned font (size/cellHeight)'
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
      1. Close and reopen Windows Terminal (the scheme/font apply on a fresh window).
      2. The Squintless color scheme is applied automatically. For the full look, set your
         font to "JetBrainsMono NFM" (or re-run with -WithTerminalDefaults to do it for you).
      3. The -WithTerminalDefaults tuning targets a HiDPI/OLED laptop. On a standard LCD,
         set antialiasingMode "cleartype", cellHeight ~1.0-1.15, font size 11-12. See the README.

    Backups (*.squintless-*.bak) sit next to every file that was changed.
    Loved it? Star the repo - it helps a lot: https://github.com/sameerzahir97-cloud/squintless
"@ -ForegroundColor DarkGray
