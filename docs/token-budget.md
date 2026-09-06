# Always-on token budget

Ponytail counterexample: this pack refuses to dump law and state into every turn. Caps live in `tests/token_budget.sh`. Rough tokens = bytes / 4.

## What loads every local session

| Surface | Why it loads | What the test locks |
|---------|--------------|---------------------|
| `USER-RULES.paste.txt` | Cursor User Rules (manual paste; cloud floor) | byte cap + labeled roof restatement only |
| 7 alwaysApply `.mdc` | `~/.cursor/rules` after install | count = 7; sum + `agent.mdc` caps |
| `session_start.sh` inject | `additional_context` | path to NOW.md; no body dump |
| `AGENTS.md` | this repo / cloud handbook | byte cap (navigator) |

Skill `description` lines are routers (catalog tax). Bodies load on demand. `tests/token_budget.sh` caps each description.

Hooks other than sessionStart do **not** inject always-on context. They emit `continue` / `permission` / one `followup_message` on violation. Steel stays.

## Caps (regression)

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

Fail if someone adds an alwaysApply rule, fattens paste/`agent.mdc`, copies a roof `.mdc` body into paste, or dumps NOW.md again.

## Before → after (2026-09-06, master vs this change)

| Surface | Before B | ~tok | After B | ~tok |
|---------|----------|------|---------|------|
| paste | 4324 | 1081 | 3813 | 954 |
| alwaysApply sum | 9334 | 2334 | 7727 | 1932 |
| `agent.mdc` | 3040 | 760 | 1545 | 387 |
| `vibe.mdc` | 1267 | 317 | 1155 | 289 |
| NOW.md file | 2648 | 662 | not injected | — |
| sessionStart inject | 2038 | 510 | 57 | 15 |
| `AGENTS.md` | 2183 | 546 | 2201 | 551 |
| **session always-on** (paste+mdc+inject) | **15696** | **3924** | **11597** | **2900** |

Re-run: `bash tests/run.sh` (prints the after table).

## pnpm.mdc stays alwaysApply

`pnpm.mdc` is ~894 B on every turn, including Bash/docs. Glob/intelligent apply would be nicer **if** we could prove Cursor still fires it on `pnpm add` when `package.json` is not already in context. This harness cannot observe the rules engine. A missed apply would silently allow npm. Leave `alwaysApply: true`. Do not flip it without an observable fire test.

## Cloud vs local

Cloud on this pack does not load `~/.cursor/rules`. Paste is the cloud floor: charter headings stay; roof numbers are a labeled restatement of the four `.mdc` files. Local pays paste + `.mdc`. That double-tax is the short restatement, not a second copy of the roof bodies.

## Reinstall

`git pull && FORCE=1 bash scripts/install.sh`

Re-paste `shared/rules/USER-RULES.paste.txt` into Cursor Settings → User Rules (install cannot write Settings). New chat so rules reload.
