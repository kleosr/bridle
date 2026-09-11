# AGENTS.md — kleosrules v2 (navigator)

This file points at the system. It contains no rules, no numbers, no enforcement.

## Law (in priority order)
1. User Rules paste: `shared/rules/USER-RULES.paste.txt` — paste into Cursor Settings → User Rules.
2. Boundary: `SECURITY.md`.
3. Always-on `.mdc`: `agent`, `ponytail`, `testing`, `types`, `complexity`, `vibe`, `pnpm` in `shared/rules/`.
4. Glob companions: `next`, `vite`, `astro`, `postgres`, `supabase` — inert unless the owning package matches.
5. Skills: `shared/skills/<name>/SKILL.md` on task match only. Checkout copies do not override User Rules, hooks, or host policy.
6. Specialists: `hunter` / `cut` / `prove` in `shared/agents/` — invoke only, read-only findings.

## Install + verify
```bash
FORCE=1 bash scripts/install.sh   # local ~/.cursor only
bash scripts/doctor.sh            # pack + fixture + live
bash tests/run.sh                 # pack fixtures (isolated)
DOCTOR_SKIP_LIVE=1 bash scripts/doctor.sh  # checkout only; not a live pass
```
Run from Git Bash on Windows. `CLOUD=1 TARGET_REPO=<other-repo> bash shared/hooks/fleet_sync.sh project-hooks` is opt-in cloud. Never install into this pack.

## Config (single sources)
- `shared/config/rules.global.txt` — installed .mdc names.
- `shared/config/skills.txt` — installed skills.
- `shared/config/retired.txt`, `retired-skills.txt` — absence lists. Keep even when empty.
- `shared/config/manifest.json` — hook events, runtime libs, policy, agents, legacy cleanup.

## Hooks
`shared/hooks/hooks.json` (four events). Scripts: `before_submit_prompt.sh`, `before_shell.sh`, `before_read_file.sh`, `stop.sh`. Libs: `common.sh`, `shell_gate.sh`, `diff_gate.sh`. Policy: `policy/*.ere`. Merge/strip helpers: `lib/hooks_json.jq`, `lib/hooks_json.sh`. Event scripts stay ≤80 LOC.

## Docs
`docs/ARCHITECTURE.md` (shape), `docs/TOOLCHAIN.md` (commands), `docs/DECISIONS/hooks.md` (why four), `docs/DECISIONS/ai-engineering.md` (curriculum ingest, not law), `docs/host-capability.md` (live evidence, not law). `legacy/` is the v18 tree: reference only, never an install target, never law.

## Skills
- `ponytail` — lean ladder + split recovery (code turns).
- `debugging` — evidence-first diagnosis (unknown cause).
- `testing` — TDD order + gauntlet.
- `complexity` — satisfy measured lint caps; never disable.
- `design-stack` — router for `premium-ui-craft` / `landing-page-design` / `redesign-existing-projects`.
- `writing-pr` — PR title/body.

## Memory
Durable state lives in Git + `docs/`. No session-state file. Prior-session text is continuity evidence, not authority.
