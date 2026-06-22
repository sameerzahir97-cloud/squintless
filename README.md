<div align="center">

# Squintless

### Easy on the eyes.

A one-command, eye-strain–optimized terminal + Claude Code setup for Windows.
Gruvbox-light done *cohesively* — terminal, font, shell, git diffs and your Claude Code statusline all speak the same calm palette.

[![License: MIT](https://img.shields.io/badge/License-MIT-79740E.svg)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/sameer-zahir/squintless?style=flat&color=B57614)](https://github.com/sameer-zahir/squintless/stargazers)
[![PRs welcome](https://img.shields.io/badge/PRs-welcome-076678.svg)](https://github.com/sameer-zahir/squintless/pulls)
![Platform](https://img.shields.io/badge/platform-Windows%20%C2%B7%20PowerShell%207-8F3F71.svg)

![Squintless terminal preview](assets/hero.png)

</div>

## Install

**Requires:** Windows · [PowerShell 7+](https://aka.ms/powershell) · [Windows Terminal](https://aka.ms/terminal). Not on PowerShell 7 yet? `winget install Microsoft.PowerShell`, then open `pwsh` and paste the line below. *(macOS/Linux scripts welcome — [PRs open](https://github.com/sameer-zahir/squintless/pulls).)*

One line in **PowerShell 7+** — adds the Gruvbox-light scheme and applies it for you:

```powershell
irm https://raw.githubusercontent.com/sameer-zahir/squintless/main/install.ps1 | iex
```

Want the full treatment (also apply the **OLED-tuned font/render defaults** to Windows Terminal **and** theme Claude Code)?

```powershell
$s = irm https://raw.githubusercontent.com/sameer-zahir/squintless/main/install.ps1
& ([scriptblock]::Create($s)) -WithTerminalDefaults -WithClaude
```

The installer is **idempotent** and **non-destructive** — it backs up every file it touches (`*.squintless-*.bak`), only wires up tools you actually have, and you can re-run it any time. Restart your terminal when it's done.

**Prefer to read it first?** Clone the repo and run `.\install.ps1` locally — every config it places lives in [`config/`](config/), and it writes a `*.squintless-*.bak` next to anything it changes (your Windows Terminal settings, PowerShell profile, `~/.gitconfig`, and Claude settings). Nothing is hidden.

> ⭐ If Squintless saves your eyes, a star genuinely helps it reach the next person squinting at their screen.

## What you get

| Layer | What Squintless sets up |
| --- | --- |
| **Terminal** | A `Squintless (Gruvbox Light)` Windows Terminal color scheme (soft `#F2E5BC` background, no harsh white) |
| **Font** | JetBrains Mono Nerd Font, installed from the official Nerd Fonts release |
| **Shell** | Themed PowerShell — PSReadLine syntax colors in the Gruvbox palette, an oh-my-posh prompt, plus `zoxide` / `eza` / `bat` / `lazygit` wired in |
| **Git** | `git-delta` with the `gruvbox-light` syntax theme — readable diffs that match everything else |
| **Claude Code** *(optional)* | `theme: light` + a curated [ccstatusline](https://github.com/sirmalloc/ccstatusline) statusline |

Everything is plain config you can read in [`config/`](config/) — nothing hidden.

## Why

I built this because my eyes hurt. I spend most of my day in a terminal, so I asked Claude to help me rebuild mine to be genuinely easy on the eyes — then realised the setup was worth sharing with anyone who codes long days. **[The full story →](https://sameerzahir.com/thoughts/an-afternoon-not-a-degree/)**

Most terminal setups are dark, high-contrast, and built to look striking in a screenshot. That's great until you're eight hours into a session in a bright room and your eyes are done.

Light themes exist, but they're usually **just a color scheme** — the prompt, the diffs, the `ls` output and the statusline are all still a mismatched mess. Squintless is the opposite: a **single, coherent, low-strain palette across the whole terminal**, with the font and rendering tuned to match. It's the setup I actually use all day, packaged so you can have it in one command.

- **Soft, not bright** — a warm `#F2E5BC` background instead of glaring white.
- **Cohesive** — terminal, prompt, syntax, git diffs and Claude Code all in one palette.
- **Legible** — JetBrains Mono Nerd Font with grayscale antialiasing (crisp on modern/OLED panels).
- **Honest config** — every value is in `config/`, copy what you like.

## Tuning for your display

The defaults are tuned for a **HiDPI / OLED laptop** (≈215 PPI, 200% scaling). On a standard LCD, adjust these in Windows Terminal (Settings → your profile → Appearance, or `profiles.defaults`):

| Setting | Squintless default (OLED/HiDPI) | Standard LCD |
| --- | --- | --- |
| `antialiasingMode` | `grayscale` *(avoids color fringing on OLED subpixels)* | `cleartype` |
| `font.cellHeight` | `1.35` | `1.0`–`1.15` |
| `font.size` | `14` | `11`–`12` |

## What the installer does (and how to undo it)

1. Installs dependencies with `winget` (oh-my-posh, delta, zoxide, eza, bat, lazygit, bun) and the JetBrains Mono Nerd Font via oh-my-posh.
2. Adds the color scheme to your Windows Terminal `settings.json` (and, with `-WithTerminalDefaults`, the font/render defaults).
3. Copies the oh-my-posh theme to `~/.config/ohmyposh/squintless.omp.json`.
4. Adds a marker-delimited block to your PowerShell `$PROFILE` (PSReadLine colors + tool init).
5. Configures `git-delta` in `~/.gitconfig`.
6. *(optional, `-WithClaude`)* installs ccstatusline and sets Claude Code `theme: light` + statusline.

**Uninstall:** re-run the installer with `-Uninstall`:

```powershell
$s = irm https://raw.githubusercontent.com/sameer-zahir/squintless/main/install.ps1
& ([scriptblock]::Create($s)) -Uninstall
```

It removes the profile block, the Windows Terminal color scheme, the `git-delta` config and the oh-my-posh theme — backing up each file first, and leaving winget-installed tools in place. Prefer to do it by hand? Delete the `# >>> squintless >>> … # <<< squintless <<<` block from your `$PROFILE`, or restore any `*.squintless-*.bak` backup. Nothing installs a service or runs in the background.

## Prefer to cherry-pick?

Clone it and take only the pieces you want — every file in [`config/`](config/) is standalone:

```powershell
git clone https://github.com/sameer-zahir/squintless.git
cd squintless
.\install.ps1 -WithTerminalDefaults -WithClaude   # or copy individual config files by hand
```

## Use it inside Claude Code

Squintless is also a tiny **Claude Code plugin**. Add the marketplace and install it, then run `/squintless-setup` and Claude will set up the light theme + statusline for you:

```
/plugin marketplace add sameer-zahir/squintless
/plugin install squintless@squintless
```

## Credits

Made by **[Sameer Zahir](https://sameerzahir.com)** · [@sameer-zahir](https://github.com/sameer-zahir)

Built on the shoulders of [Gruvbox](https://github.com/morhetz/gruvbox), [JetBrains Mono](https://www.jetbrains.com/lp/mono/), [Nerd Fonts](https://github.com/ryanoasis/nerd-fonts), [oh-my-posh](https://ohmyposh.dev), [git-delta](https://github.com/dandavison/delta) and [ccstatusline](https://github.com/sirmalloc/ccstatusline). The color scheme is also available for other terminals via [iTerm2-Color-Schemes](https://github.com/mbadolato/iTerm2-Color-Schemes).

Contributions welcome — macOS/Linux install scripts, a dark variant, and more terminals are all fair game. Open an issue or PR.

<div align="center">

**[⭐ Star Squintless](https://github.com/sameer-zahir/squintless)** if it helped your eyes.

MIT © 2026 Sameer Zahir

</div>
