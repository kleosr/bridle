# Engineering rules audit — kleosrules

Date: 2026-09-03. Branch audited: `master` @ `6a1bb0a`. Repaired on `cursor/engineering-rules-audit-1f88`.
Method: every claim below was traced to a consumer (Cursor official docs fetched 2026-09-03, see `docs/research/agent-instructions-research.md`), to an installer line, to a test, or reproduced with a fixture. Items that could not be proven are labelled `unknown`.

## 1. Repository facts

| Item | Evidence |
|---|---|
| Canonical branch | `master` (CI `on.push.branches: [master, main]`). |
| Languages / shells | Bash 3.2+ (hooks, installers, tests), PowerShell 5.1 (Windows installer + shim), jq. No package manager in use (`package.json` only wraps scripts; no lockfile, no deps). |
| CI | `.github/workflows/gates.yml`: `ubuntu-latest` and `macos-latest` (stock `/bin/bash`), runs `fleet_sync.sh all`, `doctor.sh`, `tests/run.sh`. No Windows job. |
| Consumers present | Cursor only. `rg -i 'claude|codex|copilot|gemini|\.cursorrules'` over the tree: zero consumer references before the audit (only "handoff" as a word). No `CLAUDE.md`, `.claude/`, `.cursorrules`, `GLOBAL-RULES.md`, `HANDOFF.md`. |
| Baseline validation | `bash tests/run.sh` → exit 0, 122 PASS. `bash scripts/doctor.sh` → exit 1 on a machine without `~/.cursor/hooks.json` (by design), 63 ok. `git status` after `tests/run.sh`: **`M NOW.md`** — the suite rewrote NOW.md without its trailing newline (finding F-09). |

## 2. Core questions

1. **Do we use Claude Code anywhere?** No. No Claude Code configuration, hook, CI step, or document references it. The only Claude-shaped artefacts were four nested `AGENTS.md` files whose first line was `@../../AGENTS.md` — that is Claude Code's `@path` import syntax (Claude docs, "Import additional files"). Cursor reads `AGENTS.md` as plain markdown and documents no import syntax; nested files are already "combined with parent directories". The line was inert text copied from a Claude idiom.
2. **Why would we need `CLAUDE.md`?** We would not. Claude Code "reads CLAUDE.md, not AGENTS.md" (official), so a `CLAUDE.md` bridge is justified only when Claude Code is a consumer. It is not. Decision: none. Enforced by `scripts/doctor.sh` and `tests/audit.sh` (fail if `CLAUDE.md`, `.cursorrules`, or `.claude/` appear without a decision update).
3. **Do we need every file?** No. Removed: 4 nested `AGENTS.md` adapters, `lib/shell_fleet.sh`, `tests/conversation_state.sh` + its fixture, the `state/` mechanism. Everything else has a traced consumer (section 3).
4. **Classification** — section 3, column "Status".
5. **System or slogans?** The enforcement layer (4 hooks, 2 `.ere` policies, `hooks.json`) is a real, testable system: every decision path now has a fixture (allow, deny, ask, malformed, missing dependency, missing policy). The guidance layer (`ponytail.mdc`, `agent.mdc`, paste) contains observable checks (LOC ladder numbers, "cite `bash tests/run.sh` green", "no `any`", cyclomatic cap 10) plus some adjectives ("smallest diff", "quality bar"). Adjective-only lines are not enforceable and are documented as guidance, not policy (section 5).
6. **Explainable / testable / installable / updatable / removable?** Yes after this change. Before it there was no uninstaller and no idempotency test.

## 3. Inventory

Columns: Consumer · Scope / activation · Purpose · Side effects · Failure · Security · Cost · Tests · Status · **Decision** · Evidence.

### 3.1 Instruction files

