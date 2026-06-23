#!/usr/bin/env bash
# Squintless - easy-on-the-eyes terminal + Claude Code setup for macOS & Linux.
# Pick a palette: Gruvbox light (default) or Tokyo Night Moon (dark).
# https://github.com/sameer-zahir/squintless
#
# Mirrors install.ps1: installs the tools, a terminal color scheme, an oh-my-posh
# prompt, git-delta, and (optionally) the Claude Code theme + ccstatusline. Safe by
# design: backs up every file it touches, is idempotent, and only wires up tools
# that are present. bash 3.2-safe (macOS ships bash 3.2).
#
#   curl -fsSL https://raw.githubusercontent.com/sameer-zahir/squintless/main/install.sh | bash
#   ./install.sh --dark --with-terminal-defaults --with-claude
#   ./install.sh --uninstall

set -euo pipefail

SQUINTLESS_VERSION="1.1.0"   # keep in sync with ./VERSION and plugin.json (CI enforces)
RAW_BASE="https://raw.githubusercontent.com/sameer-zahir/squintless/main"
START_MARKER="# >>> squintless >>>"
END_MARKER="# <<< squintless <<<"

# ---------- flags ----------
VARIANT=""              # dark | light | "" (ask)
WITH_CLAUDE=0
SKIP_DEPS=0
UNINSTALL=0
ASSUME_YES=0
TERMINALS=""            # comma-separated explicit list, else auto-detect

# ---------- pretty output ----------
if [ -t 1 ]; then
  C_CYAN=$'\033[36m'; C_GREEN=$'\033[32m'; C_GRAY=$'\033[90m'; C_YELLOW=$'\033[33m'; C_RESET=$'\033[0m'
else
  C_CYAN=""; C_GREEN=""; C_GRAY=""; C_YELLOW=""; C_RESET=""
fi
step() { printf '\n%s==> %s%s\n' "$C_CYAN" "$1" "$C_RESET"; }
ok()   { printf '    %s[ok]%s %s\n' "$C_GREEN" "$C_RESET" "$1"; }
skip() { printf '    %s[skip]%s %s\n' "$C_GRAY" "$C_RESET" "$1"; }
warn() { printf '    %s[!]%s %s\n' "$C_YELLOW" "$C_RESET" "$1"; }

have() { command -v "$1" >/dev/null 2>&1; }

usage() {
  cat <<EOF
Squintless v${SQUINTLESS_VERSION} - easy-on-the-eyes terminal + Claude Code setup.

Usage: install.sh [options]
  --dark | --light          choose the palette (default: ask, or light if non-interactive)
  --with-claude             also set the Claude Code theme + ccstatusline statusline
  --terminal=a,b            theme only these terminals (kitty,wezterm,alacritty,ghostty,iterm2,xresources)
  --skip-deps               don't install packages; just place configs
  --yes                     assume yes / non-interactive
  --uninstall               reverse what the installer changed (tools left in place)
  --version                 print version and exit
  -h, --help                this help
EOF
}

# ---------- arg parsing ----------
for arg in "$@"; do
  case "$arg" in
    --dark) VARIANT="dark" ;;
    --light) VARIANT="light" ;;
    --with-claude) WITH_CLAUDE=1 ;;
    --skip-deps) SKIP_DEPS=1 ;;
    --uninstall) UNINSTALL=1 ;;
    --yes|-y) ASSUME_YES=1 ;;
    --terminal=*) TERMINALS="${arg#*=}" ;;
    --version) printf 'squintless %s\n' "$SQUINTLESS_VERSION"; exit 0 ;;
    -h|--help) usage; exit 0 ;;
    *) warn "unknown option: $arg (try --help)" ;;
  esac
done

# ---------- helpers ----------
# Repo root if running from a clone (so we can read config/ locally), else "".
SCRIPT_DIR=""
_src="${BASH_SOURCE[0]:-}"
if [ -n "$_src" ] && [ -f "$_src" ]; then
  SCRIPT_DIR="$(cd "$(dirname "$_src")" && pwd)"
fi

# get_file <relpath under config/>  -> stdout (local clone preferred, else curl)
get_file() {
  local rel="$1"
  if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/config/$rel" ]; then
    cat "$SCRIPT_DIR/config/$rel"
  else
    curl -fsSL "$RAW_BASE/config/$rel"
  fi
}

