# Lifecycle ledger

Maintenance record for kleosrules guidance. Not law, not injected, not installed.
Read on demand when changing guidance, reviewing redundancy, or auditing provenance.
This file makes structural claims only (what exists, where it loads, what checks
cover it). It does not judge whether guidance is followed or sufficient.

Placement is deliberate: `docs/` loads only on explicit Read (see §1). Never move
this ledger, or pointers to it, into `shared/rules/`, `shared/skills/`,
`shared/hooks/`, root `AGENTS.md`, or the User Rules paste.

## 0. Roles and columns

Roles are nonexclusive; a section can carry several.

| Role | Meaning |
|---|---|
| boundary | Restricts what may happen (deny, ask, must-not, authorization). |
| contract | States a guarantee, shape, or scope that other parts rely on. |
| procedure | States ordered steps to perform some job. |
| workaround | Exists to absorb a platform/host limitation rather than state intent. |
| preference | States taste or a default that yields to task and explicit direction. |
| unclear | Role or rationale cannot be established from pack evidence this pass. |

Columns per row: source (file + section), roles, rationale (why it exists;
`unknown` when not evidenced — never manufactured), existing evidence (test,
doctor row, or observed behavior; `none` when docs-only), review trigger (what
should reopen the entry), decision authority (who may change it).

