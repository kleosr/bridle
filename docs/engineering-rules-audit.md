# Engineering Rules Audit — kleosrules

**Repository:** kleosr/kleosrules v18.0.0  
**Audit date:** 2026-09-03  
**Auditor role:** Staff systems audit (local proof only)  
**Decision doc:** `docs/engineering-rules-decision.md`  
**Research:** `docs/research/agent-instructions-research.md`

## Executive summary

| Severity | Count fixed | Count open |
|----------|-------------|------------|
| P0 | 0 | 0 |
| P1 | 2 | 0 |
| P2 | 2 | 0 |
| P3 | 0 | 1 (README badge HTML typo — pre-existing, not changed) |

**P1 fixed:** (1) `doctor.sh` required live `~/.cursor` install → now uses isolated fixture HOME; (2) no uninstall path → `scripts/uninstall.sh` + lifecycle tests.

**CLAUDE.md:** Not added — zero verified consumers (`rg -i claude` → 0).

---

## Consumer map (high level)

```
Cursor IDE / Cloud Agent
  ├─ reads ~/.cursor/hooks.json (global) OR repo .cursor/hooks.json (Lane-A cloud)
  ├─ spawns ./hooks/*.sh with JSON stdin
  ├─ loads User Rules (manual paste) + ~/.cursor/rules/*.mdc
  ├─ loads skills on demand from ~/.cursor/skills/*
  └─ may inject repo AGENTS.md (cloud_instructions / workspace context)

fleet_sync.sh install
  ├─ writes ~/.cursor/{hooks,rules,skills,agents}
  └─ symlinks pack/.cursor/rules/types.mdc

scripts/doctor.sh + tests/run.sh
  └─ validate pack integrity (fixture HOME for install checks)

.github/workflows/gates.yml
  └─ CI: install + doctor + tests (ubuntu + macos)
```