| Path | Consumer | Activation | Purpose | Cost | Tests | Status | Decision | Evidence |
|---|---|---|---|---|---|---|---|---|
| `AGENTS.md` (root) | Cursor Agent (project root AGENTS.md, official) | every chat in this repo | repository handbook | 65 lines / 4.6 KB per session | CI `test -f AGENTS.md`; doctor: exactly one AGENTS.md | canonical | **keep, change** (add uninstall, docs pointers, consumer statement) | Cursor rules doc: "Cursor supports AGENTS.md in the project root and subdirectories." |
| `shared/{config,hooks,rules,skills}/AGENTS.md` | Cursor nested AGENTS.md (when files in that dir are in context) | working in that subtree | "thin adapter" `@../../AGENTS.md` + a list duplicating `skills.txt` / `GLOBAL` array | 4 × ~8 lines, loaded on top of the parent it "imports" | none | duplicated + contradictory (Claude import syntax, no Claude consumer; content restates `shared/config/skills.txt` and `fleet_sync.sh GLOBAL=()`) | **remove** | Claude memory doc: `@path` import is Claude Code syntax. Cursor doc: nested files are combined with parents automatically, so the import line adds nothing and the lists are second sources of truth. Test: `tests/audit.sh` "exactly one AGENTS.md". |
| `shared/rules/USER-RULES.paste.txt` | Cursor User Rules (manual paste) | every Agent chat, all projects | identity charter + session protocol | 46 lines / 3.4 KB per prompt | doctor stale-name grep | canonical (user floor; charter forbids thinning) | **keep** | README setup step; charter text "Do not replace, summarize, thin". Not editable by this audit by the owner's own rule. |
| `shared/rules/agent.mdc` | Cursor user rule (`~/.cursor/rules`, `alwaysApply: true`) | every prompt | autonomous loop, before-write declaration | was 49 lines / 2.5 KB; now 42 / 1.9 KB per prompt | install test, doctor stale grep | canonical, partially duplicated | **change** (drop hook table duplicated in paste + SECURITY.md + ARCHITECTURE + ADR + README; drop unverifiable "Cursor documents 21 hook events"; drop `/state/`) | Same table appeared in 5 files; `SECURITY.md` is the declared SSOT for steel. |
| `shared/rules/ponytail.mdc` | Cursor user rule, alwaysApply | every prompt | LOC ladder, quality floors | 30 lines / 0.8 KB | fixtures_more: ladder numbers present | canonical | keep | Numbers are observable (80/120/300/700). Points to skill for procedure. |
| `shared/rules/pnpm.mdc` | Cursor user rule, alwaysApply | every prompt | pnpm only | 15 lines | install test | canonical | keep | `SECURITY.md` owns the field table; this is the always-on pointer. |
| `shared/rules/{vibe,complexity,testing,next,vite,astro,postgres}.mdc` | Cursor user rule, `globs` | when matching file is in context | stack-specific roofs | 15–32 lines each, only when attached | install test | canonical, scoped | keep | Glob syntax: Cursor docs show comma-separated strings; these use YAML arrays. Arrays are widely used and Cursor's own `/create-rule` accepts them, but the doc does not state it — **unknown**, unchanged (braces `{ts,tsx}` in `next.mdc` would break a comma-split string, so converting is riskier than leaving). |
| `shared/rules/types.mdc` | Cursor project rule (pack `.cursor/rules/types.mdc` symlink; copied to `scan.roots` repos) | glob | type discipline | 18 lines | install test "keeps types.mdc in pack" | canonical, project layer | keep | `SHARED=(types)` in `fleet_sync.sh`. |
| `shared/skills/*/SKILL.md` (10) | Cursor skills (`~/.cursor/skills/<name>` symlink) | on demand (`/name`, Read) | procedures | 0 per prompt; 20–83 lines when read | verify_smoke symlink target check | canonical | keep | `shared/config/skills.txt` is the list; each has one `.mdc` or router pointing at it. Design skills are Mario's taste system, invoked via `design-stack`. |
| `shared/skills/ponytail/{bans.txt,domains-ddd.md,fe-be-layout.md}`, `landing-page-design/SOURCE.md`, `premium-ui-craft/sources.md`, `redesign-existing-projects/SOURCE.md` | linked from their SKILL.md | on demand | references | 0 per prompt | none (prose) | canonical | keep | Referenced by name inside the skill body; `bans.txt` "fail-open if missing" is documented. |
| `shared/agents/{hunter,cut,prove}.md` | Cursor subagents (`~/.cursor/agents`) | when parent launches them | isolated review contracts with explicit input/output shape | 0 per prompt; 98–136 lines per launch | install test, verify_smoke | canonical | keep | Each is a distinct workflow (vuln/logic, over-build, verification) with a testable output table. |
| `NOW.md` | `session_start.sh` (Now/State/Limits/Proof/Next, `head -n 40`) | every non-plan session | bounded memory | ≤40 lines per session | fixtures.sh (inject, archive exclusion, token skip) | canonical | change (record this audit) | `extract_now` in `lib/common.sh`. |
| `SECURITY.md` | humans + agents (linked from paste, agent.mdc, pnpm.mdc) | on demand | pnpm + steel SSOT | 0 per prompt | doctor `onlyBuiltDependencies` grep | canonical | change (payload/rm rows) | |
| `docs/*.md` | humans | on demand | architecture, curator, toolchain, ADR | 0 | doctor/run.sh do not read | canonical | change (state removal, uninstall, failure table) | |

