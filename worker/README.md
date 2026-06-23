# Squintless short-URL Worker

A tiny Cloudflare Worker that 302-redirects short paths to the install scripts, so
the one-liner can be `irm <short>/sq | iex` instead of the long raw GitHub URL.

**Live:** `sameerzahir.com/sq` · `sameerzahir.com/sh` (and `squintless.sameerzahir97.workers.dev`).

| Path | Redirects to |
| --- | --- |
| `/sq`, `/ps1` | `…/main/install.ps1` (Windows) |
| `/sh` | `…/main/install.sh` (macOS/Linux) |
| `/` | the GitHub repo |

## Deploy

```bash
cd worker
wrangler deploy          # publishes to https://squintless.<your-subdomain>.workers.dev
```

The custom-domain routes (`sameerzahir.com/sq` and `/sh`) are already active in
`wrangler.toml` and deployed. To change them, edit that `routes` block (the zone must
be on your Cloudflare account) and run `wrangler deploy`. Because these are 302
redirects, you can later point `/sq` at a pinned release tag without touching any caller.
