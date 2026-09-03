# Decision: one instruction architecture for kleosrules

Date: 2026-09-03. Status: accepted, implemented on `cursor/engineering-rules-audit-1f88`. Evidence: `docs/engineering-rules-audit.md`; sources: `docs/research/agent-instructions-research.md`.

## Do we need `CLAUDE.md`?

**No.**

- Consumer check: nothing in this repository is read by Claude Code. There is no `.claude/`, no Claude hook config, no CI step, no document that names it as a supported tool. CI runs Cursor's hook contract only.
- Official behaviour: Claude Code "reads CLAUDE.md, not AGENTS.md" and supports `@path` imports; Cursor reads `AGENTS.md` (root and nested) as plain markdown and documents no import syntax. A `CLAUDE.md` bridge therefore has exactly one purpose — serving Claude Code — and that consumer is absent.
- Cost of adding one anyway: a second always-loaded rulebook to keep in sync, with no test able to prove it is ever read.
- Guard: `scripts/doctor.sh` and `tests/audit.sh` fail if `CLAUDE.md`, `.cursorrules`, or `.claude/` appear. Adding Claude Code later means: one `CLAUDE.md` containing `@AGENTS.md` and nothing else, a test that Claude Code is actually configured, and an update to this file.

The same reasoning removed the four nested `AGENTS.md` files: their first line was Claude's `@../../AGENTS.md` import idiom, inert under Cursor, and the rest duplicated `shared/config/skills.txt` and the installer's `GLOBAL` list.

## The architecture

| Layer | Artefact | Consumer | Activation | Owns |
|---|---|---|---|---|
| Identity | `shared/rules/USER-RULES.paste.txt` → Cursor User Rules (manual paste) | Cursor Agent | every prompt, every project | who the agent is; session protocol summary; model lock. Owner-locked: not thinned by tooling. |
| Repository handbook | `AGENTS.md` (root, the only one) | Cursor Agent | every chat in this repo | what this repo is, where law/skills/workflows live, verification loop |
| Always-on roofs | `~/.cursor/rules/{agent,ponytail,pnpm}.mdc` (installed from `shared/rules/`) | Cursor user rules, `alwaysApply: true` | every prompt | loop discipline, LOC ladder, pnpm |
| Scoped roofs | `~/.cursor/rules/{vibe,complexity,testing,next,vite,astro,postgres}.mdc` | Cursor user rules, `globs` | matching file in context | stack-specific hard rules |
| Project rule | `.cursor/rules/types.mdc` (pack symlink; copied to opt-in `scan.roots`) | Cursor project rule | glob | type discipline where the project wants it |
| Procedures | `~/.cursor/skills/<name>` → `shared/skills/<name>/SKILL.md` | Cursor skills | on demand (`/name`, Read) | how-to; never always-on policy |
| Specialists | `~/.cursor/agents/{hunter,cut,prove}.md` | Cursor subagents | when launched | isolated review with a fixed I/O contract |
| Enforcement | `~/.cursor/hooks.json` + `hooks/{session_start,before_submit_prompt,before_shell,before_read_file}.sh` + `policy/*.ere` | Cursor user hooks | 4 events | secrets, destructive shell, source-write-via-shell, lint bypass; NOW.md injection |
| Cloud enforcement | `hooks.cloud.json` written into a target repo by `fleet_sync.sh project-hooks` | Cursor project hooks (cloud VMs cannot see `~/.cursor`) | 3 events | same steel minus sessionStart; never into this pack |
| Memory | `NOW.md` | `session_start.sh` | every non-plan session | bounded state (≤40 lines injected) |
| Security SSOT | `SECURITY.md` | humans, agents on demand | linked | the one steel table + pnpm fields |

Precedence (official Cursor): Team → Project → User rules; nested AGENTS.md more-specific-wins. Inside this pack the only project rule is `types.mdc` and there is one `AGENTS.md`, so no intra-pack conflicts exist. Hooks are not rules: they run regardless of rules and never rewrite prompts (`updated_input` banned; `preToolUse` unregistered).

## Rejected alternatives

- **Keep nested `AGENTS.md` as Cursor-native scoped instructions.** Rejected: their content was lists already owned by config files; nothing directory-specific remained once the import line was dropped. Re-add one only when a subtree needs an instruction the root cannot express.
- **Move always-on roofs into `AGENTS.md`.** Rejected: the roofs are user-global (they apply in every repo the owner works in); `AGENTS.md` is repo-scoped. Different scope, different file.
- **Convert `.mdc` `globs` arrays to comma-separated strings to match the docs example.** Rejected for now: arrays work in practice and `next.mdc` uses brace patterns that a comma split would break. Recorded as `unknown` (F-16).
- **Make `before_shell.sh` `failClosed: true`.** Rejected: a hook crash would freeze every shell command; the documented fail-open plus explicit `ask` on unreadable payloads gives the same safety for the realistic failure (schema drift) without locking the IDE on a `jq` outage.

## What "done" means for this architecture

`bash tests/run.sh` (175 fixtures incl. malformed payload, missing policy, broken `jq`, install×2, uninstall) exit 0; `bash scripts/doctor.sh` exit 0 on an installed machine; `git diff --check` clean; tree clean after tests. Platforms proven: Linux (this run), macOS (CI). Windows/WSL: unproven, labelled.
