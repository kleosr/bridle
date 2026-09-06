<div align="center">

  <a href="https://cursor.com">
    <img src="assets/cursor-light.svg#gh-light-mode-only" alt="Cursor" width="56" height="56" />
    <img src="assets/cursor.svg#gh-dark-mode-only" alt="Cursor" width="56" height="56" />
  </a>

  <h1>kleosrules</h1>

  <p><strong>Cursor harness pack — User Rules, thin roofs, on-demand skills, five Bash hooks, local NOW.md.</strong></p>

  <p>
    <img src="https://img.shields.io/badge/v18.0.0-111827?style=flat&logo=github&logoColor=white" alt="version" />
    <img src="https://img.shields.io/badge/Cursor-000000?style=flat&logo=cursor&logoColor=white" alt="Cursor" />
    <img src="https://img.shields.io/badge/Bash-4EAA25?style=flat&logo=gnubash&logoColor=white" alt="Bash" />
    <img src="https://img.shields.io/badge/license-MIT-2ea44f?style=flat" alt="MIT" />
  </p>

</div>

---

macOS (stock Bash 3.2), Linux, Windows via WSL shim. Requires `bash` 3.2+ and `jq`. No Rust. No pack Python. No MCP core. Hooks register globally (`~/.cursor/hooks.json`). `sessionStart` points at `NOW.md`. Steel: secrets + shell + stop churn. Law: `SECURITY.md`.

## Install

```bash
FORCE=1 bash scripts/install.sh          # or MacOS/install.sh / Linux/install.sh
```

```powershell
.\Windows\install.ps1                    # WSL + jq inside WSL; native Windows unsupported
```

Paste `shared/rules/USER-RULES.paste.txt` → Cursor Settings → User Rules. New chat.

Update: re-run install (idempotent). Uninstall: `bash scripts/uninstall.sh` (fingerprinted; keeps your custom `.mdc`). Cloud Lane-A: 3 events (no `sessionStart`, no `stop`).

`HANDOFF.md` is retired (`NOW.md`). Doctor fails if it returns.

## Verify

```bash
bash scripts/doctor.sh
bash tests/run.sh
```

Skills: `/ponytail` `/debugging` `/testing` `/complexity` `/now`. Review: `hunter` `cut` `prove`. Map: `AGENTS.md`. Caps: `docs/token-budget.md`. Docs index: `docs/README.md`.

## Layout

```
MacOS/ Linux/ Windows/     platform installers (WSL shim on Windows)
shared/hooks/              five events + lib + policy + fleet_sync
shared/rules/              paste + alwaysApply/glob .mdc
shared/skills/             on-demand SKILL.md + SOURCE.md
shared/agents/             hunter, cut, prove
shared/config/             skills.txt, retired*, scan.roots
scripts/                   install, uninstall, doctor, sync
tests/                     run.sh + fixtures
docs/                      living map; _archive/ = 2026-09 snapshots
NOW.md  SECURITY.md  AGENTS.md
```

`FORCE=1 bash scripts/install.sh` after edits. `sync` is opt-in (`scan.roots` empty). MIT.
