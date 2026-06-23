---
name: squintless-setup
description: Set up Squintless - an easy-on-the-eyes look for the terminal and Claude Code (theme, font, prompt, git-delta, statusline) in either Gruvbox light or Tokyo Night Moon dark. Use when the user wants a low-eye-strain terminal or Claude Code theme (light or dark), asks to reduce eye strain while coding, or mentions Squintless.
---

# Squintless setup

Squintless is a one-command, eye-strain-optimized setup for the terminal and Claude Code, in two cohesive palettes: **Gruvbox light** (default) and **Tokyo Night Moon** (dark). Use this skill to help the user install it, or to apply just the Claude Code parts.

## What it includes

- **Claude Code:** `theme` matching the chosen variant (`light` or `dark`) + a curated [ccstatusline](https://github.com/sirmalloc/ccstatusline) statusline (model · effort · cwd · git · usage on line 1; context · cost · timers · weekly usage on line 2). The ccstatusline config uses ANSI color names, so the same settings look right in both light and dark.
- **Terminal (Windows):** a `Squintless (Gruvbox Light)` or `Squintless (Tokyo Night Moon)` Windows Terminal scheme, JetBrains Mono Nerd Font, themed PowerShell (PSReadLine colors + oh-my-posh prompt), and git-delta with a matching syntax theme (`gruvbox-light` / `TwoDark`).

## How to help the user

1. **Full setup (Windows / PowerShell 7+).** Have them run:
   ```powershell
   irm https://raw.githubusercontent.com/sameer-zahir/squintless/main/install.ps1 | iex
   ```
   This asks light or dark interactively. To choose up front and add the font/render defaults plus the matching Claude Code theme + statusline (use `-Light` for Gruvbox):
   ```powershell
   $s = irm https://raw.githubusercontent.com/sameer-zahir/squintless/main/install.ps1
   & ([scriptblock]::Create($s)) -Dark -WithTerminalDefaults -WithClaude
   ```

2. **Just the Claude Code look (any OS).**
   - Set `theme` to `light` or `dark` in `~/.claude/settings.json`.
   - Install the statusline: `npm install -g ccstatusline` (or `bun install -g ccstatusline`), then set `statusLine` to run the `ccstatusline` binary. Offer the curated config from the repo's `config/ccstatusline.settings.json` (it uses ANSI color names, so it suits both themes).

3. **Not on Windows?** Point them to the portable color schemes (Gruvbox-light, or the `.dark.json` Tokyo Night Moon) and the per-tool files in the repo's `config/` directory. Native macOS/Linux installers are a work in progress - contributions welcome.

Repo: https://github.com/sameer-zahir/squintless · by Sameer Zahir (https://sameerzahir.com).