### 3.2 Hooks and policy

| Path | Consumer | Event | Side effects | Failure (before → after) | Tests | Decision |
|---|---|---|---|---|---|---|
| `shared/hooks/hooks.json` | Cursor user hooks (`~/.cursor/hooks.json`, cwd `~/.cursor`) | registers 4 events | none | — | fixtures, gauntlet, audit (numeric timeout on every entry) | keep |
| `shared/hooks/hooks.cloud.json` | Cursor project hooks written by `project-hooks` into another repo's `.cursor/` | 3 events (no sessionStart: cloud VMs cannot see `~/.cursor`) | none | two entries had no `timeout` → all have 10/30 | gauntlet, audit | change |
| `session_start.sh` | sessionStart | inject NOW.md | **wrote `state/<conversation_id>/mode` under the workspace root or `~/.cursor` on every session; nothing read it** → writes nothing | non-JSON: still injects (payload only used for mode/root) | fixtures, plan_mode, audit "no state/" | change |
| `before_submit_prompt.sh` | beforeSubmitPrompt | block secret-looking prompt | none | non-JSON → `continue:false` (already) | fixtures, gauntlet, audit | keep |
| `before_shell.sh` + `lib/shell_gate.sh` | beforeShellExecution | deny/ask/allow | none | non-JSON or no `command` → **silent allow** → `ask` + message | gauntlet (30 cases), audit (40 cases) | change |
| `before_read_file.sh` | beforeReadFile (`failClosed: true`) | deny secret paths | none | non-JSON → exit 5, no JSON, no message; **policy file missing → silent `{}` allow** → both `deny` + actionable message | gauntlet, audit | change |
| `lib/common.sh` | all hooks | root resolution, NOW extraction, JSON emitters | none | — | fixtures_more (`emit_ask` present) | change (remove dead `state_dir`, `extract_conv_id`) |
| `lib/shell_fleet.sh` | `before_shell.sh` early-allow for `bash scripts/install.sh` | — | none | — | gauntlet | **remove**: reproduced that `gate_shell_command` already allows those commands without it (dead bypass, one more execution path). |
| `policy/secret_paths.ere` | `before_read_file.sh`, `gate_shell_secrets` | `grep -qE -f` | none | missing → now deny on read | gauntlet, audit | keep |
| `policy/secret_tokens.ere` | `before_submit_prompt.sh`, `session_start.sh` | `grep -qE -f` | none | missing → continue:true / inject (fail-open, declared) | gauntlet | keep |
| `lib/fleet_*.sh`, `fleet_sync.sh`, `lib/windows_hooks_rewrite.jq` | installer only (never copied to `~/.cursor/hooks/lib`, test "does not copy fleet_install.sh") | — | writes `~/.cursor` | — | gauntlet, audit (install×2, uninstall) | change (uninstall, no `state`, retired loop) |

### 3.3 Installers, scripts, tests, config

