---
---
name: memory
description: >-
  Session continuity via HANDOFF.md. Optional Obsidian vault for long-term memory.
  ALWAYS at session start/end: read wiki/hot.md then wiki/index.md; ingest
  raw/ once; query wiki only. Mid-session durable facts, preCompact
  write-back (persist INTO vault), handoffs. Complements codebase-memory.
---

# Obsidian memory (fat skill)

Thin roof: `rules/obsidian-memory.mdc` (paths + amnesia).
This file = CallMcpTool workflows, ingest/query/lint, COMPLETE CAPTURE.
V2 harness: Bash `session_start` / `before_submit_prompt` / `stop_gate` (no Rust kleos-gate).


# Obsidian memory (kleosr — LLM Wiki / no amnesia)

Chat forgets. Context windows are not memory
([Dezo](https://x.com/0xDezo/status/2079595162955571339);
[Iolld](https://x.com/EvgeniyIolld/status/2081103929392169211)).
Pattern: **raw = source, wiki = compiled, continuous refeed**
([Karpathy](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f);
[kkai](https://x.com/0xkkai/status/2081005037992464894);
[Degen stack](https://x.com/Degen_calls_sol/status/2070846650780664143);
[Cyril/Kimi](https://x.com/cyrilXBT/status/2080397292339704294)).

| Lifecycle | Force |
|-----------|--------|
| sessionStart | Bash inject: amnesia + HANDOFF tail |
| beforeSubmitPrompt | Bash classify + thin INTENT duty |
| Mid-session | companion roofs; durable fact → COMPLETE vault_append |
| CODE write | Soft: vault_read hot\|index first (companions). Hard size: `lean_gate.sh` |
| Durable fact | same-turn `vault_append` (agent must) |
| Ops triad | **ingest → query → lint** (+ write-back) |
| Fleet | missing hub → refeed disk AGENTS/README/HANDOFF |
| stop | write-back Session + hot; mirror HANDOFF |

## Curator (Cursor-native)

Harness seeds + classifies the ask; agent deep-reads; vault stays SSOT. Not Neo4j.

1. **Force** — `session_start` / `before_submit_prompt` inject `additional_context` only.
2. **Agent** — thin INTENT; `search_simple` / targeted `vault_read` for next-action pages.
3. **Roof** — soft recall before CODE; hard lean LOC via `lean_gate.sh`; stop needs persist.
4. **Law** — `docs/ARCHITECTURE.md` + `docs/CURATOR.md` + companion `context-curator.mdc`.

Vault path: MCP `user-obsidian` (see companion). No pack-local `context.json` gate.

## Server

MCP: `user-obsidian` **(OPTIONAL)**. Vault: `/home/kleosr/rootsidian/kleosr`.

**If MCP configured and Obsidian running:**
Always `GetMcpTools` before `CallMcpTool`.
Durable facts → `vault_append`.

**If MCP not available:**
Fall back to `HANDOFF.md` for all durable facts.
Never invent vault state or call MCP tools.

## Graphs + layer stack

| Graph | Skill / MCP | Answers |
|-------|-------------|---------|
| Code / AST | `codebase-memory` | Callers, symbols, structure |
| Knowledge / intent | this skill / `user-obsidian` | Decisions, concepts, sessions |
| Work lineage | git / HANDOFF / Sessions | What changed; parent run |

Pack units (prompt→context→harness→loop→graph): `docs/ARCHITECTURE.md`.
Vault is the **knowledge graph** plane — not Neo4j unless asked.
Debug: fix the layer whose unit broke (one input / window / pass / run / job).
Process rule: fix rulebook/judge — not hand-patch agent output (`harness-retro`).

## Tools

| Need | Tool |
|------|------|
| List | `vault_list` |
| Search | `search_simple` |
| Read (+ backlinks) | `vault_read` |
| Map headings | `vault_get_document_map` |
| Create/overwrite | `vault_write` |
| Append (prefer) | `vault_append` |
| Surgical | `vault_patch` |
| Relocate | `vault_move` |

Prefer append/patch on living notes. Prefer search → targeted read over vault dump.

## Layout (complete LLM Wiki)

```
AGENT.md
raw/                         # never edit
  bootstrap/ research/ chats/ docs/
  processed/                 # after ingest (moved, not deleted)
wiki/
  hot.md                     # read FIRST
  index.md                   # master directory
  log.md                     # append-only ops timeline
  concepts/ entities/ sources/ catalogs/
  projects/<slug>/{Index,Map,Decisions,Learnings,Sessions/}
  journals/ audits/
instructions/
  PROCESSING.md
  AGENT-MEMORY.md
  MAX-MEMORY.md               # continuous fleet refeed
```

Fleet catalog in vault: `wiki/catalogs/Fleet.md`. Thread catalog: `wiki/catalogs/Second-Brain-Threads.md`.
Frontmatter: `type`, `project`, `status`, `tags`, `updated`.
Concept/entity/source pages: Summary, Key Points, Connections, Sources, Metadata.
**COMPLETE CAPTURE (universal):** every durable write-back must be complete enough
to recall and act without the chat or external URL — ingest products, sources
(FULL extract), concepts/entities, Decisions (options/why/residual), Learnings
(concrete bite + next action), Sessions (goal / what ran / evidence / outcomes /
open / residual), journals. Thin summary-only anywhere = defect.
`wiki/hot.md` may stay short **only** if it points at fat pages.
Cursor does not open X/web from wiki — the page body is the memory.
Law: vault `instructions/PROCESSING.md`.

## Loop (mandatory)

### Start — every chat with repo work

1. `vault_read` `wiki/hot.md`
2. `vault_read` `wiki/index.md` (or `search_simple`)
3. Open `wiki/projects/<slug>/Index.md` + latest Session (+ Decisions when choosing)
4. Then repo `AGENTS.md` / `HANDOFF.md`
5. Do **not** re-read all of `raw/` for answers

### Ingest — when `raw/` has new files (not under `processed/`)

Per `instructions/PROCESSING.md` **COMPLETE CAPTURE**: extract → check index → create/merge concepts/
entities/sources with **FULL body** (verbatim preferred) → `[[wikilinks]]` → update index + hot + **log** → move source
to `raw/processed/`. Never edit originals. URL + thin stub = defect — expand before Done.

### Query + write-back

Read hot → index → wiki pages only. Cite `[[links]]`. If thin, **expand the page
to COMPLETE** (or say what to add under `raw/`). Durable answers → complete
wiki page or Decisions/Learnings/Session (not vibe summaries) + log + hot refresh
(model is reasoning only; vault is memory).

### Fleet refeed (max memory)

If `wiki/projects/<slug>/` is missing for the repo in the workspace, read disk
README/AGENTS/HANDOFF/DEBT/TOOLCHAIN (skip secrets), upsert Index+Map+Decisions+Learnings,
update `wiki/catalogs/Fleet.md` + index + log. Never dump full source trees into the wiki
(AST = `codebase-memory`). Protocol: vault `instructions/MAX-MEMORY.md`.

### Lint (daily light / weekly full)

Orphans, dead links, contradictions, 90d stale, **summary-only pages of any
type** → `wiki/audits/YYYY-MM-DD.md` (weekly: `wiki/audits/YYYY-MM-DD-weekly.md`).
Ingest/lint law: vault `instructions/PROCESSING.md` + `instructions/AGENT-MEMORY.md`.

### During — same turn as the fact

- Decision → `Decisions.md` dated bullet with **why/options/residual** + `[[wikilinks]]`
- Learning → `Learnings.md` (failure mode + when it bites + next action)
- Continuity → `wiki/journals/YYYY-MM-DD.md` (resume-ready detail)
- Context shift → refresh `wiki/hot.md` (pointers to fat pages)
- New atomic idea → `wiki/concepts/<Name>.md` (actionable depth, not title-only)
- Status/article ingest → `wiki/sources/<Name>.md` with **FULL extract**, never link-only
- Any other durable fact from the turn → same COMPLETE depth into the right wiki page

### End / stop / handoff / model switch

1. `wiki/projects/<slug>/Sessions/YYYY-MM-DD-<topic>.md` — **complete** Session:

```markdown
## Goal
<!-- verified intent restatement -->

## Done-when
<!-- concrete exit criteria -->

## What ran
<!-- commands / paths -->

## Evidence
<!-- TOOLCHAIN / cargo / tests · frontend: npm run css+build verbatim, visual QA (screenshot / browser / motif state) -->

## Outcomes
<!-- what changed -->

## Open
<!-- leftover threads -->

## Residual
<!-- named uncertainty -->

## Layer check
| Layer | Evidence |
|-------|----------|
| Prompt | |
| Context | |
| Harness | |
| Loop | |
| Graph | |
```

2. Mirror repo `HANDOFF.md` at the same depth (skill `session-handoff`)
3. Refresh `wiki/hot.md` if the session changed “now”

### preCompact

Write-back **complete** Session + Decisions/Learnings **into** the vault before chat
context dies. This is max memory — chat amnesia without vault persist.
Never delete or empty wiki pages as “flush.” Never flush as a thin stub.

### Hard stops

- No secrets in vault. Never edit `raw/`.
- No new MCP servers; use `user-obsidian`.
- No mass `vault_delete` without exact user list.
- Vault ≠ TOOLCHAIN green.
- Ignoring recall/write-back roofs = defect (context drift / amnesia).
- **Summary-only write-back of any durable page** = defect — expand to COMPLETE before Done.

## Fleet

`session-handoff` · `ship-loop` · `codebase-memory` · companion `obsidian-memory.mdc`
· Bash `session_start` / `before_submit_prompt` / `stop_gate` memory roofs.
