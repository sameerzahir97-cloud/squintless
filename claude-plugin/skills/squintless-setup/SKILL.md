---
name: squintless-setup
description: Set up Squintless - an easy-on-the-eyes look for the terminal and Claude Code (theme, font, prompt, git-delta, statusline) in either Gruvbox light or Tokyo Night Moon dark. Use when the user wants a low-eye-strain terminal or Claude Code theme (light or dark), asks to reduce eye strain while coding, or mentions Squintless.
---

# Squintless setup

Squintless is a one-command, eye-strain-optimized setup for the terminal and Claude Code, in two cohesive palettes: **Gruvbox light** (default) and **Tokyo Night Moon** (dark). Use this skill to help the user install it, or to apply just the Claude Code parts.

## What it includes

- **Claude Code:** `theme` matching the chosen variant (`light` or `dark`) + a curated [ccstatusline](https://github.com/sirmalloc/ccstatusline) statusline (model · effort · cwd · git · usage on line 1; context · cost · timers · weekly usage on line 2). The ccstatusline config uses ANSI color names, so the same settings look right in both light and dark.
- **Terminal (Windows / macOS / Linux):** a `Squintless (Gruvbox Light)` or `Squintless (Tokyo Night Moon)` color scheme (Windows Terminal on Windows; kitty / WezTerm / Alacritty / Ghostty / iTerm2 on macOS & Linux), JetBrains Mono Nerd Font, a themed oh-my-posh prompt (PowerShell, or `zsh`/`bash`), and git-delta with a matching syntax theme (`gruvbox-light` / `TwoDark`).

## How to help the user

First ask which OS they're on and whether they want light or dark.

1. **Full setup — Windows (PowerShell 7+).**
   ```powershell
   irm https://sameerzahir.com/sq | iex
   ```
   Asks light/dark interactively. To choose up front and add the font/render defaults plus the Claude Code theme + statusline (`-Light` for Gruvbox):
   ```powershell
   $s = irm https://raw.githubusercontent.com/sameer-zahir/squintless/main/install.ps1
   & ([scriptblock]::Create($s)) -Dark -WithTerminalDefaults -WithClaude
   ```

2. **Full setup — macOS / Linux.**
   ```bash
   curl -fsSL https://sameerzahir.com/sh | bash
   ```
   Flags: `--dark` / `--light`, `--with-claude`, `--terminal=kitty,wezterm`, `--skip-deps`, `--uninstall`, `--yes`. It themes kitty/Ghostty automatically and drops a scheme + one-line instruction for WezTerm/Alacritty/iTerm2.

3. **Just the Claude Code look (any OS, no terminal changes).**
   - Set `theme` to `light` or `dark` in `~/.claude/settings.json`.
   - Install the statusline: `npm install -g ccstatusline` (or `bun install -g ccstatusline`), then point `statusLine` at the `ccstatusline` binary. Offer the curated config from `config/ccstatusline.settings.json` (ANSI color names, so it suits both themes).

Everything the installers touch is backed up (`*.squintless-*.bak`) and reversible with `-Uninstall` / `--uninstall` — reassure first-timers of that.

Repo: https://github.com/sameer-zahir/squintless · by Sameer Zahir (https://sameerzahir.com).
