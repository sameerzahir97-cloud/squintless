---
name: squintless-setup
description: Set up Squintless - an easy-on-the-eyes Gruvbox-light look for the terminal and Claude Code (theme, font, prompt, git-delta, statusline). Use when the user wants a light, low-eye-strain terminal or Claude Code theme, asks to reduce eye strain while coding, or mentions Squintless.
---

# Squintless setup

Squintless is a one-command, eye-strain-optimized **Gruvbox-light** setup for the terminal and Claude Code. Use this skill to help the user install it, or to apply just the Claude Code parts.

## What it includes

- **Claude Code:** `theme: light` + a curated [ccstatusline](https://github.com/sirmalloc/ccstatusline) statusline (model · effort · cwd · git · usage on line 1; context · cost · timers · weekly usage on line 2).
- **Terminal (Windows):** a Gruvbox-light Windows Terminal scheme, JetBrains Mono Nerd Font, themed PowerShell (PSReadLine colors + oh-my-posh prompt), and git-delta with the `gruvbox-light` syntax theme.

## How to help the user

1. **Full setup (Windows / PowerShell 7+).** Have them run:
   ```powershell
   irm https://raw.githubusercontent.com/sameer-zahir/squintless/main/install.ps1 | iex
   ```
   For the font/render defaults and the Claude Code theme + statusline as well:
   ```powershell
   $s = irm https://raw.githubusercontent.com/sameer-zahir/squintless/main/install.ps1
   & ([scriptblock]::Create($s)) -WithTerminalDefaults -WithClaude
   ```

2. **Just the Claude Code look (any OS).**
   - Set `theme` to `light` in `~/.claude/settings.json`.
   - Install the statusline: `npm install -g ccstatusline` (or `bun install -g ccstatusline`), then set `statusLine` to run the `ccstatusline` binary. Offer the curated config from the repo's `config/ccstatusline.settings.json`.

3. **Not on Windows?** Point them to the portable Gruvbox-light color scheme and the per-tool files in the repo's `config/` directory. Native macOS/Linux installers are a work in progress - contributions welcome.

Repo: https://github.com/sameer-zahir/squintless · by Sameer Zahir (https://sameerzahir.com).
