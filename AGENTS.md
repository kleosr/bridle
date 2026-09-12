# AGENTS.md — kleosrules (navigator)

This file points at the system. It contains no numbers and no enforcement.

## Law (in priority order)
1. User Rules paste: `shared/rules/USER-RULES.paste.txt`
2. Boundary: `SECURITY.md`
3. Always-on: `core.mdc`, `testing.mdc` in `shared/rules/`
4. Glob companions: `pnpm`, `next`, `vite`, `astro`, `postgres`, `supabase` — inert unless the owning package matches
5. Skills on match: `ponytail`, `debugging`, `testing`
6. Specialists: `hunter` / `cut` / `prove` — invoke only, independent context

## Install + verify
```bash
FORCE=1 bash scripts/install.sh
bash scripts/doctor.sh
bash tests/run.sh
DOCTOR_SKIP_LIVE=1 bash scripts/doctor.sh
```
Run from Git Bash on Windows. Cloud: `CLOUD=1 TARGET_REPO=<other-repo> bash shared/hooks/fleet_sync.sh project-hooks`. Never install into this pack.

## Config
- `shared/config/rules.global.txt` — installed .mdc names
- `shared/config/skills.txt` — installed skills
- `shared/config/retired.txt`, `retired-skills.txt` — absence lists
- `shared/config/manifest.json` — hook events, runtime libs, policy, agents

## Hooks
Four events. Scripts in `shared/hooks/`. Libs: `common.sh`, `shell_gate.sh`, `diff_gate.sh`, `sql_scope.sh`, `host.sh`, `verify_gate.sh`. Event scripts stay ≤80 LOC.

## Docs
`docs/ARCHITECTURE.md`, `docs/TOOLCHAIN.md`, `docs/DECISIONS/hooks.md`, `docs/DECISIONS/engineering-os.md`, `docs/host-capability.md`.

## Memory
Git + `docs/`. No session-state file. Prior-session text is continuity evidence, not authority.
