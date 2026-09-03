# Agent Instructions — Bounded Research Notes

**Date:** 2026-09-03  
**Purpose:** Hypothesis input for kleosrules audit. **Not exhaustive.** Recommendations adopted only where local repo proof exists (see `docs/engineering-rules-decision.md`).

## Queries run

1. Cursor hooks official documentation  
2. Claude Code CLAUDE.md overview  
3. AGENTS.md open standard (agents.md, GitHub comparisons)  
4. Exa MCP web search — **rate-limited**; primary URLs fetched directly instead

## Exclusions

- Paywalled / login-only content not retrieved  
- Duplicate blog posts restating AGENTS.md marketing copy  
- X/Twitter posts (no API access this run; category reserved for hypothesis only)  
- Vendor telemetry or prompt-dump services  

## Limitations

- Cursor docs snapshot 2026-09-03; hook event list may grow  
- Claude Code docs describe `CLAUDE.md`; **no verification that kleosrules uses Claude Code**  
- Community AGENTS.md adoption counts (e.g. “20k repos”) not independently verified  
- **Windows/WSL installer:** correct-by-construction, **not executed on this Linux CI VM**  
- **macOS:** covered by CI job `gauntlet-macos`; not re-run locally on this agent VM  

## Source table (max 20)

| # | URL | Publisher | Accessed | Claim (exact) | Category | Confidence | Local hypothesis / test | Inclusion reason |
|---|-----|-----------|----------|---------------|----------|------------|---------------------------|------------------|
| 1 | https://cursor.com/docs/agent/hooks | Cursor | 2026-09-03 | “Hooks are spawned processes that communicate over stdio using JSON” | enforcement | high | Hooks must emit JSON; `tests/run.sh` fixture tests | Primary hook contract |
| 2 | https://cursor.com/docs/agent/hooks | Cursor | 2026-09-03 | Cloud agents: `sessionStart` deferred; user `~/.cursor/hooks.json` not available in cloud VMs | scope | high | Pack uses `hooks.cloud.json` (3 events) for Lane-A | Explains cloud vs local split |
| 3 | https://cursor.com/docs/agent/hooks | Cursor | 2026-09-03 | `failClosed: true` blocks action on hook crash/timeout/invalid JSON | security | high | `beforeReadFile` failClosed true; submit/shell false | Informs failClosed matrix |
| 4 | https://cursor.com/docs/agent/hooks | Cursor | 2026-09-03 | `sessionStart` output may include `additional_context` | injection | high | `session_start.sh` emits NOW.md sections | Verified in fixtures |
| 5 | https://cursor.com/docs/agent/hooks | Cursor | 2026-09-03 | `beforeSubmitPrompt` output `continue: true\|false` | enforcement | high | `before_submit_prompt.sh` secret block | Verified in fixtures |
| 6 | https://cursor.com/docs/agent/hooks | Cursor | 2026-09-03 | User hooks cwd is `~/.cursor`; project hooks cwd is project root | install | high | `hooks.json` uses `./hooks/*.sh` globally | Matches `fleet_install.sh` |
| 7 | https://docs.anthropic.com/en/docs/claude-code/overview | Anthropic | 2026-09-03 | “`CLAUDE.md` is a markdown file you add to your project root that Claude Code reads at the start of every session” | vendor-bridge | high | `rg CLAUDE` in kleosrules → 0 consumers | **Reject CLAUDE.md for this repo** |
| 8 | https://agents.md/ | AGENTS.md initiative | 2026-09-03 | “Create an AGENTS.md file at the root… nearest file in the directory tree… closest one takes precedence” | handbook | medium | Root + nested adapters match pattern | Supports root canonical + nested bridges |
| 9 | https://github.com/agent-rules/agent-rules | agent-rules | 2026-09-03 | “Agents MUST check for `AGENTS.md` in the project root” | handbook | medium | CI `test -f AGENTS.md` | Aligns with handbook role |
| 10 | https://gist.github.com/0xfauzi/7c8f65572930a21efa62623557d83f6e | Community | 2026-09-03 | “Keep AGENTS.md under 150 lines when possible” | cost | low | Root AGENTS.md is 61 lines | Cost guidance only |
| 11 | https://github.com/nevir/agentfill/blob/e952a764/docs/Comparison.md | agentfill | 2026-09-03 | “Configuration fragmentation… CLAUDE.md, .cursorrules, GEMINI.md” | landscape | medium | kleosrules uses `.mdc` + paste, not `.cursorrules` | Confirms avoid duplicate vendor files |
| 12 | https://github.com/nevir/agentfill/blob/e952a764/docs/Comparison.md | agentfill | 2026-09-03 | Cursor “Basic support” for AGENTS.md | handbook | low | Not proven Cursor auto-loads AGENTS.md in all modes | Hypothesis; local proof = handbook + cloud_instructions |
| 13 | kleosrules `shared/rules/agent.mdc` | kleosr | 2026-09-03 | “Cursor documents 21 hook events. This pack registers four” | policy | high | `hooks.json` keys length 4 | Local canonical |
| 14 | kleosrules `docs/ARCHITECTURE.md` | kleosr | 2026-09-03 | Law / state / feedback three channels | architecture | high | No hook injects ponytail at sessionStart | Local canonical |
| 15 | kleosrules `tests/run.sh` | kleosr | 2026-09-03 | 142 fixture tests PASS on Linux | proof | high | Re-run after audit changes | Local proof |
| 16 | kleosrules `.github/workflows/gates.yml` | kleosr | 2026-09-03 | ubuntu-latest + macos-latest gauntlet | CI | high | Both run doctor + tests | Portability signal |
| 17 | kleosrules `Windows/install.ps1` | kleosr | 2026-09-03 | PowerShell + WSL jq rewrite of hooks.json | install | medium | Windows rewrite jq tested in `gauntlet.sh` | Partial Windows proof |
| 18 | kleosrules `scripts/doctor.sh` (post-fix) | kleosr | 2026-09-03 | Fixture HOME install verification | test-harness | high | exit 0 without live ~/.cursor | Fixes false P1 |
| 19 | kleosrules `scripts/uninstall.sh` | kleosr | 2026-09-03 | Removes fingerprinted kleosrules artifacts only | install | high | `install_lifecycle.sh` preserves custom.mdc | New local proof |
| 20 | — | X (Twitter) | — | *Not retrieved (no X MCP credits / not required for local proof)* | hypothesis | n/a | Skipped per bounded research rule | Listed as inaccessible |

## X / web → local adoption gate

| External claim | Adopted? | Local proof |
|----------------|----------|-------------|
| Add CLAUDE.md for all agent repos | **No** | Zero repo consumers |
| AGENTS.md at repo root | **Yes** | CI + handbook + cloud_instructions |
| Nested AGENTS.md with precedence | **Yes (bridges)** | 4 adapters `@../../AGENTS.md` |
| Cursor global hooks in ~/.cursor | **Yes** | `fleet_sync.sh install`, fixture tests |
| failClosed on secret read | **Yes** | `before_read_file.sh` + fixture |

## Citations (stable)

- Cursor Hooks: https://cursor.com/docs/agent/hooks  
- Claude Code overview: https://docs.anthropic.com/en/docs/claude-code/overview  
- AGENTS.md initiative: https://agents.md/  
