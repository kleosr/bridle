# Agent Instructions — Bounded Research Notes

**Date:** 2026-09-03  
**Purpose:** Hypothesis input for kleosrules audit. **Not exhaustive.** Recommendations adopted only where local repo proof exists (see `docs/engineering-rules-decision.md`).

**Popularity is not proof.** None of the sources below changed repository behavior without local evidence.

## Queries run

1. Cursor hooks official documentation (fetched on this VM)
2. Claude Code CLAUDE.md overview (fetched on this VM)
3. AGENTS.md open standard (agents.md, GitHub comparisons)
4. Exa MCP web search — rate-limited; primary URLs fetched directly instead
5. X posts — **operator-supplied** (retrieved outside this VM via X API, 2026-09-02/03); this cloud VM has **no X API access**

## Exclusions

- Paywalled / login-only content not retrieved
- Duplicate blog posts restating AGENTS.md marketing copy
- Vendor telemetry or prompt-dump services

## Limitations

- Cursor docs snapshot 2026-09-03; hook event list may grow
- Claude Code docs describe `CLAUDE.md`; **no verification that kleosrules uses Claude Code**
- Community AGENTS.md adoption counts not independently verified
- **Windows/WSL installer:** correct-by-construction, **not executed on this Linux CI VM**
- **macOS:** covered by CI job `gauntlet-macos`; not re-run locally on this agent VM
- **This cloud VM has no X API access** — X rows 10–15 are operator-supplied citations, not agent-retrieved

## Source table (20 rows)