| Path | Consumer | Decision | Evidence |
|---|---|---|---|
| `scripts/install.sh`, `MacOS/install.sh`, `Linux/install.sh` | humans/CI → `fleet_sync.sh install` | keep | CI runs `fleet_sync.sh all` on both OSes. |
| `scripts/uninstall.sh`, `fleet_sync.sh uninstall` | humans | **generate (new)** | No uninstall path existed (P1). Tested: removes owned files, keeps foreign, idempotent, leaves a non-owned `hooks.json`. |
| `scripts/sync.sh`, `fleet_sync.sh sync`, `shared/config/scan.roots`, `scan.ignore` | opt-in fleet copy of `types.mdc` | keep | `scan.roots` empty by default; verified portability check in verify_smoke. |
| `Windows/install.ps1`, `Windows/hooks/wsl-shim.ps1` | Windows users | change (drop `shell_fleet.sh`) | **untested**: no PowerShell here or in CI. Shim does not propagate the WSL exit code (`$LASTEXITCODE`) — recorded as `unknown` impact, not changed because it cannot be tested here. |
| `Windows/uninstall.ps1` | Windows users | generate (new, **untested**) | Mirror of `uninstall_home`; labelled in file header and README. |
| `scripts/doctor.sh` | humans/CI | change (drop `state/` check, stale-name paths of deleted adapters, add single-AGENTS.md / no-CLAUDE.md / no-shell_fleet checks, `scripts/*.sh` executable) | |
| `tests/run.sh` | CI | change | Backed up and rewrote NOW.md with `printf '%s'` (dropped trailing newline → dirty tree). Replaced by a `cksum` equality assertion. |
| `tests/conversation_state.sh`, `fixtures/sessionStart_conversation.json` | run.sh | **remove** | Tested the removed `state/<conv>` mechanism. |
| `tests/audit.sh` | run.sh | generate (new) | 53 branch fixtures (section 6). |
| `tests/{static_checks,fixtures,gauntlet,fixtures_more,plan_mode}.sh` | run.sh | keep / minor change (drop `state` assertions) | |
| `shared/config/{skills,retired,retired-skills}.txt` | fleet_install / sync_repos / verify | keep | `retired.txt` is now the only list verify_smoke consults (was duplicated in four hard-coded `if` blocks). |
| `.gitignore` | git | change (drop `state/`) | Stale entries `branch_structure.json`, `temp_*.bat`, self-ignore line left: P3, harmless, not in scope. |
| `.github/workflows/gates.yml` | GitHub Actions | keep | Pinned checkout SHA, `permissions: contents: read`. |
| `assets/*.svg`, `LICENSE`, `package.json` | README badges, license, script aliases | keep | `package.json` has no dependencies; scripts alias the bash entry points. |

## 4. Findings (severity → decision)

