#!/usr/bin/env python3
"""Repo validation for CI and local use: JSON well-formedness, Windows Terminal
scheme completeness, and version sync across VERSION / plugin.json / install.ps1.

  python tools/validate.py     # exit 1 on any problem

Pairs with `python tools/gen.py --check` (generated-file freshness).
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
errs: list[str] = []

REQUIRED_SCHEME_KEYS = {
    "name", "background", "foreground",
    "black", "red", "green", "yellow", "blue", "purple", "cyan", "white",
    "brightBlack", "brightRed", "brightGreen", "brightYellow",
    "brightBlue", "brightPurple", "brightCyan", "brightWhite",
    "cursorColor", "selectionBackground",
}


def load_json(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as e:  # noqa: BLE001
        errs.append(f"invalid JSON {path.relative_to(ROOT)}: {e}")
        return None


def check_scheme(d: dict, where: str):
    missing = REQUIRED_SCHEME_KEYS - set(d)
    if missing:
        errs.append(f"{where}: missing scheme keys {sorted(missing)}")


def main() -> int:
    # 1. Every JSON file parses.
    globs = ["palettes/*.json", "config/**/*.json",
             "claude-plugin/.claude-plugin/plugin.json", ".claude-plugin/marketplace.json"]
    for g in globs:
        for f in ROOT.glob(g):
            load_json(f)

    # 2. Windows Terminal schemes define name + all 16 colors (fragment requirement).
    for name in ("windows-terminal.scheme.json", "windows-terminal.scheme.dark.json"):
        f = ROOT / "config" / name
        d = load_json(f)
        if d:
            check_scheme(d, f"config/{name}")
    for f in ROOT.glob("config/generated/windows/*.fragment.json"):
        d = load_json(f)
        for s in (d or {}).get("schemes", []):
            check_scheme(s, f"{f.relative_to(ROOT)} scheme '{s.get('name', '?')}'")

    # 3. Version sync across the three sources of truth.
    version = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
    plugin = load_json(ROOT / "claude-plugin/.claude-plugin/plugin.json") or {}
    m_ps = re.search(r"\$SquintlessVersion\s*=\s*'([^']+)'",
                     (ROOT / "install.ps1").read_text(encoding="utf-8"))
    m_sh = re.search(r'SQUINTLESS_VERSION="([^"]+)"',
                     (ROOT / "install.sh").read_text(encoding="utf-8"))
    versions = {"VERSION": version, "plugin.json": plugin.get("version"),
                "install.ps1": m_ps.group(1) if m_ps else None,
                "install.sh": m_sh.group(1) if m_sh else None}
    psd1 = ROOT / "module/Squintless/Squintless.psd1"
    if psd1.exists():
        m_mod = re.search(r"ModuleVersion\s*=\s*'([^']+)'", psd1.read_text(encoding="utf-8"))
        versions["module.psd1"] = m_mod.group(1) if m_mod else None
    if len(set(versions.values())) != 1:
        errs.append(f"version mismatch: {versions}")

    if errs:
        print("VALIDATION FAILED:")
        for e in errs:
            print(f"  - {e}")
        return 1
    print(f"validation OK (version {version}).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