backup_file() {
  local path="$1"
  if [ -e "$path" ]; then
    local stamp; stamp="$(date +%Y%m%d-%H%M%S)"
    cp "$path" "$path.squintless-$stamp.bak"
    ok "backed up -> $(basename "$path.squintless-$stamp.bak")"
  fi
}

# Strip the marker-delimited block (inclusive) from stdin.
strip_block() {
  awk -v s="$START_MARKER" -v e="$END_MARKER" '$0==s{skip=1} skip==0{print} $0==e{skip=0}'
}

# merge_block <file>   block content on stdin; idempotently insert/replace it.
merge_block() {
  local file="$1"; local block; block="$(cat)"
  local cur=""; [ -f "$file" ] && cur="$(cat "$file")"
  local stripped; stripped="$(printf '%s\n' "$cur" | strip_block)"
  while [ -n "$stripped" ] && [ -z "${stripped##*$'\n'}" ]; do stripped="${stripped%$'\n'}"; done
  mkdir -p "$(dirname "$file")"
  if [ -n "$stripped" ]; then
    printf '%s\n\n%s\n' "$stripped" "$block" > "$file"
  else
    printf '%s\n' "$block" > "$file"
  fi
}

# remove_block <file>   remove the marker block from a config file (for uninstall).
remove_block() {
  local file="$1"
  [ -f "$file" ] || return 0
  if grep -qF "$START_MARKER" "$file" 2>/dev/null; then
    backup_file "$file"
    local out; out="$(strip_block < "$file")"
    while [ -n "$out" ] && [ -z "${out##*$'\n'}" ]; do out="${out%$'\n'}"; done
    if [ -n "$out" ]; then printf '%s\n' "$out" > "$file"; else : > "$file"; fi
    ok "removed Squintless block from $(basename "$file")"
  fi
}

# Resolve a working ccstatusline statusLine command across bun / npm-global installs.
resolve_cc_command() {
  if [ -x "$HOME/.bun/bin/ccstatusline" ]; then printf '"%s"' "$HOME/.bun/bin/ccstatusline"; return; fi
  if have npm; then
    local root; root="$(npm root -g 2>/dev/null || true)"
    if [ -n "$root" ] && [ -f "$root/ccstatusline/dist/ccstatusline.js" ]; then
      printf 'node "%s"' "$root/ccstatusline/dist/ccstatusline.js"; return
    fi
  fi
  if have ccstatusline; then printf '"%s"' "$(command -v ccstatusline)"; return; fi
  printf ''
}

# Current login shell name (zsh|bash|...).
shell_name() { basename "${SHELL:-bash}"; }

rc_file() {
  case "$(shell_name)" in
    zsh) printf '%s/.zshrc' "$HOME" ;;
    bash)
      # macOS Terminal/iTerm start LOGIN bash, which reads ~/.bash_profile, not ~/.bashrc.
      if [ "$(uname -s)" = "Darwin" ]; then printf '%s/.bash_profile' "$HOME"
      else printf '%s/.bashrc' "$HOME"; fi ;;
    *) printf '%s/.profile' "$HOME" ;;
  esac
}

# ---------- platform detection ----------
OS="$(uname -s)"
MGR=""
if [ "$OS" = "Darwin" ]; then
  MGR="brew"
elif have apt-get; then MGR="apt"
elif have dnf; then MGR="dnf"
elif have pacman; then MGR="pacman"
elif have zypper; then MGR="zypper"
elif have brew; then MGR="brew"
fi

