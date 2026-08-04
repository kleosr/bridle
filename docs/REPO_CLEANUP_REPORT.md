# Repository Cleanup Report

Date: 2026-08-04
Auditor: kleosr (lead maintainer pass)

## Inventory Summary

| Category | Count | Notes |
|----------|-------|-------|
| Tracked files | 97 | Excludes `.cursor/` and `state/` (gitignored) |
| Hook scripts | 7 | 4 event hooks + `lean_gate` + `pre_tool_use` + `fleet_sync` + `fleet_dispatch` |
| Hook configs | 2 | `hooks.json` + `hooks.project.json` — divergent, both miss `pre_tool_use.sh` |
| Policy files (wired) | 2 | `intent.json`, `lean.json` |
| Policy files (dead) | 5 | `.cursor/hooks/policy/{ask-scope,context,delete,secrets,shell}.json` — Rust-gate remnants |
| Project rules | 10 | `agent`, `context-curator`, `debugging`, `lean-code`, `native-lean-autoload`, `obsidian-memory`, `ponytail`, `testing`, `types`, `vernacular` |
| User rules | 2 | `USER-RULES.paste.txt`, `option-c-core.mdc` |
| Skills | 32 | Across architecture, lean, frontend, ship, voice |
| Docs | 6 | `ARCHITECTURE`, `TOOLCHAIN`, `CURATOR`, ADR, 2 retired evals |

## Classification

### DELETE — Dead/Stale/Retired
| File/Dir | Reason |
|----------|--------|
| `.cursor/hooks/policy/ask-scope.json` | Rust-gate remnant, never wired in V2 |
| `.cursor/hooks/policy/context.json` | Rust-gate remnant, vault-recall gate (MCP-first) |
| `.cursor/hooks/policy/delete.json` | Rust-gate remnant, never wired |
| `.cursor/hooks/policy/secrets.json` | Rust-gate remnant, never wired |
| `.cursor/hooks/policy/shell.json` | Rust-gate remnant, never wired |
| `.cursor/v14-rule-inject.json` | V14 artifact, 2 major versions behind |
| `.cursor/breakthrough-chain.md` | Experimental/research scratch |
| `.cursor/breakthrough-research.md` | Experimental/research scratch |
| `.cursor/HANDOFF.md` | Stale copy (sync destination artifact) |
| `.cursor/state/*` | Ephemeral runtime state (already gitignored) |
| `.cursor/hooks/*.sh` | Stale copies of canonical `hooks/*.sh` (fleet_sync regenerates) |
| `.cursor/hooks.json` | Stale copy of `hooks/hooks.project.json` (fleet_sync regenerates) |
| `docs/evals/MINIMAL-NATIVE-EXPRESSION-AUDIT.md` | Audit of deleted Rust `kleos-gate`; historical only |
| `docs/evals/UNIFIED-COUNTEREXAMPLE-TAXONOMY.md` | Audit of deleted Rust `kleos-gate`; historical only |

> **Note:** `.cursor/` is entirely gitignored. The files above are local artifacts, not tracked. They will be cleaned from disk but this doesn't affect the git repo. The `.cursor/` dir itself is the sync destination and will be repopulated by `fleet_sync.sh`.

### REFACTOR — MCP-First → Local-First
| File | Change |
|------|--------|
| `README.md` | Remove Obsidian/MCP as hard requirement; make optional |
| `AGENTS.md` | Remove "Obsidian MCP memory" from overview; local HANDOFF is brain |
| `HANDOFF.md` | Expand to bounded state file with compaction protocol |
| `user-rules/USER-RULES.paste.txt` | Remove vault/MCP as required; local HANDOFF is default memory |
| `user-rules/option-c-core.mdc` | Remove MCP as required; local HANDOFF is default |
| `rules/obsidian-memory.mdc` | Convert to optional local+MCP memory rule |
| `rules/agent.mdc` | Remove MCP hard reference |
| `rules/context-curator.mdc` | Remove vault_read as required step |
| `rules/native-lean-autoload.mdc` | Replace MCP memory with local HANDOFF |
| `hooks/session_start.sh` | Remove vault references from injected context |
| `hooks/before_submit_prompt.sh` | Remove vault write-back requirement from injected context |
| `hooks/stop_gate.sh` | Remove vault write-back from accept handler + HANDOFF template |
| `docs/ARCHITECTURE.md` | Graph layer = local Markdown files (Obsidian optional) |
| `docs/TOOLCHAIN.md` | Remove Obsidian MCP prerequisite |
| `docs/CURATOR.md` | Local HANDOFF is SSOT; Obsidian optional |

### MERGE — Deduplicate
| Source | Target | Reason |
|--------|--------|--------|
| `hooks/hooks.json` + `hooks/hooks.project.json` | `.cursor/hooks.json` (single canonical, fleet_sync generates) | Two configs diverge; one source of truth |

### KEEP — Core (unchanged or minor edits)
| File/Dir | Notes |
|----------|-------|
| `LICENSE` | MIT — preserved |
| `hooks/lean_gate.sh` | Core ponytail roof — upgrade in Phase 7 |
| `hooks/pre_tool_use.sh` | Core autonomy gate — keep |
| `hooks/fleet_sync.sh` | Install tooling — update references |
| `hooks/fleet_dispatch.sh` | Backlog dispatcher — keep |
| `hooks/policy/intent.json` | Wired policy |
| `hooks/policy/lean.json` | Wired policy |
| `rules/{ponytail,lean-code,debugging,testing,types,vernacular}.mdc` | Core rules — minor MCP scrub |
| `skills/*` | On-demand skills — leave as-is |
| `config/*` | Fleet config — leave as-is |
| `assets/*` | Brand SVGs — leave as-is |

## Assumptions

1. `.cursor/` is a **sync destination**, not source — confirmed by `.gitignore` and `fleet_sync.sh` logic. Local artifacts there can be cleaned.
2. The retired eval docs (`docs/evals/*`) have no operational value — they audit code that was deleted. Kept references in the ADR are sufficient.
3. `fleet_dispatch.sh` and `pre_tool_use.sh` are operational but not registered in `hooks.json` CI config — this will be fixed by merging configs and adding them.
4. Obsidian/MCP should remain as an **optional** capability (the skill stays, the user can wire it), but not a **required** one for the core framework.
5. `HANDOFF.md` replaces `wiki/hot.md` as the session-level state file when Obsidian is not present.

## Remaining Risks

- **Cursor hook API shape** may change; hooks validate stdin but rely on `messages`/`transcript`/`conversation` array shape for stop_gate.
- **Obsidian-dependent skills** (`obsidian-memory`, `codebase-memory`, `session-handoff`) still reference MCP — they become optional skills, not core requirements.
- **`fleet_sync.sh`** currently generates `~/.cursor/hooks.json` without `pre_tool_use.sh` in the event hook array — needs update.
