# Architecture: 5 Layers & Deterministic Containment

kleosrules V2 uses the 5 Layers framework. Layers nest; they do not replace each other. When something breaks, fix the layer whose unit failed.

| # | Layer | Unit | kleosrules Implementation |
|---|-------|------|---------------------------|
| 1 | Prompt | Input | User message. The model remembers nothing before this call. |
| 2 | Context | Window | `HANDOFF.md` (tail 15), `before_submit_prompt.sh` classify. |
| 3 | Harness | Pass | Cursor + Bash hooks + tools. Without `stop_gate`, you only have an API. |
| 4 | Loop | Run | `stop_gate.sh` audits `Done-when`. Auto-brakes stop early exits. |
| 5 | Graph | Job | Obsidian vault (Markdown + wikilinks). Shared durable state. |

## Preventive Amnesia

Cursor reasons in a window that dies. Obsidian keeps what must survive. Bash hooks force a read of `hot`/`index` and a write of `Session`/`hot` so the next chat is not blank.

## Injection vs Declaration

1. **Injection (Layer 2):** `before_submit_prompt.sh` adds route duties through `additional_context`. It must not mutate the user prompt (`updated_input` is banned).
2. **Declaration (Layer 1/4):** Thin INTENT — one OBJECTIVE, optional local CONSTRAINTS, deterministic Done-when (≤5 anchors). Never rewrite the user prompt.
3. **Audit (Layer 3):** `stop_gate.sh` checks markers, thin-roof caps (`hooks/policy/intent.json`), and `Done-when: met`.

## Runtime map

- **Muscles:** Bash scripts under `/hooks` (event hooks max 80 LOC each; fail-closed where registered).
- **Policy (wired only):** `hooks/policy/intent.json` + `hooks/policy/lean.json`.
- **Brain:** Obsidian via MCP. No local datasets, no Rust binaries.
- **State:** Ephemeral files in `/state/` (gitignored). Cleared each run.
