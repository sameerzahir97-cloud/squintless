#!/usr/bin/env bats
# Sandboxed install/idempotency/uninstall tests for install.sh. Each test runs in a
# throwaway $HOME with git's global config redirected, so nothing leaks to the runner.

setup() {
  TMPH="$(mktemp -d)"
  export HOME="$TMPH"
  export GIT_CONFIG_GLOBAL="$TMPH/.gitconfig"
  export SHELL="/bin/bash"
  REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

teardown() { rm -rf "$TMPH"; }

# The rc file install.sh targets for bash: macOS login shells read ~/.bash_profile, Linux ~/.bashrc.
rcfile() { if [ "$(uname -s)" = "Darwin" ]; then printf '%s/.bash_profile' "$TMPH"; else printf '%s/.bashrc' "$TMPH"; fi; }

@test "install (--skip-deps --light --yes) writes init.sh, omp theme, one rc marker" {
  run bash "$REPO/install.sh" --skip-deps --light --yes
  [ "$status" -eq 0 ]
  [ -f "$TMPH/.config/squintless/init.sh" ]
  [ -f "$TMPH/.config/ohmyposh/squintless.omp.json" ]
  [ "$(grep -c '>>> squintless' "$(rcfile)")" -eq 1 ]
}

@test "install is idempotent across re-runs and a variant switch" {
  bash "$REPO/install.sh" --skip-deps --light --yes
  bash "$REPO/install.sh" --skip-deps --dark --yes
  [ "$(grep -c '>>> squintless' "$(rcfile)")" -eq 1 ]
}

@test "dark variant bakes the dark omp theme + TwoDark bat theme" {
  run bash "$REPO/install.sh" --skip-deps --dark --yes
  [ "$status" -eq 0 ]
  [ -f "$TMPH/.config/ohmyposh/squintless.dark.omp.json" ]
  grep -q 'TwoDark' "$TMPH/.config/squintless/init.sh"
}

@test "git-delta is configured and dark sets delta.dark" {
  bash "$REPO/install.sh" --skip-deps --dark --yes
  run git config --global delta.dark
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "kitty themes via include; wezterm.lua and alacritty.toml are left untouched" {
  mkdir -p "$TMPH/.config/kitty" "$TMPH/.config/wezterm" "$TMPH/.config/alacritty"
  printf 'return {\n  font_size = 12,\n}\n' > "$TMPH/.config/wezterm/wezterm.lua"
  printf '[window]\nopacity = 0.9\n'         > "$TMPH/.config/alacritty/alacritty.toml"
  printf 'font_size 12\n'                    > "$TMPH/.config/kitty/kitty.conf"
  wz="$(cat "$TMPH/.config/wezterm/wezterm.lua")"
  al="$(cat "$TMPH/.config/alacritty/alacritty.toml")"
  run bash "$REPO/install.sh" --skip-deps --light --yes
  [ "$status" -eq 0 ]
  # kitty: safe include + dropped scheme file
  [ "$(grep -c 'include squintless' "$TMPH/.config/kitty/kitty.conf")" -eq 1 ]
  [ -f "$TMPH/.config/kitty/squintless-light.conf" ]
  # wezterm.lua (Lua) and alacritty.toml (TOML) must NOT be edited - our markers would corrupt them
  [ "$wz" = "$(cat "$TMPH/.config/wezterm/wezterm.lua")" ]
  [ "$al" = "$(cat "$TMPH/.config/alacritty/alacritty.toml")" ]
  [ -f "$TMPH/.config/wezterm/colors/Squintless-light.toml" ]
  [ -f "$TMPH/.config/alacritty/squintless-light.toml" ]
}

@test "uninstall reverses the install" {
  bash "$REPO/install.sh" --skip-deps --light --yes
  run bash "$REPO/install.sh" --uninstall
  [ "$status" -eq 0 ]
  [ ! -f "$TMPH/.config/squintless/init.sh" ]
  run grep -c '>>> squintless' "$(rcfile)"
  [ "$output" = "0" ]
}