| ID | Sev | Finding | Reproduction | Decision | Changed files | Tests | Status |
|---|---|---|---|---|---|---|---|
| F-01 | P1 | `before_shell.sh` silently **allowed** when the payload was not JSON or had no `command` (`jq … \|\| true` → empty → `emit_allow`). A Cursor field rename would switch the whole gate off invisibly. | `printf 'not json' \| bash before_shell.sh` → `{"permission":"allow"}` | `ask` with an actionable message | `shared/hooks/before_shell.sh` | audit: 4 cases | fixed |
| F-02 | P1 | `before_read_file.sh` with `secret_paths.ere` missing returned `{}` (allow) although the hook is declared `failClosed: true`. Non-JSON payload exited 5 with no JSON and no message. | copy hook without `policy/` → `{}`; `printf 'not json'` → exit 5 | deny + message in both cases; explicit `{"permission":"allow"}` on the happy path | `shared/hooks/before_read_file.sh` | audit: 5 cases | fixed |
| F-03 | P1 | Source-write deny bypassed by quoted or backslash-escaped paths containing spaces (`echo x > "my file.ts"`, `> my\ file.ts`, `tee "src/a b.tsx"`). | `→ allow` | Path pattern accepts `'…'`/`"…"` tokens and `\ `; 11-branch `elif` chain became a 7-row pattern table (`gate_shell_source_write` cc 13 → 2; new `shell_writes_source` cc 3). Two redundant heredoc rows removed (the redirect row already matched them; test "heredoc redirect" proves it). | `shared/hooks/lib/shell_gate.sh` | audit: 9 cases + all 30 pre-existing gauntlet cases | fixed |
| F-04 | P1 | `session_start.sh` created `state/<conversation_id>/mode` in the **user's workspace root** (or `~/.cursor`) on every session. No consumer read it (grep: only the tests). Untracked litter in user repos; unbounded per-conversation directories. | run hook with `workspace_roots:[tmp]` → `tmp/state/c1/mode` | Remove state writing and the dead helpers; remove `~/.cursor/state` creation and `gitignore_state`. | `session_start.sh`, `lib/common.sh`, `lib/fleet_install.sh`, `lib/fleet_sync_repos.sh`, `.gitignore`, `agent.mdc`, `CURATOR.md`, `ARCHITECTURE.md`, tests | audit: 3 cases; plan_mode reduced | fixed |
| F-05 | P1 | No uninstaller. Install/update existed; removal of owned artefacts from `~/.cursor` was undocumented and impossible without hand-deleting. | `grep -r uninstall` → nothing | `fleet_sync.sh uninstall`, `scripts/uninstall.sh`, `Windows/uninstall.ps1`; owned-only semantics | `fleet_sync.sh`, `lib/fleet_install.sh`, `scripts/uninstall.sh`, `Windows/uninstall.ps1`, README, TOOLCHAIN, AGENTS.md | audit: 12 cases (install×2 identical tree, uninstall owned/foreign/idempotent/non-owned hooks.json) | fixed (Windows: untested) |
| F-06 | P2 | Nested `AGENTS.md` adapters used Claude Code `@import` syntax; Cursor has no such import; content duplicated `skills.txt` and the `GLOBAL` array; loaded on top of the parent they claimed to import. | Cursor + Claude docs | remove all four; doctor + test assert single AGENTS.md | 4 files, `scripts/doctor.sh` | audit, doctor | fixed |
| F-07 | P2 | `lib/shell_fleet.sh` early-allow was dead: `gate_shell_command` already allows `bash scripts/install.sh` / `fleet_sync.sh …`. One more runtime lib copied to every install. | sourced gate without it → ALLOW | remove; drop from `RUNTIME_LIBS` and `install.ps1` | `before_shell.sh`, `lib/fleet_install.sh`, `Windows/install.ps1` | gauntlet (still allows), audit (absent) | fixed |
| F-08 | P2 | `rm -rf /tmp/kleos-x`, `rm -rf /anything` denied (regex `rm -rf? /`); ordinary temp cleanup blocked. Meanwhile `rm -fr /var`, `rm -r -f /`, `rm -rf "/"`, `rm -rf $HOME`, `rm -rf .` were **allowed**. | probes above | Explicit target set: `/`, `/*`, `.`, `..`, `~…`, `$HOME…`, top-level system dirs; flag order/`-fr`/quotes handled | `lib/shell_gate.sh` | audit: 16 cases | fixed |
| F-09 | P2 | `tests/run.sh` rewrote `NOW.md` without its trailing newline → dirty tree after every run. | `git status` after tests | remove backup/restore; assert `cksum` unchanged | `tests/run.sh` | run.sh "tests did not modify NOW.md" | fixed |
| F-10 | P2 | `verify_smoke` hard-coded four retired rule names already listed in `shared/config/retired.txt` (two sources of truth). | read | loop over `retired.txt`; loop over `GLOBAL`/`PACK_AGENTS` for presence | `lib/fleet_verify.sh` | fleet `all` in fake HOME → `[ok] verify smoke` | fixed |
| F-11 | P2 | `agent.mdc` (always-on) restated the hook table that also lives in the paste, `SECURITY.md`, `ARCHITECTURE.md`, ADR, README, and asserted "Cursor documents 21 hook events" (unverifiable, and wrong against the current doc which lists 22 incl. Tab/workspaceOpen). | read | keep one pointer to `SECURITY.md`; drop the count | `shared/rules/agent.mdc` | doctor stale grep | fixed (−7 lines / −0.6 KB per prompt) |
| F-12 | P2 | `hooks.cloud.json` had no `timeout` on two entries (bounded runtime not declared). | jq | add 10s | `hooks.cloud.json` | audit "numeric timeout" | fixed |
| F-13 | P2 | README: "16 checks" (doctor runs ~65), `policy/ — *.ere deny lists + leftover json` (no json), tree omitted five lib files, `project-hooks` and cloud path undocumented, no uninstall, no consumer statement, WSL described as tested "on this machine". | read | rewrite the affected lines only | `README.md` | — | fixed |
| F-14 | P2 | `Windows/hooks/wsl-shim.ps1` does not forward the WSL exit code; a crashed hook looks like exit 0 with empty stdout. | static read | **no change** — cannot be tested here (no PowerShell/WSL, no Windows CI). Recorded as untested platform risk. | — | — | open (documented) |
| F-15 | P3 | `.gitignore` lists itself and two stale `temp_*.bat` names. | read | no change (harmless; outside finding scope) | — | — | no change |
| F-16 | P3 | `.mdc` `globs` use YAML arrays; Cursor doc shows comma-separated strings. | doc | no change; `unknown` whether arrays are officially supported; converting would break brace patterns in `next.mdc` | — | — | no change |
| F-17 | P3 | `composer_mode: "plan"` (quiet branch in `session_start.sh`) is not in Cursor's documented value set (`agent`/`ask`/`edit`). | doc | no change; harmless if never sent; kept as documented behaviour | — | plan_mode.sh | no change |
| F-18 | P3 | `beforeReadFile` payload without `file_path` is allowed silently (no `ask` exists for that event). | design | no change; documented in TOOLCHAIN failure table | — | — | no change |

