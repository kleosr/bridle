# Architecture: 5 Layers & Deterministic Containment

kleosrules V2 uses the 5 Layers framework. Layers nest; they do not replace each other. When something breaks, fix the layer whose unit failed.

| # | Layer | Unit | kleosrules Implementation |
|---|-------|------|---------------------------|
| 1 | Prompt | Input | User message. The model remembers nothing before this call. |
| 2 | Context | Window | `HANDOFF.md` (tail 15), `before_submit_prompt.sh` classify. |
| 3 | Harness | Pass | Cursor + Bash hooks + tools. Without `stop_gate`, you only have an API. |
| 4 | Loop | Run | `stop_gate.sh` audits `Done-when`. Auto-brakes stop early exits. |
| 5 | Graph | Job | Local Markdown files (`HANDOFF.md`). |

## Preventive Amnesia

Cursor reasons in a window that dies. `HANDOFF.md` keeps what must survive. Bash hooks force a read of HANDOFF tail at start and a seed of HANDOFF on stop-accept so the next chat is not blank.

## Injection vs Declaration

1. **Injection (Layer 2):** `before_submit_prompt.sh` adds route duties through `additionalContext`. It must not mutate the user prompt (`updated_input` is banned).
2. **Declaration (Layer 1/4):** INTENT job card in **chat prose before tools** (never Shell/Write/fence). OBJECTIVE=postcondition + `edit:`|`NEW:` tags; Done-when=≤5 decidable predicates. Finish all tags same turn. User prompt immutable.
3. **Audit (Layer 3):** `stop_gate.sh` checks **assistant prose only** (strips tool payloads + fences), thin-roof caps, FILE_MAP tags, drip reject, and `Done-when: met`.

## Runtime map

- **Muscles:** Bash scripts under `/hooks` (event hooks max 80 LOC each; fail-closed where registered). Core logic in `/hooks/lib/`.
- **Policy (wired only):** `hooks/policy/intent.json` + `hooks/policy/lean.json`.
- **Brain:** `HANDOFF.md` (local, always works).
- **State:** Ephemeral files in `/state/` (gitignored). Cleared each run.