| # | URL | Publisher | Accessed | Claim (exact) | Category | Confidence | Local hypothesis / test | Inclusion reason |
|---|-----|-----------|----------|---------------|----------|------------|---------------------------|------------------|
| 1 | https://cursor.com/docs/agent/hooks | Cursor | 2026-09-03 | “Hooks are spawned processes that communicate over stdio using JSON” | enforcement | high | Hooks must emit JSON; `tests/run.sh` fixture tests | Primary hook contract (VM fetch) |
| 2 | https://cursor.com/docs/agent/hooks | Cursor | 2026-09-03 | Cloud agents: `sessionStart` deferred; user `~/.cursor/hooks.json` not available in cloud VMs | scope | high | Pack uses `hooks.cloud.json` (3 events) for Lane-A | Explains cloud vs local split |
| 3 | https://cursor.com/docs/agent/hooks | Cursor | 2026-09-03 | `failClosed: true` blocks action on hook crash/timeout/invalid JSON | security | high | `beforeReadFile` failClosed true; submit/shell false | Informs failClosed matrix |
| 4 | https://cursor.com/docs/agent/hooks | Cursor | 2026-09-03 | `sessionStart` output may include `additional_context` | injection | high | `session_start.sh` emits NOW.md sections | Verified in fixtures |
| 5 | https://cursor.com/docs/agent/hooks | Cursor | 2026-09-03 | `beforeSubmitPrompt` output `continue: true\|false` | enforcement | high | `before_submit_prompt.sh` secret block | Verified in fixtures |
| 6 | https://cursor.com/docs/agent/hooks | Cursor | 2026-09-03 | User hooks cwd is `~/.cursor`; project hooks cwd is project root | install | high | `hooks.json` uses `./hooks/*.sh` globally | Matches `fleet_install.sh` |
| 7 | https://docs.anthropic.com/en/docs/claude-code/overview | Anthropic | 2026-09-03 | “`CLAUDE.md` is a markdown file you add to your project root that Claude Code reads at the start of every session” | vendor-bridge | high | `rg CLAUDE` in kleosrules → 0 consumers | **Reject CLAUDE.md for this repo** |
| 8 | https://agents.md/ | AGENTS.md initiative | 2026-09-03 | “Create an AGENTS.md file at the root… nearest file in the directory tree… closest one takes precedence” | handbook | medium | Root + nested adapters match pattern | Supports root canonical + nested bridges |
| 9 | https://github.com/agent-rules/agent-rules | agent-rules | 2026-09-03 | “Agents MUST check for `AGENTS.md` in the project root” | handbook | medium | CI `test -f AGENTS.md` | Aligns with handbook role |
| 10 | https://x.com/tobi/status/2092259436538495186 | Tobi Lutke (operator-supplied) | 2026-08-25 | “I'm thinking about banning Claude code at Shopify until they change their mind and read AGENTS.md and .agents/skills etc. Insisting on only reading CLAUDE.md sometimes leads to split brain problems when different team members use different tools.” | practitioner | high | Split-brain = multiple tools in one repo; kleosrules has zero Claude consumers → supports reject-CLAUDE.md | Hypothesis support only |
| 11 | https://x.com/josevalim/status/2088889755933040759 | José Valim (operator-supplied) | 2026-08-16 | Claude Code PRs to the Elixir repo are worse because it does not read AGENTS.md | practitioner | medium-high | Relevant only if outside contributors use Claude Code here; unproven future trigger to revisit | Recorded; no repo change |
| 12 | https://x.com/pablostanley/status/2086113007009165352 | Pablo Stanley (operator-supplied) | 2026-08-08 | CLAUDE.md as a one-line `@AGENTS.md` bridge | practitioner | medium | No Claude consumer in kleosrules → bridge not adopted | Hypothesis only |
| 13 | https://x.com/dani_avila7/status/2087857760088064390 | Daniel San (operator-supplied) | 2026-08-13 | Instruction files keep growing because adding a rule is easy and deleting requires proving nothing breaks | opinion | medium | Maps to context-cost column in audit inventory | Cost awareness; no new files added |
| 14 | https://x.com/loftwah/status/2085872860556636216 | Loftwah (operator-supplied) | 2026-08-07 | “AGENTS.md is acting as code, AGENTS.md is an entrypoint” | opinion | medium | P3 finding: consider CODEOWNERS on root AGENTS.md — **out of scope this PR** | Recorded severity P3; not implemented |
| 15 | https://x.com/AtMemX/status/2093597279819038795 | AtMemX (operator-supplied) | 2026-08-29 | “Instructions are probabilistic. Hooks are deterministic.” | opinion | medium | Maps to law (.mdc/skills) vs steel (five hooks) split in `docs/ARCHITECTURE.md` | Hypothesis support only |
| 16 | kleosrules `shared/rules/agent.mdc` | kleosr | 2026-09-03 | “Cursor documents 21 hook events. This pack registers four” | policy | high | `hooks.json` keys length 4 | Local canonical |
| 17 | kleosrules `docs/ARCHITECTURE.md` | kleosr | 2026-09-03 | Law / state / feedback three channels | architecture | high | No hook injects ponytail at sessionStart | Local canonical |
| 18 | kleosrules `tests/run.sh` | kleosr | 2026-09-03 | Full fixture suite PASS on Linux (count verified each run) | proof | high | Re-run after each fix; see audit validation section | Local proof |
| 19 | kleosrules `scripts/doctor.sh` + `scripts/uninstall.sh` | kleosr | 2026-09-03 | Fixture HOME doctor; fingerprint uninstall with `${FORCE:-0}` | test-harness | high | `install_lifecycle.sh` | Fixes P1 false-fail + partial uninstall |
| 20 | — | This audit VM | 2026-09-03 | **This cloud VM has no X API access.** Rows 10–15 are operator-supplied (retrieved outside this VM, 2026-09-02/03). | limitation | n/a | X cannot be re-fetched or verified from this environment | Accurate access boundary |

## X / web → local adoption gate

| External claim | Adopted? | Local proof |
|----------------|----------|-------------|
| Add CLAUDE.md for all agent repos | **No** | Zero repo consumers; Tobi split-brain supports single-tool Cursor pack |
| AGENTS.md at repo root | **Yes** | CI + handbook + cloud_instructions |
| Nested AGENTS.md with precedence | **Yes (bridges)** | 4 adapters `@../../AGENTS.md` |
| Cursor global hooks in ~/.cursor | **Yes** | `fleet_sync.sh install`, fixture tests |
| failClosed on secret read | **Yes** | `before_read_file.sh` + fixture |
| CLAUDE.md as `@AGENTS.md` bridge | **No** | No Claude consumer |
| AGENTS.md needs CODEOWNERS | **No (P3 recorded)** | Out of scope |

## Citations (stable)

- Cursor Hooks: https://cursor.com/docs/agent/hooks  
- Claude Code overview: https://docs.anthropic.com/en/docs/claude-code/overview  
- AGENTS.md initiative: https://agents.md/  
