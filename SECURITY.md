# Security Policy

Squintless is installed with a piped one-liner:

```powershell
irm https://sameerzahir.com/sq | iex          # Windows
```
```bash
curl -fsSL https://sameerzahir.com/sh | bash   # macOS / Linux
```

Running code straight from a URL is a real trust decision, so this document explains
what those URLs resolve to, how to verify a download, and how to report a problem.

## Reporting a vulnerability

Please report privately first — don't open a public issue for a security problem.

- Email **sameerzahir97@gmail.com**, or
- Open a **private GitHub security advisory**:
  <https://github.com/sameer-zahir/squintless/security/advisories/new>

Include what you found, how to reproduce it, and the OS / shell / install method.
You'll get an acknowledgement, and fixes ship in a tagged release with credit if
you'd like it.

## Supported versions

The **latest release** is supported. Squintless is a single linear line of releases;
fixes land on `main` and go out in the next tag. If you're affected by something,
update to the newest release first.

## What the short URLs actually do

`sameerzahir.com/sq` and `sameerzahir.com/sh` are **transparent 302 redirects** served
by a tiny Cloudflare Worker ([`worker/`](worker/)). They point at the raw scripts on
`main`, nothing else:

- `/sq` (and `/ps1`) → `https://raw.githubusercontent.com/sameer-zahir/squintless/main/install.ps1`
- `/sh` → `https://raw.githubusercontent.com/sameer-zahir/squintless/main/install.sh`

You can audit exactly what you'll run before running it:

```bash
curl -fsSL https://sameerzahir.com/sh        # prints install.sh; pipe to bash only when happy
```

Prefer no redirect at all? Use the full `raw.githubusercontent.com/.../main/install.ps1`
(or `install.sh`) URL, or clone the repo and run `./install.sh` / `.\install.ps1`
locally. Every config the installer places lives in [`config/`](config/) — nothing is
hidden or fetched from anywhere else.

## Verifying a download

Tagged releases ship a **`SHA256SUMS`** file alongside `install.ps1`, `install.sh`,
and `squintless-config.zip`. After downloading from the
[Releases page](https://github.com/sameer-zahir/squintless/releases), check it:

```bash
sha256sum -c SHA256SUMS        # macOS: shasum -a 256 -c SHA256SUMS
```
```powershell
Get-FileHash install.ps1 -Algorithm SHA256   # compare against SHA256SUMS
```

The checksums are produced in CI when a `vX.Y.Z` tag is pushed, and the tag is
verified to match `VERSION` before the release is cut.

## What the installer does — and doesn't do

The installers are designed to be safe to run, re-run, and reverse:

- **Non-destructive & idempotent.** They back up **every file they touch** to a
  `*.squintless-*.bak` next to the original, and re-running won't duplicate anything.
- **Only what you have.** They wire up tools that are actually present and skip the
  rest.
- **Fully reversible.** `-Uninstall` (Windows) / `--uninstall` (macOS/Linux) removes
  the shell block, color scheme, `git-delta` config and oh-my-posh theme, backing up
  each file first and leaving installed tools in place.
- **Nothing in the background.** No service is installed and nothing runs after the
  install finishes. To undo by hand, delete the
  `# >>> squintless >>> … # <<< squintless <<<` block or restore a `.bak` file.