## 5. Rule audit (guidance layer)

| Rule | Class | Consumer / scope | Observable check | Duplication removed | Verification |
|---|---|---|---|---|---|
| paste `Session Protocol` | context + policy | User Rules, every prompt | hook behaviours listed = `SECURITY.md` table | none possible (owner-locked) | manual read vs `SECURITY.md` |
| `agent.mdc` | workflow | user alwaysApply | "cite green `bash tests/run.sh` / `scripts/doctor.sh`"; "Change only files you actually opened" | hook table, event count, `/state/` | doctor stale grep |
| `ponytail.mdc` | policy | user alwaysApply | LOC 80/120/300/700; nesting ≤2; no `any` | — | fixtures_more greps the numbers |
| `pnpm.mdc` | policy | user alwaysApply | `pnpm` only; `Read SECURITY.md` before security keys | — | install test |
| `complexity.mdc` | policy | glob (code files) | lint cap (repo or 10); bypass denied by `before_shell.sh` | — | gauntlet: `complexity:off`, `--ignore C901` denied |
| `vibe/next/vite/astro/postgres.mdc` | context + policy | glob | detect stack from nearest `package.json`; hard bullets | — | none executable (prose); activation is Cursor's |
| `testing.mdc` | policy | glob (tests) | "Bug fix ships `regression: <symptom>`"; "Fail closed on red" | — | test names in this repo follow `regression:` |
| `types.mdc` | policy | project glob | "Do not add suppressions just to pass CI" | — | install test keeps it project-layer |
| Precedence | — | Cursor: Team → Project → User rules (official); nested AGENTS.md: more specific wins | pack has one project rule (`types`) and no nested AGENTS.md, so no intra-pack precedence conflicts remain | | |

Adjective-only lines that remain ("Smallest diff", "Prefer NO CODE", "quality bar") are guidance; they are not claimed as enforcement anywhere in the docs.

## 6. Hook matrix (event → input → decision → exit → agent-visible outcome)

| Event / hook | Input used | Allow | Block | Malformed | Missing dep (`jq`) | Missing policy | Timeout | Spaces/special chars | Repeat | Interrupt |
|---|---|---|---|---|---|---|---|---|---|---|
| `beforeShellExecution` / `before_shell.sh` | `.command` (fallback `.tool_input.command`) | `{"permission":"allow"}` (`ls`, `git status`, `rm -rf /tmp/x`, `pnpm add`) | `deny` destructive/source-write/secret-path/lint-bypass; `ask` infra/DB | `ask` + "run bash scripts/doctor.sh" | exit 127, no stdout → Cursor fail-open (`failClosed:false`, documented) | secret-path scan skipped, other gates run | 30 s (hooks.json); single-pass greps | quoted/escaped paths denied (F-03) | stateless | single JSON at end |
| `beforeReadFile` / `before_read_file.sh` | `.file_path` | `{"permission":"allow"}` | `deny` on `secret_paths.ere` match | `deny` + message | exit 127 → Cursor `failClosed:true` denies | `deny` + "run install" | 10 s | `/my dir/server.key` denied | stateless | single JSON |
| `beforeSubmitPrompt` / `before_submit_prompt.sh` | `.prompt` | `{"continue":true}` | `{"continue":false,…}` on token regex | `continue:false` | exit non-zero → fail-open | `continue:true` (declared fail-open) | 10 s | n/a | stateless | single JSON |
| `sessionStart` / `session_start.sh` | `.workspace_roots[0]`, `.composer_mode` | `additional_context` (≤40 lines) or `{}` | never blocks (Cursor ignores `continue` here) | inject anyway | exit non-zero → no inject | inject without token scan | 10 s | root with spaces handled (`cd "$wr"`) | stateless (no `state/` since F-04) | single JSON |

