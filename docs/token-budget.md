# Token budget

Caps live in `tests/token_budget.sh`. Rough tokens = bytes / 4.

## Always-on (every local session)

| Surface | Why | Lock |
|---------|-----|------|
| `USER-RULES.paste.txt` | User Rules; cloud floor | byte cap + labeled roof restatement |
| 7 alwaysApply `.mdc` | `~/.cursor/rules` | count 7; sum + `agent.mdc` |
| `session_start.sh` | `additional_context` | path to NOW.md |
| `AGENTS.md` | this repo / cloud handbook | navigator cap |

Other hooks emit `continue` / `permission` / one `followup_message`. Not always-on prose.

## On-demand

| Surface | When | Lock |
|---------|------|------|
| skill `description` | catalog | ≤ 200 B each |
| `SKILL.md` body | task match | ≤ 1800 B; sum ≤ 12000 |
| hunter / cut / prove | invoke | ≤ 2500 / 2300 / 2300 |
| `SOURCE.md` | stuck on design | not always-on |
| `docs/_archive/` | audit trail | not installed, not injected |

## Caps

| Meter | Cap |
|-------|-----|
| alwaysApply count | 7 |
| alwaysApply bytes | 8200 |
| `agent.mdc` | 1900 |
| paste | 3900 |
| `AGENTS.md` | 2400 |
| sessionStart inject | 220 |
| paste + mdc + inject | 12500 |
| paste roof paragraph | 480 |
| skill description | 200 |
| skill body | 1800 |
| skill body sum | 12000 |
| hunter / cut / prove | 2500 / 2300 / 2300 |
| README | 3200 |

## Before → after (master 2026-09-05 → this PR)

Always-on:

| Surface | Before B | ~tok | After B | ~tok |
|---------|----------|------|---------|------|
| paste | 4324 | 1081 | 3813 | 954 |
| alwaysApply sum | 9334 | 2334 | 7727 | 1932 |
| `agent.mdc` | 3040 | 760 | 1545 | 387 |
| sessionStart inject | 2038 | 510 | 57 | 15 |
| `AGENTS.md` | 2183 | 546 | 2213 | 554 |
| **session always-on** | **15696** | **3924** | **11597** | **2900** |

On-demand + handbook:

| Surface | Before B | After B |
|---------|----------|---------|
| 10 skill bodies | 21988 | 10478 |
| hunter + cut + prove | 15314 | 6140 |
| README | 9555 | 2574 |
| living `docs/*.md` | 83557 | ~25k + `_archive/` |

## Layout

Living: `docs/README.md` → ARCHITECTURE, CURATOR, TOOLCHAIN, token-budget, quality-roofs-audit, engineering-system, DECISIONS. Snapshots: `docs/_archive/`. Design sources: `SOURCE.md` only.

## pnpm.mdc

Stays `alwaysApply: true`. This harness cannot prove Cursor glob fire on a bare `pnpm add`. A miss would allow npm.

## Reinstall

`git pull && FORCE=1 bash scripts/install.sh`

Re-paste `shared/rules/USER-RULES.paste.txt`. New chat.