# ---------- banner ----------
printf '%s\n' "$C_YELLOW"
cat <<'BANNER'
  ____            _       _   _
 / ___|  __ _ _ _(_)_ _ | |_| | ___ ___ ___
 \___ \ / _` | | | | ' \|  _| |/ -_|_-<_-<
 |___/_/\__, |\_,_|_|_||_|\__|_|\___/__/__/  Easy on the eyes.
            |_|
BANNER
printf '%s' "$C_RESET"

# ---------- uninstall ----------
if [ "$UNINSTALL" -eq 1 ]; then
  step "Uninstalling Squintless"
  remove_block "$(rc_file)"
  if [ -f "$HOME/.config/squintless/init.sh" ]; then
    rm -f "$HOME/.config/squintless/init.sh"; ok "removed ~/.config/squintless/init.sh"
  fi
  rmdir "$HOME/.config/squintless" 2>/dev/null || true
  for omp in squintless.omp.json squintless.dark.omp.json; do
    [ -f "$HOME/.config/ohmyposh/$omp" ] && { rm -f "$HOME/.config/ohmyposh/$omp"; ok "removed oh-my-posh theme ($omp)"; }
  done
  # terminal config: remove our include lines (kitty/ghostty) + every dropped scheme file
  remove_block "$HOME/.config/kitty/kitty.conf"
  remove_block "$HOME/.config/ghostty/config"
  rm -f "$HOME/.config/kitty/squintless-light.conf" "$HOME/.config/kitty/squintless-dark.conf" 2>/dev/null || true
  rm -f "$HOME/.config/ghostty/themes/squintless-light" "$HOME/.config/ghostty/themes/squintless-dark" 2>/dev/null || true
  rm -f "$HOME/.config/wezterm/colors/Squintless-light.toml" "$HOME/.config/wezterm/colors/Squintless-dark.toml" 2>/dev/null || true
  rm -f "$HOME/.config/alacritty/squintless-light.toml" "$HOME/.config/alacritty/squintless-dark.toml" 2>/dev/null || true
  rm -f "$HOME"/.config/squintless/schemes/* 2>/dev/null || true
  rmdir "$HOME/.config/squintless/schemes" 2>/dev/null || true
  if have git; then
    for k in core.pager interactive.diffFilter delta.navigate delta.line-numbers delta.light delta.dark delta.syntax-theme merge.conflictStyle; do
      git config --global --unset "$k" 2>/dev/null || true
    done
    ok "unset git-delta config"
  fi
  claude="$HOME/.claude/settings.json"
  if [ -f "$claude" ] && grep -q ccstatusline "$claude" 2>/dev/null; then
    backup_file "$claude"
    if have jq; then
      tmp="$(mktemp)"; jq 'del(.statusLine)' "$claude" > "$tmp" && mv "$tmp" "$claude" && ok "reverted Claude statusLine (theme left as-is)"
    elif have python3; then
      python3 - "$claude" <<'PY' && ok "reverted Claude statusLine (theme left as-is)"
import json,sys
p=sys.argv[1]; d=json.load(open(p)); d.pop("statusLine",None); json.dump(d,open(p,"w"),indent=2)
PY
    fi
  fi
  [ -f "$HOME/.config/ccstatusline/settings.json" ] && { backup_file "$HOME/.config/ccstatusline/settings.json"; rm -f "$HOME/.config/ccstatusline/settings.json"; ok "removed ccstatusline config"; }
  printf '\n%s==> Squintless uninstalled.%s\n' "$C_GREEN" "$C_RESET"
  printf '%s    Package-manager tools were left in place. Backups (*.squintless-*.bak) remain next to edited files.%s\n' "$C_GRAY" "$C_RESET"
  exit 0
fi

# ---------- variant resolution ----------
if [ -z "$VARIANT" ]; then
  if [ -t 0 ] && [ "$ASSUME_YES" -eq 0 ]; then
    printf '\n%s  Which Squintless palette?%s\n' "$C_CYAN" "$C_RESET"
    printf '    [L] Light - Gruvbox light, soft #F2E5BC (the default)\n'
    printf '    [D] Dark  - Tokyo Night Moon, deep #222436\n'
    printf '  Choose (L/D): '
    read -r ans || ans=""
    case "$(printf '%s' "$ans" | tr '[:upper:]' '[:lower:]')" in d|dark) VARIANT="dark" ;; *) VARIANT="light" ;; esac
  else
    VARIANT="light"
  fi
fi

set_variant_config() {
  if [ "$VARIANT" = "dark" ]; then
    SCHEME_NAME="Squintless (Tokyo Night Moon)"; OMP_FILE="squintless.dark.omp.json"
    BAT_THEME="TwoDark"; DELTA_POLARITY="dark"; DELTA_THEME="TwoDark"; CLAUDE_THEME="dark"; GEN="dark"; LABEL="Tokyo Night Moon (dark)"
  else
    SCHEME_NAME="Squintless (Gruvbox Light)"; OMP_FILE="squintless.omp.json"
    BAT_THEME="gruvbox-light"; DELTA_POLARITY="light"; DELTA_THEME="gruvbox-light"; CLAUDE_THEME="light"; GEN="light"; LABEL="Gruvbox Light"
  fi
}
set_variant_config
printf '%s  Variant: %s  |  platform: %s/%s%s\n' "$C_YELLOW" "$LABEL" "$OS" "${MGR:-none}" "$C_RESET"

# ---------- 1. dependencies ----------
# Returns the package name for a tool under the active manager (empty = handled specially).
pkg_name() {
  case "$1:$MGR" in
    git-delta:*) echo "git-delta" ;;
    *:*) echo "$1" ;;
  esac
}
install_one() {
  local tool="$1" bin="$2"
  if have "$bin"; then skip "$tool already installed"; return; fi
  case "$tool" in
    oh-my-posh)
      if [ "$MGR" = "brew" ]; then brew install jandedobbeleer/oh-my-posh/oh-my-posh >/dev/null 2>&1 || warn "brew couldn't install oh-my-posh"
      else
        mkdir -p "$HOME/.local/bin"
        curl -fsSL https://ohmyposh.dev/install.sh | bash -s -- -d "$HOME/.local/bin" >/dev/null 2>&1 || warn "oh-my-posh install script failed"
        case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) PATH="$HOME/.local/bin:$PATH" ;; esac
      fi ;;
    *)
      local pkg; pkg="$(pkg_name "$tool")"
      case "$MGR" in
        brew)   brew install "$pkg" >/dev/null 2>&1 || warn "brew couldn't install $tool" ;;
        apt)    sudo apt-get install -y "$pkg" >/dev/null 2>&1 || warn "apt couldn't install $tool (may be unavailable in your repo)" ;;
        dnf)    sudo dnf install -y "$pkg" >/dev/null 2>&1 || warn "dnf couldn't install $tool" ;;
        pacman) sudo pacman -S --noconfirm "$pkg" >/dev/null 2>&1 || warn "pacman couldn't install $tool" ;;
        zypper) sudo zypper install -y "$pkg" >/dev/null 2>&1 || warn "zypper couldn't install $tool" ;;
        *)      warn "no supported package manager - install $tool manually" ;;
      esac ;;
  esac
  if have "$bin"; then ok "$tool"; else warn "$tool not on PATH yet - open a new shell, or install it manually"; fi
}

if [ "$SKIP_DEPS" -eq 1 ]; then
  step "Dependencies (skipped via --skip-deps)"
else
  step "Installing dependencies ($MGR)"
  if [ -z "$MGR" ]; then
    warn "no supported package manager found (brew/apt/dnf/pacman/zypper) - skipping deps"
  else
    install_one oh-my-posh oh-my-posh
    install_one git-delta delta
    install_one zoxide zoxide
    install_one eza eza
    install_one bat bat
    install_one lazygit lazygit
  fi
fi

# Font
step "JetBrains Mono Nerd Font"
if [ "$SKIP_DEPS" -eq 1 ]; then
  skip "skipped via --skip-deps"
elif [ "$MGR" = "brew" ]; then
  if brew install --cask font-jetbrains-mono-nerd-font >/dev/null 2>&1; then ok "JetBrainsMono Nerd Font (brew cask)"; else warn "install JetBrainsMono Nerd Font manually (brew cask font-jetbrains-mono-nerd-font)"; fi
elif have oh-my-posh; then
  if oh-my-posh font install JetBrainsMono >/dev/null 2>&1; then ok "installed JetBrainsMono Nerd Font"; else warn "font install failed - grab JetBrainsMono.zip from nerd-fonts releases"; fi
else
  warn "oh-my-posh not available to install the font - get JetBrainsMono.zip from nerd-fonts releases"
fi

# ---------- 2. shell layer (sourced init + marker block) ----------
step "Shell prompt + tools"
SQDIR="$HOME/.config/squintless"
mkdir -p "$SQDIR" "$HOME/.config/ohmyposh"
backup_file "$HOME/.config/ohmyposh/$OMP_FILE"
get_file "$OMP_FILE" > "$HOME/.config/ohmyposh/$OMP_FILE"
ok "oh-my-posh theme -> ~/.config/ohmyposh/$OMP_FILE"

SHELL_ID="$(shell_name)"; [ "$SHELL_ID" = "zsh" ] || SHELL_ID="bash"
cat > "$SQDIR/init.sh" <<EOF
# Squintless shell init ($LABEL) - sourced from your shell rc. Safe to read.
case ":\$PATH:" in *":\$HOME/.local/bin:"*) ;; *) [ -d "\$HOME/.local/bin" ] && PATH="\$HOME/.local/bin:\$PATH" ;; esac
if command -v oh-my-posh >/dev/null 2>&1; then
  eval "\$(oh-my-posh init $SHELL_ID --config "\$HOME/.config/ohmyposh/$OMP_FILE")"
fi
if command -v zoxide >/dev/null 2>&1; then eval "\$(zoxide init $SHELL_ID)"; fi
if command -v eza >/dev/null 2>&1; then
  ll() { eza -la --git --icons --group-directories-first "\$@"; }
  lt() { eza --tree --level=2 --icons --git-ignore "\$@"; }
fi
if command -v bat >/dev/null 2>&1; then export BAT_THEME="$BAT_THEME"; fi
if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
  alias bat=batcat; export BAT_THEME="$BAT_THEME"
fi
if command -v lazygit >/dev/null 2>&1; then alias lg=lazygit; fi
EOF
ok "wrote $SQDIR/init.sh"

RC="$(rc_file)"
backup_file "$RC"
printf '%s\n%s\n%s\n' "$START_MARKER" "[ -f \"\$HOME/.config/squintless/init.sh\" ] && . \"\$HOME/.config/squintless/init.sh\"" "$END_MARKER" | merge_block "$RC"
ok "wired Squintless into $(basename "$RC")"

# ---------- 3. git-delta ----------
step "git-delta ($DELTA_THEME)"
if have git; then
  backup_file "$HOME/.gitconfig"
  git config --global core.pager delta
  git config --global interactive.diffFilter 'delta --color-only'
  git config --global delta.navigate true
  git config --global delta.line-numbers true
  if [ "$DELTA_POLARITY" = "light" ]; then git config --global delta.light true; git config --global --unset delta.dark 2>/dev/null || true
  else git config --global delta.dark true; git config --global --unset delta.light 2>/dev/null || true; fi
  git config --global delta.syntax-theme "$DELTA_THEME"
  git config --global merge.conflictStyle zdiff3
  ok "configured delta in ~/.gitconfig"
else
  warn "git not found - skipping delta config"
fi

# ---------- 4. terminal color scheme ----------
step "Terminal color scheme"
add_terminal_include() {  # <config-file> <include-line>
  local file="$1" line="$2"
  printf '%s\n%s\n%s\n' "$START_MARKER" "$line" "$END_MARKER" | merge_block "$file"
}
want_terminal() {  # returns 0 if terminal $1 is selected (explicit list or auto-detected)
  local t="$1"
  if [ -n "$TERMINALS" ]; then case ",$TERMINALS," in *",$t,"*) return 0 ;; *) return 1 ;; esac; fi
  case "$t" in
    kitty)     [ -d "$HOME/.config/kitty" ] || have kitty ;;
    wezterm)   [ -d "$HOME/.config/wezterm" ] || have wezterm ;;
    alacritty) [ -d "$HOME/.config/alacritty" ] || have alacritty ;;
    ghostty)   [ -d "$HOME/.config/ghostty" ] || have ghostty ;;
    iterm2)    [ "$OS" = "Darwin" ] ;;
    *) return 1 ;;
  esac
}
THEMED=0
mkdir -p "$SQDIR/schemes"
if want_terminal kitty; then
  d="$HOME/.config/kitty"; mkdir -p "$d"
  get_file "generated/kitty/squintless-$GEN.conf" > "$d/squintless-$GEN.conf"
  add_terminal_include "$d/kitty.conf" "include squintless-$GEN.conf"
  ok "kitty themed (include in kitty.conf)"; THEMED=1
fi
if want_terminal wezterm; then
  # wezterm.lua is Lua - our '#' markers aren't comments there, so drop the scheme + instruct (never edit it).
  d="$HOME/.config/wezterm"; mkdir -p "$d/colors"
  get_file "generated/wezterm/squintless-$GEN.toml" > "$d/colors/Squintless-$GEN.toml"
  ok "wezterm: scheme placed in colors/ - add to wezterm.lua:  config.color_scheme = '$SCHEME_NAME'"; THEMED=1
fi
if want_terminal alacritty; then
  # appending a top-level 'general.import' after existing [tables] is invalid TOML - drop + instruct.
  d="$HOME/.config/alacritty"; mkdir -p "$d"
  get_file "generated/alacritty/squintless-$GEN.toml" > "$d/squintless-$GEN.toml"
  ok "alacritty: scheme placed - add under [general] in alacritty.toml:  import = [\"~/.config/alacritty/squintless-$GEN.toml\"]"; THEMED=1
fi
if want_terminal ghostty; then
  d="$HOME/.config/ghostty"; mkdir -p "$d/themes"
  get_file "generated/ghostty/squintless-$GEN" > "$d/themes/squintless-$GEN"
  add_terminal_include "$d/config" "theme = squintless-$GEN"
  ok "ghostty themed (theme in config)"; THEMED=1
fi
if want_terminal iterm2; then
  get_file "generated/iterm2/squintless-$GEN.itermcolors" > "$SQDIR/schemes/squintless-$GEN.itermcolors"
  ok "iTerm2 scheme -> $SQDIR/schemes/squintless-$GEN.itermcolors (double-click to import, or Settings > Profiles > Colors > Import)"; THEMED=1
fi
if [ "$THEMED" -eq 0 ]; then
  get_file "generated/xresources/squintless-$GEN.Xresources" > "$SQDIR/schemes/squintless-$GEN.Xresources"
  warn "no supported terminal detected - generated schemes are in $SQDIR/schemes/ (use --terminal=kitty,wezterm,...)"
fi

# ---------- 5. Claude Code (optional) ----------
DO_CLAUDE="$WITH_CLAUDE"
if [ "$DO_CLAUDE" -eq 0 ] && [ -t 0 ] && [ "$ASSUME_YES" -eq 0 ]; then
  printf 'Apply Claude Code %s theme + ccstatusline statusline? (y/N): ' "$CLAUDE_THEME"
  read -r a || a=""
  case "$(printf '%s' "$a" | tr '[:upper:]' '[:lower:]')" in y|yes) DO_CLAUDE=1 ;; esac
fi
if [ "$DO_CLAUDE" -eq 1 ]; then
  step "Claude Code ($CLAUDE_THEME theme + statusline)"
  if have bun; then
    if bun install -g ccstatusline >/dev/null 2>&1; then ok "ccstatusline (bun)"; else warn "bun couldn't install ccstatusline"; fi
  elif have npm; then
    if npm install -g ccstatusline >/dev/null 2>&1; then ok "ccstatusline (npm)"; else warn "npm couldn't install ccstatusline"; fi
  else warn "no bun/npm - install ccstatusline yourself: npm i -g ccstatusline"; fi
  mkdir -p "$HOME/.config/ccstatusline"
  backup_file "$HOME/.config/ccstatusline/settings.json"
  get_file "ccstatusline.settings.json" > "$HOME/.config/ccstatusline/settings.json"
  ok "ccstatusline config -> ~/.config/ccstatusline/settings.json"
  claude="$HOME/.claude/settings.json"
  if [ -f "$claude" ]; then
    cc_cmd="$(resolve_cc_command)"
    backup_file "$claude"
    if have jq; then
      tmp="$(mktemp)"
      if [ -n "$cc_cmd" ]; then
        jq --arg t "$CLAUDE_THEME" --arg c "$cc_cmd" '.theme=$t | .statusLine={type:"command",command:$c,padding:0}' "$claude" > "$tmp" && mv "$tmp" "$claude" && ok "set Claude theme:$CLAUDE_THEME + statusLine"
      else
        jq --arg t "$CLAUDE_THEME" '.theme=$t' "$claude" > "$tmp" && mv "$tmp" "$claude" && warn "set theme:$CLAUDE_THEME; ccstatusline not found - set statusLine manually"
      fi
    elif have python3; then
      python3 - "$claude" "$CLAUDE_THEME" "$cc_cmd" <<'PY' && ok "set Claude theme + statusLine"
import json,sys
p,theme,cmd=sys.argv[1],sys.argv[2],sys.argv[3]
d=json.load(open(p)); d["theme"]=theme
if cmd: d["statusLine"]={"type":"command","command":cmd,"padding":0}
json.dump(d,open(p,"w"),indent=2)
PY
    else
      warn "neither jq nor python3 found - set theme + statusLine in ~/.claude/settings.json manually"
    fi
  else
    warn "Claude settings (~/.claude/settings.json) not found - run Claude Code once, then re-run with --with-claude"
  fi
fi

# ---------- done ----------
printf '\n%s==> Squintless v%s installed (%s).%s\n' "$C_GREEN" "$SQUINTLESS_VERSION" "$LABEL" "$C_RESET"
cat <<EOF
    Next:
      1. Restart your terminal (or: source $(rc_file)).
      2. Set your terminal font to a JetBrains Mono Nerd Font for prompt glyphs.
      3. WezTerm/iTerm2 may need one manual step (printed above).

    Backups (*.squintless-*.bak) sit next to every changed file.  Undo: ./install.sh --uninstall
    Loved it? Star the repo: https://github.com/sameer-zahir/squintless
EOF