Exit-code note (official): 0 → use JSON; 2 → deny; other → fail-open unless `failClosed`. Hooks here always exit 0 with JSON on decided paths; only a missing/broken `jq` yields a non-zero exit, and the `failClosed` flag per event decides the outcome.

## 7. Context / runtime cost

Always-on per prompt (user layer): `agent.mdc` 1.9 KB (was 2.5) + `ponytail.mdc` 0.8 KB + `pnpm.mdc` 0.9 KB + paste 3.4 KB ≈ **7.0 KB** (was 7.6). Root `AGENTS.md` 4.6 KB per session in this repo (was 4.6 + up to 4 × ~0.4 KB nested). Glob rules attach only when matching files are in context (0.6–1.3 KB each). Skills and agents: 0 until invoked.

Runtime: each hook is one `jq` parse plus ≤ 9 `grep -E` passes over a ≤ few-KB string; no network, no loops over input, no file writes. Measured: `tests/run.sh` (175 fixtures, 5 fake-HOME installs) completes in ~3.5 s on the Linux runner.

## 8. Complexity (changed functions; method: 1 + `if/elif/while/for` + `case` arms + `&&`/`||`, per `docs` note in `tests/audit.sh` header)

| Function | File | Before | After | Note |
|---|---|---|---|---|
| `gate_shell_source_write` | `lib/shell_gate.sh` | 13 | 2 | 11-branch `elif` chain → pattern table |
| `shell_writes_source` (new) | `lib/shell_gate.sh` | — | 3 | loop over `SRC_WRITE_PATTERNS` + inline-write regex |
| `gate_shell_command` | `lib/shell_gate.sh` | 7 | 7 | `rm` scope moved into `RM_DESTRUCTIVE` inside the same alternation |
| `verify_smoke` | `lib/fleet_verify.sh` | 43 | 39 | linear checklist (depth 1); 4 hard-coded blocks → 1 loop over `retired.txt`. Still >15: it is a flat post-install checklist, each line one independent check with its own message; splitting it would only relocate lines. Documented, not gamed. |
| `uninstall_home_hooks` (new) | `lib/fleet_install.sh` | — | 7 | hooks.json + scripts + libs + policy |
| `uninstall_home` (new) | `lib/fleet_install.sh` | — | 7 | rules + skills + agents |
| `before_shell.sh` (script) | — | 5 decision points | 4 | bypass lib removed; two guard clauses |
| `before_read_file.sh` (script) | — | 2 | 4 | two guard clauses (F-02) |
| `session_start.sh` (script) | — | 7 | 6 | state block removed |

No changed function increased. No file in the repository exceeds 400 lines (largest: `tests/gauntlet.sh` 208, `scripts/doctor.sh` 204); every edit was a surgical edit.

## 9. Portability

| Platform | Evidence |
|---|---|
| Linux | This run: `bash tests/run.sh` exit 0 (175 PASS); `bash scripts/doctor.sh` exit 0 with a fake-HOME install; CI `ubuntu-latest`. |
| macOS | CI `macos-latest` with `/bin/bash` 3.2 (not re-run in this audit; no macOS here). Code uses no `mapfile`, `readlink -f`, `stat -c`, GNU `\b` (doctor enforces). |
| WSL / Windows | **untested**. `install.ps1`, `uninstall.ps1`, `wsl-shim.ps1` are not executed anywhere. F-14 open. |