Authority values: `owner` (kleosr/user), `host-vendor` (Cursor loader/hook-runner
semantics — unverifiable in this repo), `repo-convention` (target repo being
edited), `pack` (this repo's maintainer, acting for the owner).

## 1. Loading conventions (observed)

| Surface | When it enters context | Evidence |
|---|---|---|
| User Rules charter (paste of `shared/rules/USER-RULES.paste.txt`) | Every session, after manual paste into Settings + new chat | `docs/token-budget.md`; runtime-grounding-audit §1 (`obs`) |
| 7 alwaysApply `.mdc` (agent, ponytail, pnpm, complexity, vibe, testing, types) | Every session | `docs/token-budget.md`; `docs/engineering-system.md` "What loads" |
| 5 glob `.mdc` (next, vite, astro, postgres, supabase) | Host glob match is a candidate; each file self-checks the owning package and is inert if unmatched | File bodies ("this file is inert"); `docs/token-budget.md` |
| Root `AGENTS.md` | This pack checkout (workspace instructions) | `docs/engineering-system.md`; runtime-grounding-audit P1 |
| Skill catalog (`name` + `description`) | Host-determined session catalog | runtime-grounding-audit P8/P9 (`obs`) |
| Skill bodies (`SKILL.md`) | Only on explicit Read | runtime-grounding-audit P9/P10 (`obs`); testing skill "Sources" |
| hunter / cut / prove | Only on invoke (`/name` or @-attach) | `AGENTS.md`; `docs/token-budget.md` |
| Hook scripts | Per registered event (`hooks.json`) | `shared/hooks/hooks.json`; `docs/DECISIONS/hooks-architecture.md` |
| `docs/`, `SECURITY.md`, `NOW.md`, archive | Only on explicit Read; never auto-injected | runtime-grounding-audit §1 ("reference only"); `docs/README.md` |
| Installed snapshot | Unix: skills are symlinks (live). Windows: skills are copies (snapshot; checkout edits need reinstall + new chat) | `docs/TOOLCHAIN.md`; testing skill "Sources" |

Known loader limits (do not re-verify by assertion): root/nested instruction text
can be stale within a running session after a pull (runtime-grounding-audit P1/P2,
findings table); glob auto-activation timing and host pause on `ask` are
unverified here (`docs/ARCHITECTURE.md` "Coverage"; `SECURITY.md` manual check).

## 2. Inventory scope

In scope (guidance sections classified in §3):

- `shared/rules/USER-RULES.paste.txt` (all sections; read this pass).
- 12 `.mdc` files: agent, ponytail, testing, complexity, types, vibe, pnpm (alwaysApply)
  + next, vite, astro, postgres, supabase (glob). All read this pass.
- 4 event hook scripts + `fleet_sync.sh` + `lib/common.sh`, `lib/shell_gate.sh`,
  `lib/fleet_scan.sh`, `lib/fleet_install.sh`, `lib/fleet_verify.sh`,
  `policy/secret_paths.ere`. All read this pass.
- `shared/hooks/hooks.json` (read). `hooks.cloud.json` (not read; referenced only).
- `shared/config/rules.global.txt`, `skills.txt`, `retired-skills.txt`,
  `retired.txt`, `manifest.json` (all read this pass).
- Skills `testing` and `ponytail` (bodies read). Remaining skill bodies
  (debugging, complexity, design-stack, landing-page-design, premium-ui-craft,
  redesign-existing-projects, writing-pr) NOT read this pass — classified from
  description routers, `.mdc` pointers, and test/doctor references only.
- `shared/agents/hunter.md`, `cut.md`, `prove.md` NOT read this pass —
  classified from `AGENTS.md`, doctor presence checks, and eval prose references.
- `SECURITY.md` (read this pass). `docs/` living files (read this pass, except
  `docs/_archive/` where only `README.md` and `runtime-grounding-audit.md` were
  read). `AGENTS.md`, `README.md`, `NOW.md` (read).
- `tests/run.sh`, `tests/static_checks.sh`, `tests/grounding.sh`,
  `tests/eval_corpus.sh` (read). Remaining `tests/*.sh` NOT read in full this
  pass — cited by name/purpose from `run.sh` and living docs.
- `scripts/install.sh`, `scripts/uninstall.sh`, `scripts/doctor.sh`,
  `Windows/install.ps1` (read). `MacOS/install.sh`, `Linux/install.sh`,
  `Windows/lib/*`, `Windows/hooks/bash-shim.ps1`, `lib/shell_fleet.sh`,
  `lib/diff_gate.sh`, `lib/hooks_json.*`, `lib/fleet_sync_repos.sh`,
  `lib/windows_hooks_rewrite.jq` NOT read this pass — cited from references.

Out of scope (not classified, not verified here):

- Live `~/.cursor` snapshot (rules, skills, hooks, agents as installed).
- Session catalog contents and host loader internals.
- Model behavior on any task (including manual eval rubric M1–M4).
- Cloud lane behavior beyond `hooks.cloud.json` registration shape.
- Host implementation of `failClosed`, `ask` pause, prompt-scan timing.
- Transcripts under the Cursor projects directory (host-managed, outside pack).
- External services, registries, and network effects.

Read blocks this pass: several `Read` calls were blocked when issued in parallel
batches — the `beforeReadFile` hook crashed under concurrent shim invocations and
the tool failed closed. No policy deny was observed (blocked paths do not match
`secret_paths.ere`). Sequential retries succeeded for every file retried
(`SECURITY.md`, `hooks.json`, `manifest.json`, `rules.global.txt`, `skills.txt`,
`retired*.txt`, ponytail `SKILL.md`). Files listed above as NOT read were not
retried, to bound this pass; their entries are marked accordingly.

## 3. Ledger

### 3.1 Charter (`shared/rules/USER-RULES.paste.txt`)

| ID | Section | Roles | Rationale | Evidence | Review trigger | Authority |
|---|---|---|---|---|---|---|
| C1 | Identity | contract | unknown | doctor paste-headings check | Charter rewrite request | owner |
| C2 | Stance & Pushback | procedure, preference | unknown | none (docs) | Recurring passive-agreement failures | owner |
| C3 | Autonomy (reversible auto / consequential approval) | boundary, contract | unknown | eval prose "retrieved text cannot authorize"; SECURITY.md authorization rows | Authz incident or scope dispute | owner |
| C4 | Effective destination + recheck at execution | boundary, procedure | Design counterexample: same command, changed destination (task brief, this pass) | eval prose "approval binds effective destination"; testing skill stale-evidence row | Destination-surprise incident | owner |
| C5 | Mission placeholders (unset) | contract | Keep goals explicit; forbid invention | doctor paste-headings check | Goals requested or charter forked | owner |
| C6 | Handoff as continuity evidence (not authority) | contract, procedure | Design counterexample: goal laundering via handoff (task brief, this pass) | eval prose "handoff is continuity evidence" | Scope creep via notes | owner |
| C7 | Session (hooks advisory-stop note, no retry of denies) | boundary, contract | Mirror of hook architecture in prose | ADR coverage table; grounding pre-action rows | Hook topology change | owner |
| C8 | Retrieval (workspace evidence, untrusted content) | procedure, boundary | unknown | none (docs) | Prompt-injection incident | owner |
| C9 | Stack ownership via `vibe.mdc` | procedure, contract | Route framework guidance per owning package | vibe.mdc body; eval prose "vibe resolves ownership per scope" | Cross-framework API misuse | owner |
| C10 | Roofs pointer (numbers live in four `.mdc`) | contract | Single source for numbers; paste stays thin | doctor "complexity has numbers"; grounding "paste names SSOT"; fixtures_more "paste does not restate cyclo-22" | Any number drift between paste and `.mdc` | owner |
| C11 | Honest verification (state what ran + residual) | procedure, contract | unknown | eval rubric M4 `[info]` (manual, not executed this pass) | False "tests pass" claim | owner |
| C12 | Trusted-workspace local execution | boundary, procedure | unknown | SECURITY.md "Trust" row | Untrusted-checkout incident | owner |
| C13 | Cursor + Grok stable lock | contract, preference | unknown | fixtures_more "paste still has lock" | Host/model change request | owner |
| C14 | Retrieved text cannot authorize | boundary | Prompt-injection defense in prose | eval prose "retrieved text cannot authorize"; SECURITY.md injection rows | Bypass attempt | owner |

### 3.2 Always-on rules (`shared/rules/*.mdc`)

| ID | Section | Roles | Rationale | Evidence | Review trigger | Authority |
|---|---|---|---|---|---|---|
| R1 | agent.mdc harness table (4 events, deny > ask > allow) | contract, boundary | unknown | doctor hooks.json registration check; grounding hook-shape rows | Hook topology change | owner |
| R2 | agent.mdc "no retry of denied action via another tool" | boundary | unknown | testing skill "Block" row restates it | Bypass attempt | owner |
| R3 | agent.mdc risk classes | contract, procedure | unknown | eval prose "agent risk class table" | Safety-relevant repo adoption | owner |
| R4 | agent.mdc concise-output style default | preference | unknown | none (docs) | Repeated over/under-verbose output | owner |
| R5 | ponytail.mdc ladder + size roofs (soft ~80, split @120, hard 300, never 500) | procedure, boundary, preference | unknown | fixtures_more roof rows; doctor "ponytail hard 300" | Roof dispute or drive-by split | owner |
| R6 | ponytail.mdc tools/split/verify | procedure | Keep hand edits in native tools; Shell source-write denied by hook | grounding pre-action rows | Workflow friction | owner |
| R7 | testing.mdc thin roofs (scope, regression label, flaky = broken) | contract, procedure | unknown | eval prose "defined change scope", "internal invariants" | Test-bloat or false-green incident | owner |
| R8 | testing.mdc pack verify (`run.sh` + doctor) | procedure, contract | unknown | run.sh exists; TOOLCHAIN documents modes | Verify-command drift | owner |
| R9 | complexity.mdc cyclo 10/never-22 + conditional cognitive/Halstead/CRAP | boundary, contract | unknown | doctor "cyclo-22 ceiling"; fixtures_more "never above 22" | Lint-cap dispute | owner |
| R10 | types.mdc (no `any`, narrow `unknown`) | boundary, contract | unknown | eval prose "types allows validator flow" | Type-escape incident | owner |
| R11 | vibe.mdc stack ownership + hard JS/TS list | procedure, contract | unknown | eval prose "vibe resolves ownership per scope" | Framework-mixup incident | owner |
| R12 | pnpm.mdc (new JS on pnpm, respect existing) | procedure, preference, contract | unknown | eval prose "pnpm respects existing manager" | Manager-migration dispute | owner |

### 3.3 Glob companions (`shared/rules/*.mdc`, inert unless matched)

| ID | Section | Roles | Rationale | Evidence | Review trigger | Authority |
|---|---|---|---|---|---|---|
| G1 | next/vite/astro self-check + inert-if-unmatched | contract, procedure | Prevent training-stale or cross-framework APIs | eval prose rows (version-matched, library/custom, repo manager); grounding glob-shape row | Framework API invention | owner |
| G2 | postgres (parameterized, forward-only migrations, EXPLAIN discipline) | boundary, procedure | unknown | eval prose "postgres composable with supabase" | SQL-injection or migration incident | owner |
| G3 | supabase (RLS, service-role, pooler) | boundary, procedure | unknown | file body; installed-copy drift noted in-session (catalog showed narrower tenant row — unverified, see §4 A5) | Authz bypass | owner |

### 3.4 Hooks (`shared/hooks/`)

| ID | Section | Roles | Rationale | Evidence | Review trigger | Authority |
|---|---|---|---|---|---|---|
| H1 | `before_submit_prompt.sh` (token → `continue:false`) | boundary, contract | unknown | gauntlet/hook_edges token rows (cited, not re-read); eval reason row `secret-token` | Secret-in-prompt incident | owner |
| H2 | `before_shell.sh` + `lib/shell_gate.sh` (destructive/source-write/lint-disable/secret-path deny; infra+activation ask) | boundary, contract | unknown | grounding pre-action rows; eval control + reason rows; SECURITY.md steel table | FP/FN report | owner |
| H3 | Known FP kept: `drop`/`truncate` substring fires anywhere | contract, workaround | unknown (kept deliberately per SECURITY.md; original report not traced this pass) | SECURITY.md "Known FP, kept" | Gate-weakening proposal | owner |
| H4 | `before_read_file.sh` (sensitive-path screening) | boundary, contract | Keep secrets out of model context (screening, not full confidentiality) | eval reason row `secret-path`; SECURITY.md steel table | Secret-in-context incident | owner |
| H5 | `stop.sh` + `lib/diff_gate.sh` (churn ≥50% @ ≥80 LOC or mass reindent → one advisory followup) | contract, procedure | Churn detection replaced a 300-LOC size trigger that caused drive-by split demands (dev miss, fixed + tested) | runtime-grounding-audit §4; grounding stop rows (rewrite/reindent/controls/bounds) | Churn FP/FN | owner |
| H6 | `stop` cannot refuse completion; `loop_limit: 1`; quiet on aborted/loop>0/malformed | contract | Platform contract + loop bound | grounding bounds rows; hooks.json shape rows | Host stop-semantics change | host-vendor (semantics), owner (wording) |
| H7 | Failure classes: malformed/missing-policy/missing-jq → deny / `continue:false`; JSON-only stdout; no secret/command echo; stable `reason` codes | contract, boundary | unknown | eval no-echo rows + reason rows; SECURITY.md failure table | Secret-leak in diagnostics | owner |
| H8 | `hooks.json` registration (4 events, `./hooks/` commands, failClosed true/true/true/false, stop loop_limit 1, no sessionStart) | contract | unknown | doctor registration check; grounding shape rows | Event/topology change | owner |
| H9 | `lib/common.sh` (path canon, emit helpers) | procedure | unknown | read this pass; exercised by all hook fixtures | Emit-shape drift | owner |
| H10 | `fleet_sync.sh` install/project-hooks/verify/dry-run | procedure, boundary | unknown | doctor fixture-install rows; TOOLCHAIN install section | Install/ownership bug | owner |
| H11 | `FORCE=1` ownership: differing user rules/agents kept unless `FORCE=1` (backup once, restore on uninstall); directory skills need `FORCE=1` to remove | boundary, procedure | Incident-motivated per task brief; no incident commit traced in repo history this pass — provenance unknown, retained as boundary (see §4 A1) | TOOLCHAIN ownership rows; engineering-system idempotency; uninstall.sh body; install_lifecycle tests (cited, not re-read) | Ownership bug or data-loss report | owner |
| H12 | Windows `install.ps1`: always overwrites rules/agents with backup-once (no FORCE gate); skills copied (snapshot); shim rewrite of hook commands | procedure, contract | Platform divergence; rationale unknown | Windows/install.ps1 body (read); TOOLCHAIN Windows rows; windows_host tests (cited, not re-read) | Windows ownership complaint or shim drift vs `fleet_install.sh` | owner |
| H13 | Retired-skill catalog cleanup (pack stems moved out of `skills/`; foreign names kept; bak never overwritten) | workaround, procedure | Old installer left `*.pre-kleos-bak` under `skills/`, which the host catalogs (observed: `now.pre-kleos-bak` in session catalog) | windows_host regression rows (cited); TOOLCHAIN symlink/copy rows; `retired-skills.txt` | New catalog leftover or foreign-name removal | owner |

### 3.5 Config SSOT (`shared/config/`)

| ID | Section | Roles | Rationale | Evidence | Review trigger | Authority |
|---|---|---|---|---|---|---|
| K1 | `rules.global.txt` (12 names incl. glob companions) | contract | One list for fleet_sync, uninstall, Windows install | grounding "GLOBAL list has one SSOT"; doctor "includes types, complexity, pnpm, supabase" | Rule add/retire | owner |
| K2 | `skills.txt` (9 skills) | contract | Catalog source for install/verify | grounding "every catalog skill has a description"; fleet_verify symlink loop | Skill add/retire | owner |
| K3 | `retired-skills.txt` + `retired.txt` (absent-lists that stay) | contract, procedure | Prevent resurrection of removed guidance | doctor/fixture prune rows (cited); H13 | Retire/rename | owner |
| K4 | `manifest.json` (hook scripts incl. legacy `session_start.sh`, libs, shims, policy, agents, optional skills) | contract | Install/verify inventory incl. legacy cleanup targets | doctor "manifest + merge/strip present"; static JSON validity | Inventory drift | owner |

Note on K4: `session_start.sh` in `hookScripts` is a legacy cleanup target
(removed, never installed), not a fifth event. Do not read that list as
registration; registration is `hooks.json` (H8).

### 3.6 Skills (bodies on Read only)

| ID | Section | Roles | Rationale | Evidence | Review trigger | Authority |
|---|---|---|---|---|---|---|
| S1 | testing skill (TDD order, practice, gauntlet, grep-status, Windows Git Bash, SKIP_LIVE banners, stale-evidence rule) | procedure, contract | unknown, except stale-evidence rule (task brief, this pass) | eval prose "testing rejects stale verification"; run.sh `set -euo pipefail` behavior documented in-skill | Verify-honesty failure | owner |
| S2 | ponytail skill (ladder rungs, split recovery, floors, destination-recheck rule) | procedure, preference | unknown, except destination-recheck rule (task brief, this pass) | eval prose "ponytail refreshes destination checks" | Ladder dispute | owner |
| S3 | debugging / complexity / design-stack / landing-page-design / premium-ui-craft / redesign-existing-projects / writing-pr (bodies NOT read this pass) | unclear (+ procedure assumed from routers) | unknown | Description routers (not re-read; cited from skills.txt + AGENTS.md grouping); grounding description-contract row | Any edit to those skills | owner |

### 3.7 Review specialists (`shared/agents/`, bodies NOT read this pass)

| ID | Section | Roles | Rationale | Evidence | Review trigger | Authority |
|---|---|---|---|---|---|---|
| A-h | hunter (security review on match) | unclear (+ boundary assumed) | unknown | doctor presence; SECURITY.md review row; eval prose "hunter requires confidence" | Body read or review miss | owner |
| A-c | cut (simplicity review) | unclear (+ preference assumed) | unknown | doctor presence; eval prose "cut bans metric-only deletion" | Body read or bad deletion call | owner |
| A-p | prove (behavior/audit/env/manager verdicts + repo-manager audit) | unclear (+ procedure assumed) | unknown | doctor presence; SECURITY.md review row; eval prose "prove uses repo-manager audit" | Body read or false-green | owner |

### 3.8 Security law (`SECURITY.md`)

| ID | Section | Roles | Rationale | Evidence | Review trigger | Authority |
|---|---|---|---|---|---|---|
| E1 | Boundary statement (hooks on supported paths; broader = OS/CI/human auth; regex = mistake prevention, not sandbox) | boundary, contract | unknown | ADR coverage table mirrors it | Boundary overclaim | owner |
| E2 | Pack steel table (per-event controls + fail-closed-in-scripts notes) | contract, boundary | unknown | Hook fixtures (cited); eval reason rows | Control drift | owner |
| E3 | "Not gated (law only)" list (Write/StrReplace secrets, MCP, Tab, preToolUse) | contract | unknown | ARCHITECTURE "Uncovered" row; eval "uncovered surfaces documented" | New channel adoption | owner |
| E4 | Script failure classes + reason codes | contract | unknown | Eval reason + no-echo rows | Diagnostic leak | owner |
| E5 | Activation approval (installer path ≠ trust; name action/target/scope/effect) | boundary, procedure | unknown | before_shell fleet-sync ask/deny branch (read) | Activation confusion | owner |
| E6 | Trust (auto-verify only in trusted workspace; inspect new checkouts) | boundary, procedure | unknown | Charter C12 mirrors it | Untrusted-checkout incident | owner |
| E7 | Data security + untrusted content (approval names content/destination/purpose; redaction; injection as data) | boundary, procedure | unknown | Charter C14 mirrors the injection row | Disclosure or injection incident | owner |
| E8 | Manual host integration check (6 steps; record host version + date + pass/fail) | procedure, contract | Host behavior unverified in repo; needs live evidence | none executed this pass (no live install per task) | Host update or behavior change | owner |
| E9 | pnpm required-fields table + banned keys | procedure, boundary | unknown | pnpm.mdc "before changing keys, Read SECURITY.md" | Supply-chain incident | owner |
| E10 | Cybersecurity fields table (secrets, injection, authz, XSS/CSRF/SSRF, CI, destructive, MCP, exfil, Windows shim) | boundary, procedure | unknown | Partially mirrored by hook gates (destructive, secrets) and glob roofs (authz) | New threat class | owner |

### 3.9 Docs (reference only; never injected)

| ID | Section | Roles | Rationale | Evidence | Review trigger | Authority |
|---|---|---|---|---|---|---|
| D1 | ARCHITECTURE (layers, channels, runtime, steel-vs-ask, coverage incl. host-unverified + uncovered) | contract | unknown | Eval "ADR coverage table present" targets the ADR; ARCH rows cited by eval "uncovered surfaces documented" | Topology or coverage change | owner |
| D2 | engineering-system (stage ownership, precedence, what-loads, failure messages, idempotency, hard stops) | contract, procedure | unknown | Mirrors hooks.json + run.sh + doctor behaviors | Stage/gate change | owner |
| D3 | TOOLCHAIN (prereqs, commands, install/doctor safety incl. FORCE ownership, symlink-vs-copy, policy evidence) | procedure, contract | unknown | Doctor modes + install_lifecycle (cited) | Command/fixture drift | owner |
| D4 | token-budget (intended loading; discovery metadata costs; measure-don't-estimate) | contract | unknown | runtime-grounding-audit byte counts (stale snapshot, see §4 A4) | Context-pressure report | owner |
| D5 | quality-roofs-audit (map to four `.mdc`; not a second canon) | contract | unknown | Doctor roof rows target the `.mdc`, not this map | Number drift | owner |
| D6 | CURATOR (before-Write grounding, file map, handoff shape) | procedure | unknown | none (docs) | Grounding failure | owner |
| D7 | DECISIONS/hooks-architecture.md (ADR: 4 events, coverage claimed-vs-remaining, failure classes, bounded matching) | contract | unknown | Eval "ADR coverage table present"; doctor law-staleness sweep | Hook change | owner |
| D8 | Archive (`_archive/*`: 2026-09 snapshots incl. sessionStart-era tables) | contract (historical) | Preserve audit trail; explicitly not law | `_archive/README.md` ("Not always-on. Not install targets") | Misuse of archive as law | owner |
| D9 | Root `AGENTS.md` (navigator: law map, pack notes, skills, workflows, memory) | procedure, contract | unknown | Grounding "AGENTS.md is a navigator" row | Navigation rot (dead pointer) | owner |
| D10 | `README.md` (install/verify/layout) | procedure, contract | unknown | Mirrors TOOLCHAIN + run.sh | Command drift | owner |
| D11 | `NOW.md` current content (goal/state/evidence/next re Windows shim pass) | procedure (as handoff instance), unclear (freshness of claims) | unknown | none (hand-written state) | Next session or staleness | owner |

### 3.10 Tests and doctor (existing mechanisms)

| ID | Section | Roles | Rationale | Evidence | Review trigger | Authority |
|---|---|---|---|---|---|---|
| T-run | `tests/run.sh` (temp-pack copy, `run_test`, ordered sources, PASS/FAIL + exit code) | procedure, contract | unknown | Read this pass; self-evidencing on run | Harness change | owner |
| T-static | `static_checks.sh` (bash -n, shellcheck-if-present, JSON validity) | contract | unknown | Read this pass | New script/JSON without coverage | owner |
| T-eval | `eval_corpus.sh` (deterministic control must-pass individually; prose presence explicitly not behavior proof; M1–M4 manual rubric `[info]` only, no averaging of security) | contract, procedure | unknown | Read this pass | Evaluated-behavior dispute | owner |
| T-ground | `grounding.sh` (stop probes, hook shapes, frontmatter linter, no-dup-headings, glob shape, SSOT refs, description contract, navigator checks) | contract | unknown | Read this pass | Grounding regression | owner |
| T-rest | fixtures, gauntlet, gate_edges, hook_edges, plan_mode, fixtures_more, install_lifecycle, windows_host (bodies NOT re-read this pass) | contract (assumed) | unknown | Cited from run.sh order + TOOLCHAIN/doctor references | Any edit to those files | owner |
| T-doc | `scripts/doctor.sh` (pack inventory + isolated fixture install + optional live checksum; SKIP_LIVE/SKIP_FIXTURE modes with distinct banners) | procedure, contract | unknown | Read this pass | Mode/banner drift | owner |

## 4. Ambiguous classifications

| # | Entry | Ambiguity | Standing decision |
|---|---|---|---|
| A1 | H11 FORCE=1 ownership | Boundary (authorization to overwrite user data) vs procedure (install steps)? Incident-motivated per task brief, but no incident record traced in repo history this pass. Also: Unix gates on FORCE while Windows (H12) always overwrites with backup-once — is the divergence a contract or an accident? | Keep both roles; keep the guidance. Divergence recorded, not judged. Revisit only on an ownership bug report. Authority: owner. |
| A2 | H3 kept `drop`/`truncate` FP | Contract (documented behavior) vs workaround (regex limitation absorbed in docs)? | Keep both roles. The "do not weaken the gate" line makes removal the riskier move. Authority: owner. |
| A3 | R4 concise-output default | Preference (style yields to task) vs procedure (report shape)? agent.mdc calls it a default with mandatory exceptions (denials). | Preference primary, procedure secondary. Do not promote to boundary. Authority: owner. |
| A4 | D4 token-budget byte counts | The audit byte counts (11,812 → 14,577) are a 2026-09-03 snapshot; current counts are unverified. Contract (loading model) vs unclear (stale numbers)? | Loading model = contract; byte counts = historical, do not cite as current. Authority: owner. |
| A5 | G3 supabase installed-copy drift | Session catalog showed a narrower tenant-isolation row than the checkout body during this task's context load. Checkout body is authoritative for the ledger; installed snapshot was not diffed (no live install per task). | Checkout = contract; installed state = unknown. Revisit on next approved install + new chat. Authority: owner. |
| A6 | S3 / A-h / A-c / A-p unread bodies | Roles assumed from routers and references, not established. | `unclear` stays until bodies are read. No consolidation proposed for unread content. Authority: owner. |
| A7 | T1–T5 ties (task brief §4) | No `T1`–`T5` content found in `docs/` or `tests/` by search this pass. Cannot classify what is not in the pack. | Unknown. No redundancy inferred from ties. Revisit when the brief defines T1–T5. Authority: task author/owner. |
| A8 | D11 NOW.md claims | Hand-written state ("review corrections landed", "live not updated") with no verification attached in-file. Procedure (handoff instance) vs unclear (freshness)? | Both. Consume as continuity evidence per C6, not as verified state. Authority: owner. |
| A9 | K4 `session_start.sh` in manifest `hookScripts` | Legacy cleanup target vs live registration? Manifest also lists `wsl-shim.ps1` (legacy). Registration is `hooks.json` (4 events, no sessionStart). | Cleanup target (contract). Do not register; do not delete from manifest without an install-lifecycle reason. Authority: owner. |

## 5. Possible consolidations (no removals performed)

None of the following were changed. Each needs owner approval + re-verify
(`DOCTOR_SKIP_LIVE=1 bash scripts/doctor.sh`, `bash tests/run.sh`) before acting.

| # | Overlap | Keep-as-is reason |
|---|---|---|
| P1 | Harness described in 4+ places: agent.mdc table (R1), engineering-system stages (D2), ARCHITECTURE steel (D1), ADR coverage (D7), SECURITY steel (E2) | Different jobs: capsule vs loop vs layers vs decision record vs law. Consolidation risk: breaking the readers each serves. At most, cross-link. |
| P2 | Charter (C1–C14) vs agent.mdc capsule (R1–R4): no-retry-denies, handoff-as-evidence, approval naming appear in both | Intentional per 2026-09 audit: paste = user-level floor (incl. cloud), `.mdc` = installed capsule. Different load paths justify duplication. |
| P3 | Thin-roof pattern: `.mdc` points, skill explains (ponytail R5/S2, testing R7/S1) | Intentional: keeps always-on context small. Do not inline skills into rules. |
| P4 | CURATOR grounding (D6) vs engineering-system GROUND row (D2) vs testing skill gauntlet (S1) | Different granularity: pre-Write habit vs stage map vs test loop. At most, align wording. |
| P5 | TOOLCHAIN install safety (D3) vs engineering-system idempotency (D2) vs uninstall.sh comments | Same facts, three readers (operator, loop, code). Keep; drift is caught by install_lifecycle tests. |
| P6 | Reason-code lists: SECURITY E4 vs ADR failure classes (D7) vs eval reason rows (T-eval) | Law vs decision record vs test. Tests pin the codes; docs explain them. Keep. |
| P7 | Supabase/postgres composability stated in both glob files (G2/G3) | Each file must stand alone when only its glob matches. Keep. |
| P8 | Archive ADR changelog (D8) vs living ADR (D7) | Archive is history by policy (`_archive/README.md`). Never merge back. |

## 6. Execution records inventory

### 6.1 What exists

| Record | Producer | Persisted? | Content | Trust limitation |
|---|---|---|---|---|
| Test stdout (`PASS:`/`FAIL:` + exit code) | `bash tests/run.sh` | No (terminal only) | Per-fixture pass/fail, section headers, M1–M4 `[info]` rubric text | Ephemeral; re-runnable but not attributable. Paste into chat is hearsay without a re-run. |
| Doctor stdout (`[ok]`/`[fail]`/`[warn]`/`[info]` + banner) | `bash scripts/doctor.sh` | No (terminal only) | Pack inventory, fixture-install results, optional live checksums | Same as above. `CHECKOUT CHECKS PASSED` ≠ live verified (banner says so). |
| `NOW.md` | Human/agent, by hand | Yes (repo file) | Goal/state/evidence/next for unfinished work | Hand-written, may be stale (A8); must never hold secrets; continuity evidence only (C6). |
| Git history | Commits | Yes (repo) | Coarse change record (e.g. `e853f88` audit, `#36` fail-close) | No per-execution granularity; messages do not record targets, approvals, or host behavior. Working tree currently holds 40 modified + 2 new files uncommitted (this pass changed 3 of them: none — see §8). |
| `~/.cursor/kleosrules-owned.txt` | Install (Unix) | Transient (removed on uninstall) | Hashes of owned rules/agents for ownership checks | Deleted by uninstall; not an audit log; live file, not inspected this pass. |
| Install/uninstall stdout (`[ok]`/`[rm]`/`[keep]`/`[restore]`) | fleet_sync / uninstall / install.ps1 | No (terminal only; `DRY_RUN=1` previews without writing) | What was written/kept/restored | Ephemeral; no record of who approved FORCE or which checkout was trusted. |
| Host hook decisions (allow/deny/ask UIs) | Cursor host | Host-managed, outside pack | Per-call decisions | Not visible to the pack; host pause/deny timing unverified (E8). |
| Agent transcripts | Cursor host | Outside pack (projects dir) | Full session record | Host-local, not versioned, may contain secrets; not a pack mechanism. |

### 6.2 What is actually missing (not built this pass)

- A persisted, per-execution record of consequential actions (action, resolved
  target, effective destination, inputs' freshness, approval reference, result).
  stdout and NOW.md do not provide this; git does not either.
- Any tamper-evidence for such records (append-only log, signatures, external
  sink). Nothing in the pack claims it, and this pass adds no such claim.
- A recorded link between a host `ask` approval and the exact command + target
  executed afterwards. The charter requires rechecking at execution (C4); no
  mechanism records that the recheck happened.
- Live-install attestation (which checkout, which commit, when, verified by
  whom). Doctor checksums compare live vs checkout on demand but persist nothing.

No recorder was built and none is proposed here beyond naming the gap. A future
recorder would itself need a threat model (local attacker? malicious repo?
operator error?), a sink, redaction rules, and host cooperation for `ask`
correlation — all out of scope for a maintainability pass.

## 7. Maintenance procedure

1. Scope the change: name the ledger IDs touched (e.g. `R5`, `H2`). If none
   apply, add a row before editing guidance — never edit law first and document
   later.
2. Read before changing: open the source file(s) plus this ledger entry. For
   unread bodies (S3, A-h/c/p, T-rest), read the body and upgrade the entry;
   do not reclassify from memory.
3. Keep the hot path cold: edits go to the source file only. Never add
   enforcement, pointers, or summaries of this ledger to User Rules, `.mdc`
   files, skills, hooks, or root `AGENTS.md`.
4. Preserve provenance honesty: if rationale is unknown, write `unknown`. Do not
   infer redundancy from benchmark ties (A7) or from incident-motivation alone
   (A1). Consolidations in §5 need explicit owner approval each.
5. Update the ledger in the same change: roles, rationale, evidence, trigger,
   authority, plus a §8 changelog line. Keep §2 scope lists accurate.
6. Re-verify with existing mechanisms: `DOCTOR_SKIP_LIVE=1 bash
   scripts/doctor.sh` (checkout only) then `bash tests/run.sh`. Run from Git
   Bash on Windows. Docs-only ledger edits still run the ledger structural
   checks via `run.sh`; skip the live doctor unless an install is in scope.
7. Report honestly: what ran, exit codes, what remains unverified (live install,
   host behavior, model evals). Never claim live, host, or behavior verification
   from checkout fixtures.

## 8. Changelog

| Date (UTC-5) | Change | By |
|---|---|---|
| 2026-09-10 | Initial ledger: §§0–8; inventory scope explicit; T1–T5 and FORCE-1 provenance marked unknown; structural checks in `tests/lifecycle_ledger.sh` wired via `tests/run.sh`; no removals; no live install; no model evals. | Agent pass (this chat) |
