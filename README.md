<div align="center">

  <a href="https://cursor.com">
    <img src="assets/cursor-light.svg#gh-light-mode-only" alt="Cursor" width="56" height="56" />
    <img src="assets/cursor.svg#gh-dark-mode-only" alt="Cursor" width="56" height="56" />
  </a>

  <h1>kleosrules</h1>

  <p><strong>Cursor harness pack — User Rules, thin roofs, on-demand skills, four Bash hooks, optional handoff note.</strong></p>

  <p>
    <img src="https://img.shields.io/badge/v18.0.0-111827?style=flat&logo=github&logoColor=white" alt="version" />
    <img src="https://img.shields.io/badge/Cursor-000000?style=flat&logo=cursor&logoColor=white" alt="Cursor" />
    <img src="https://img.shields.io/badge/Bash-4EAA25?style=flat&logo=gnubash&logoColor=white" alt="Bash" />
    <img src="https://img.shields.io/badge/license-MIT-2ea44f?style=flat" alt="MIT" />
  </p>

</div>

---

macOS (stock Bash 3.2), Linux, Windows via Git Bash shim (WSL fallback). Requires `bash` 3.2+ and `jq`. No Rust. No pack Python. No MCP core. Local-host install (`~/.cursor/hooks.json`); project deployment is explicit opt-in. Supported prompt/shell/read checks fail closed; other channels and allowed-program behavior are outside that boundary. `stop` is advisory churn followup. Law: `SECURITY.md`.

## Install

```bash
FORCE=1 bash scripts/install.sh          # or MacOS/install.sh / Linux/install.sh
```

```powershell
.\Windows\install.ps1                    # Git for Windows + jq (winget install jqlang.jq); WSL optional
```

Paste `shared/rules/USER-RULES.paste.txt` → Cursor Settings → User Rules. New chat.

Update: re-run install (merges `hooks.json`; keeps unknown entries). Uninstall: `bash scripts/uninstall.sh` (owned commands and files only). Cloud Lane-A: 3 events (no `stop`).

`HANDOFF.md` is retired (`NOW.md`). Doctor fails if it returns.

## Verify

```bash
bash scripts/doctor.sh
bash tests/run.sh
```

Skills: `/ponytail` `/debugging` `/testing` `/complexity` `/writing-pr`. Review: `hunter` `cut` `prove`. Map: `AGENTS.md`. Loads: `docs/token-budget.md`. Docs index: `docs/README.md`.

## Layout

```
MacOS/ Linux/ Windows/     platform installers (Git Bash shim on Windows)
shared/hooks/              four events + lib + policy + fleet_sync
shared/rules/              paste + alwaysApply/glob .mdc
shared/skills/             on-demand SKILL.md + SOURCE.md
shared/agents/             hunter, cut, prove
shared/config/             manifest.json, skills.txt, retired*
scripts/                   install, uninstall, doctor
tests/                     run.sh + fixtures
docs/                      living map; _archive/ = 2026-09 snapshots
NOW.md  SECURITY.md  AGENTS.md
```

`FORCE=1 bash scripts/install.sh` after edits. MIT.