## 10. Before / after architecture

Before: one root `AGENTS.md` + four nested pseudo-import adapters; hook table in six places; hooks with two silent-allow paths; a per-conversation `state/` side effect nobody read; install with no uninstall; a dead bypass library shipped to every machine.

After: one `AGENTS.md`; `SECURITY.md` is the single steel table (paste keeps its owner-locked summary); every hook decision path has a fixture and a message; hooks write nothing; `install`/`uninstall`/`verify` are three `fleet_sync.sh` verbs, idempotent and tested in a fake `HOME`.

Normal engineer workflow, before → after: `git clone; bash Linux/install.sh; paste User Rules` → same, plus `bash scripts/uninstall.sh` to leave cleanly and `git pull && FORCE=1 bash scripts/install.sh` to update (unchanged command, now proven idempotent).

## 11. Traceability

| Finding | Severity | Decision | Changed files | Tests | Status |
|---|---|---|---|---|---|
| F-01 payload silent allow | P1 | ask + message | `before_shell.sh` | audit ×4 | closed |
| F-02 read hook fail-open on missing policy / non-JSON | P1 | deny + message | `before_read_file.sh` | audit ×5 | closed |
| F-03 quoted-path source-write bypass | P1 | pattern table | `lib/shell_gate.sh` | audit ×9, gauntlet ×30 | closed |
| F-04 state litter | P1 | remove mechanism | 9 files | audit ×3, plan_mode | closed |
| F-05 no uninstaller | P1 | add | 7 files | audit ×12 | closed (Win untested) |
| F-06 nested AGENTS.md | P2 | remove | 5 files | audit, doctor | closed |
| F-07 dead bypass lib | P2 | remove | 3 files | audit, gauntlet | closed |
| F-08 rm scope | P2 | explicit targets | `lib/shell_gate.sh` | audit ×16 | closed |
| F-09 NOW.md churn | P2 | cksum guard | `tests/run.sh` | run.sh | closed |
| F-10 retired duplication | P2 | loop over SSOT | `lib/fleet_verify.sh` | fleet all | closed |
| F-11 agent.mdc duplication | P2 | trim | `agent.mdc` | doctor | closed |
| F-12 cloud timeouts | P2 | add | `hooks.cloud.json` | audit | closed |
| F-13 README drift | P2 | targeted lines | `README.md` | — | closed |
| F-14 shim exit code | P2 | no change | — | — | open, untested platform |
| F-15..F-18 | P3 | no change | — | — | recorded |

## 12. Validation commands (final run, after the last diff; Linux, bash 5.2, jq 1.7)

| Command | Exit | Result |
|---|---|---|
| `chmod +x shared/hooks/*.sh shared/hooks/lib/*.sh scripts/*.sh` | 0 | |
| `bash -n shared/hooks/*.sh shared/hooks/lib/*.sh scripts/*.sh tests/*.sh MacOS/install.sh Linux/install.sh` | 0 | |
| `bash tests/run.sh` | 0 | PASS 175 / FAIL 0 (baseline on `master`: 122, and it dirtied `NOW.md`) |
| `HOME=<tmp> FORCE=1 bash scripts/install.sh` (run twice) | 0, 0 | `find ~/.cursor \| sort` identical after both runs |
| `HOME=<tmp> bash shared/hooks/fleet_sync.sh verify` | 0 | `[ok] verify smoke` |
| `HOME=<tmp> bash scripts/doctor.sh` | 0 | `ALL CHECKS PASSED`, 76 ok, 0 fail |
| `HOME=<tmp> bash scripts/uninstall.sh` | 0 | only empty `agents/ rules/ skills/` directories remain under the fake `~/.cursor`; foreign files kept (asserted in `tests/audit.sh`) |
| `git diff --check` | 0 | |
| `git status --short` after tests | — | only intended changes; no `state/`, no `NOW.md` churn |
| `shellcheck` | — | not installed on this runner; CI installs it and `tests/static_checks.sh` reports warnings (non-fatal, unchanged policy) |
| macOS run | — | not executed here; CI `macos-latest` job is the evidence path |
| Windows/WSL run | — | not executed anywhere; labelled untested (F-14) |