**Not consumers:** Claude Code (no CLAUDE.md), Copilot native config files, Gemini, hooks themselves (hooks enforce; they don't read AGENTS.md).

---

## Hook event matrix

| Event | Input (stdin JSON) | Script | Decision path | Exit | Agent-visible output | failClosed | Timeout | Tests |
|-------|-------------------|--------|---------------|------|---------------------|------------|---------|-------|
| sessionStart | `workspace_roots`, `composer_mode`, `conversation_id` | `session_start.sh` | plan mode → `{}`; NOW extract → grep secret_tokens → emit context or `{}` | 0 | `additional_context` or `{}` | false | 10s | fixtures.sh, plan_mode.sh, hook_edges (token skip) |
| beforeSubmitPrompt | `prompt` / aliases | `before_submit_prompt.sh` | jq parse fail → continue false; secret grep → false; else true | 0 | `continue`, optional `user_message` | false | 10s | fixtures, gauntlet, hook_edges |
| beforeShellExecution | `command` | `before_shell.sh` → `shell_gate.sh` | fleet install allow; destructive deny; infra ask; complexity deny; source-write deny; secrets deny; else allow | 0 | `permission`, messages | false | 30s | gauntlet (40+ cases) |
| beforeReadFile | `file_path` | `before_read_file.sh` | secret_paths.ere match → deny; else `{}` | 0 | `permission` deny or `{}` | **true** | 10s | gauntlet |

**Cloud Lane-A** (`hooks.cloud.json`): beforeShellExecution, beforeReadFile, beforeSubmitPrompt only — no sessionStart (avoids double NOW inject).

---

## Inventory table (canonical artifacts)

| Path | Consumer | Scope | Activation | Purpose | Side effects | Failure behavior | Security | Context cost | Tests | Status | Decision |
|------|----------|-------|------------|---------|--------------|------------------|----------|--------------|-------|--------|----------|
| `AGENTS.md` | Cursor cloud agent, humans, CI | repo root | session / clone | Handbook SSOT | none | n/a | none | ~2–3k tok if injected | CI existence | **canonical** | keep |
| `shared/*/AGENTS.md` | agents browsing subtrees | nested | on open | bridge `@../../AGENTS.md` | none | n/a | none | minimal | none | **bridge** | keep |
| `CLAUDE.md` | — | — | — | — | — | — | — | — | — | **absent** | do not add |
| `.cursorrules` | — | — | — | — | — | — | — | — | — | **absent** | do not add |
| `shared/rules/USER-RULES.paste.txt` | human → Cursor User Rules | global user | manual paste | charter floor | none | n/a | no secrets in file | ~1.5k tok always | doctor grep | **canonical** | keep |
| `shared/rules/agent.mdc` | Cursor rules engine | ~/.cursor/rules | alwaysApply | harness capsule | install copy | n/a | references SECURITY | ~1k tok | gauntlet install | **canonical** | keep |
| `shared/rules/ponytail.mdc` | Cursor | global alwaysApply | always | lean ladder | install | n/a | low | ~400 tok | fixtures_more | **canonical** | keep |
| `shared/rules/complexity.mdc` | Cursor | global | always | cyclomatic roof | install | n/a | low | ~300 tok | install test | **canonical** | keep |
| `shared/rules/vibe.mdc` | Cursor | global alwaysApply (since 2026-09-03) | always; silent without package.json | stack router | install | n/a | low | ~700 tok | grounding | **canonical** | keep |
| `shared/rules/next.mdc` | Cursor | glob | next dep | Next API law | install | n/a | low | on match | none | **scoped** | keep |
| `shared/rules/vite.mdc` | Cursor | glob | vite projects | Vite law | install | n/a | low | on match | none | **scoped** | keep |
| `shared/rules/astro.mdc` | Cursor | glob | astro | Astro law | install | n/a | low | on match | none | **scoped** | keep |
| `shared/rules/postgres.mdc` | Cursor | glob SQL | schema paths | Postgres law | install | n/a | medium | on match | none | **scoped** | keep |
| `shared/rules/testing.mdc` | Cursor | glob tests | test files | test roof | install | n/a | low | on match | none | **scoped** | keep |
| `shared/rules/pnpm.mdc` | Cursor | glob package | pnpm fields | supply chain | install | n/a | medium | on match | doctor | **scoped** | keep |
| `shared/rules/types.mdc` | Cursor | glob types | project only | type discipline | pack `.cursor/rules` symlink | none | n/a | on match | install test | **scoped** | keep |
| `shared/hooks/hooks.json` | Cursor | ~/.cursor | IDE load | 5-event registry | install copy | invalid JSON breaks hooks | medium | tiny | fixtures, doctor | **canonical** | keep |
| `shared/hooks/hooks.cloud.json` | Cursor cloud | repo `.cursor` | cloud agent | 3-event registry | project-hooks | same | medium | tiny | gauntlet | **canonical** | keep |
| `shared/hooks/session_start.sh` | Cursor hook runner | global | sessionStart | NOW inject | writes `state/mode` | quiet on error paths | skips token-like NOW | 40 lines max inject | many | **enforcement** | keep |
| `shared/hooks/before_submit_prompt.sh` | Cursor | global | submit | secret block | none | continue false parse/secret | blocks tokens | per prompt | many | **enforcement** | keep |
| `shared/hooks/before_shell.sh` | Cursor | global | shell | gate wrapper | none | deny/ask/allow JSON | destructive block | per command | gauntlet | **enforcement** | keep |
| `shared/hooks/before_read_file.sh` | Cursor | global | read | secret deny | none | failClosed true | blocks .env/pem; missing policy / non-JSON deny | per read | gauntlet, gate_edges | **enforcement** | keep |
| `shared/hooks/stop.sh` | Cursor | global | stop | Ponytail churn followup | none | `{}` or `followup_message` | cannot refuse completion | per turn | grounding | **enforcement** | keep |
| `shared/hooks/lib/diff_gate.sh` | stop.sh | internal | sourced | rewrite / format / duplicate | none | followup text | not file size | n/a | grounding | **library** | keep |
| `shared/hooks/lib/shell_gate.sh` | before_shell | internal | sourced | policy logic | none | emit JSON | steel; separators do not bleed | n/a | gauntlet, gate_edges | **library** | keep |
| `shared/hooks/lib/common.sh` | all hooks | internal | sourced | emit helpers, NOW extract | state paths | jq dependent | none | n/a | fixtures | **library** | keep |
| `shared/hooks/fleet_sync.sh` | human/CI | install time | CLI | install/sync/verify | writes ~/.cursor | exit 2 usage | no network | n/a | gauntlet, lifecycle | **installer** | keep |
| `scripts/install.sh` | human | install | exec | wrapper to fleet_sync | same | same | same | n/a | lifecycle | **installer** | keep |
| `scripts/uninstall.sh` | human | uninstall | exec | remove owned artifacts | rm ~/.cursor parts | skip if no fingerprint | preserves custom rules | n/a | lifecycle | **installer** | **added** |
| `scripts/doctor.sh` | human/CI | verify | exec | 16+ checks | temp fixture dir | exit 1 on fail | no secret read | n/a | lifecycle | **harness** | **fixed** |
| `shared/skills/*/SKILL.md` | Cursor skills | on demand | `/skill` or Read | procedures | symlink install | n/a | low | on invoke | verify_smoke | **workflow** | keep |
| `shared/agents/{hunter,cut,prove}.md` | Cursor subagents | on demand | @agent | review workflows | copy to ~/.cursor/agents | n/a | hunter readonly | on invoke | doctor | **workflow** | keep |
| `NOW.md` | session_start | repo local | sessionStart | session memory | none | skip if secrets in tail | no secrets | 40 lines inject | fixtures | **state** | keep |
| `SECURITY.md` | rules/skills/humans | reference | cited | cyber SSOT | none | n/a | canonical | on cite | doctor | **canonical** | keep |
| `docs/ARCHITECTURE.md` | agents/humans | reference | Read | 5-layer model | none | n/a | none | on Read | none | **doc** | keep |
| `docs/TOOLCHAIN.md` | agents/humans | reference | Read | verify commands | none | n/a | none | on Read | none | **doc** | keep |
| `docs/CURATOR.md` | agents | reference | Read | curation | none | n/a | none | on Read | none | **doc** | keep |
| `docs/DECISIONS/hooks-architecture.md` | humans | ADR | Read | history | none | n/a | none | on Read | none | **doc** | keep |

---

## Activation reality: what the agent actually sees (verified 2026-09-03)

Commands: `grep -m1 alwaysApply shared/rules/*.mdc`; `ls ~/.cursor/rules .cursor/rules`; `echo '{"composer_mode":"agent","workspace_roots":["/workspace"]}' | bash shared/hooks/session_start.sh`.

| Surface | Local IDE after `scripts/install.sh` | Cloud agent on this repo (this VM) | Enforced by |
|---------|--------------------------------------|-------------------------------------|-------------|
| `ponytail.mdc`, `agent.mdc`, `pnpm.mdc` (alwaysApply) | loaded from `~/.cursor/rules` | **not loaded** — `~/.cursor/rules` absent; pack `.cursor/rules` holds only `types.mdc` by design (test: "install prunes alwaysApply from pack .cursor/rules") | Cursor rules engine |
| Glob rules (`vibe`, `complexity`, `types`, …) | on path match | only `types.mdc` on path match | Cursor rules engine |
| Grounding ("Read this codebase first, then declare") | `agent.mdc` + User Rules paste | **User Rules paste only** (if the operator pasted it) + root `AGENTS.md` | law, not hook |
| Skills (`ponytail`, `testing`, …) | on demand: Cursor lists SKILL.md `description`; agent reads when task matches, or `/name` | same, only if `~/.cursor/skills` exists → **not available on cloud** | agent judgment; no hook |
| `sessionStart` injection | NOW.md active sections only | n/a (cloud has no sessionStart) | `session_start.sh` |
| Hooks inject `.mdc` or skills? | **No** (ARCHITECTURE.md: "Do not re-inject ponytail at sessionStart") | no | — |
| "unslop" skill | **not in this pack** — `premium-ui-craft/sources.md` cites an external pstack plugin path only | — | — |

Defects found by this check:

| Finding | Sev | Status |
|---------|-----|--------|
| `NOW.md` Proof injected stale evidence ("122 PASS") every session | P2 | **fixed** (NOW.md updated to 148) |
| Cloud agents on the pack get no `ponytail`/`agent` law from `.mdc` | P2 | **decided (a): accept.** Cloud relies on User Rules paste + root `AGENTS.md`. Rejected: (b) symlink alwaysApply into pack `.cursor/rules` — double-loads locally, breaks 2 tests; (c) copy law into `AGENTS.md` — duplicates canonical policy. Revisit only if cloud becomes the primary editor of this repo. |
| Grounding is unenforced (no `preToolUse`/`afterFileEdit`) | P3 | by design; enforcement would require registering a new event — architecture change, not a fix |

---

## Retired / absent (verified)

| Item | Evidence | Decision |
|------|----------|----------|
| HANDOFF.md | doctor check; migrated to NOW.md | stay retired |
| lean_gate, stop_gate, pre_tool_use | doctor + grep law files | stay removed |
| mario-engineering-team.mdc | doctor + retired.txt | stay removed |
| Rust kleos-gate | doctor | stay removed |
| native-lean-autoload.mdc, debugging.mdc duplicate | doctor + install prune tests | stay removed |

---

## Conflicts and duplication

| Conflict | Severity | Resolution |
|----------|----------|------------|
| Root AGENTS.md vs nested adapters | P3 | Adapters are bridges only; no duplicate policy text |
| agent.mdc vs USER-RULES paste (five hooks) | P2 | Intentional: paste=charter, agent.mdc=operational capsule; overlapping hook list acceptable |
| ponytail.mdc vs ponytail skill | P2 | By design: mdc=roof, skill=procedure |
| Global vs project hooks double sessionStart | P1 | Pack never installs repo hooks on itself; cloud omits sessionStart |
| doctor vs CI agent env ~/.cursor | P1 | **Fixed:** fixture HOME |

---

## Complexity (changed files)

| File | Lines | Cyclomatic (approx) | Note |
|------|-------|---------------------|------|
| `scripts/doctor.sh` | ~200 | ≤10 | surgical edit; fixture block added |
| `scripts/uninstall.sh` | ~55 | ≤5 | **fixed** `${FORCE:-0}` |
| `tests/hook_edges.sh` | ~40 | ≤3 | removed non-deterministic interruption test |
| `tests/install_lifecycle.sh` | ~75 | ≤5 | captured exit codes; array-derived hook count |
| `shared/hooks/lib/shell_gate.sh` | 96 | >10 | **unchanged**; library gate; decomposition deferred |

No changed file >400 lines.

---

## Portability

| Platform | Tested | Evidence |
|----------|--------|----------|
| Linux | **yes** | This audit VM: doctor 0; see validation section for test PASS count |
| macOS | **CI only** | `.github/workflows/gates.yml` gauntlet-macos |
| Windows native | **no** | Hooks require Bash; install.ps1 not executed here |
| WSL (Windows) | **partial** | `windows_hooks_rewrite.jq` tested in gauntlet.sh |

---

## Traceability

Lifecycle traceability (`item → consumer → discovered → selected → loaded → injected → applied → enforced → reported → evidence → status`) lives in `docs/runtime-grounding-audit.md` (2026-09-03). The table below is the finding-level trace from this audit.

| Finding | Sev | Decision | Files | Tests | Status |
|---------|-----|----------|-------|-------|--------|
| doctor fails without live ~/.cursor | P1 | fixture HOME + info for live | `scripts/doctor.sh` | install_lifecycle | **fixed** |
| no uninstall | P1 | fingerprint uninstall script | `scripts/uninstall.sh` | install_lifecycle | **fixed** |
| missing hook malformed tests | P2 | hook_edges.sh | `tests/hook_edges.sh` | run.sh | **fixed** |
| missing install idempotency proof | P2 | lifecycle tests with captured exit codes | `tests/install_lifecycle.sh` | run.sh | **fixed** |
| tautological lifecycle/hook tests | P1 | assert observed exit codes/counts; delete fake interruption test | `tests/install_lifecycle.sh`, `tests/hook_edges.sh` | run.sh | **fixed** |
| uninstall aborts under set -u when FORCE unset | P1 | `${FORCE:-0}` + directory-skill test | `scripts/uninstall.sh` | install_lifecycle | **fixed** |
| AGENTS.md as code / CODEOWNERS | P3 | record only; out of scope | — | research row 14 | **deferred** |
| CLAUDE.md absent | — | do not add | — | rg proof | **closed** |
| shell_gate complexity >10 | P3 | keep; single module | — | gauntlet | **accepted** |

---

## Validation evidence (final)

Commands run on Linux audit VM after all changes:

```bash
chmod +x shared/hooks/*.sh shared/hooks/lib/*.sh scripts/*.sh tests/*.sh
bash -n shared/hooks/*.sh shared/hooks/lib/*.sh   # exit 0
bash scripts/doctor.sh                             # exit 0
bash tests/run.sh                                  # see PASS count below; exit 0
git diff --check                                   # exit 0 (no conflict markers)
```

Double install + uninstall: covered in `tests/install_lifecycle.sh` via isolated `$HOME` temp dirs — **does not mutate agent `~/.cursor`**.

Hook signal interruption: **not tested** — no deterministic observable outcome in this harness.

Latest Linux run after PR #27 review fixes: `bash tests/run.sh` → **PASS:148 FAIL:0 exit 0** (148 = prior 142 − 2 tautological + 8 new lifecycle assertions).

---

## Unsupported claims / unresolved risks

- Windows PowerShell install path not executed on hardware this run  
- Cursor nested AGENTS.md `@` include resolution not officially documented for all IDE versions  
- Skill route names (`/ponytail`) depend on Cursor skill UI  
- Live `~/.cursor` checksum drift check only runs when kleosrules fingerprint present (optional info otherwise)
- Hook interruption under SIGTERM/SIGINT: not tested in harness (no deterministic observable)

---

## Normal engineer workflow (after)

1. Clone kleosrules
2. Paste `USER-RULES.paste.txt` → Cursor User Rules
3. `FORCE=1 bash scripts/install.sh` (or platform installer)
4. `bash scripts/doctor.sh` — passes in CI/agent env without preinstalled hooks
5. Work with five hooks + NOW.md
6. `bash tests/run.sh` before PR
7. To remove: `bash scripts/uninstall.sh` (keeps unrelated `~/.cursor` files)
