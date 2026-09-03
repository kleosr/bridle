# Runtime Grounding Audit — kleosrules

**Base commit:** `4abf279` (2026-09-03). **Machine:** macOS, bash 3.2, jq 1.7.1, Cursor Agent (local `~/.cursor` install).
**Method:** stdin/stdout probes against the hook scripts, isolated `mktemp` git repos, and in-session tool-result observations. No hidden prompt or model context was inspected; loader-side claims are inferred from tool-result attachments and labeled by confidence.

Confidence labels: **det** = deterministic, reproducible by `bash tests/run.sh`; **obs** = observed in this Cursor session from tool results (single session); **n/a** = the platform exposes no trace; a documented proxy is named.

## 1. Lifecycle matrix

`discovered → selected → loaded → injected → applied → enforced → reported`

| item | consumer | discovered | selected | loaded | injected | applied | enforced | reported | evidence | status |
|---|---|---|---|---|---|---|---|---|---|---|
| `~/.cursor/hooks.json` | Cursor hook runner | file at fixed path (**det**: doctor `hook ref exists`) | event name | IDE start | n/a | spawns scripts | n/a | doctor "5 native ./hooks/ events" | `scripts/doctor.sh`, `tests/fixtures.sh` | working |
| `session_start.sh` | Cursor `sessionStart` | hooks.json | every new agent chat, not plan mode | on event | `additional_context` = NOW.md Now/State/Limits/Proof/Next, 28 lines / 1,114 bytes (**det**) | agent sees NOW first (**obs**: this session's hooks_context) | n/a (context, not a gate) | this doc | `tests/fixtures.sh`, `tests/plan_mode.sh` | working |
| `before_submit_prompt.sh` | Cursor `beforeSubmitPrompt` | hooks.json | every prompt | on event | `continue` (+`user_message`) | prompt blocked when token pattern hit | **det**: `glpat`, `ntn_`, `ghp_` → `continue:false`; malformed JSON → false | this doc | `tests/gauntlet.sh`, `tests/hook_edges.sh` | working |
| `before_shell.sh` + `lib/shell_gate.sh` | Cursor `beforeShellExecution` | hooks.json | every Shell call | on event | `permission` allow/deny/ask + `user_message` | **obs**: this session, `seq … > fixture.ts` denied with `LEAN BYPASS BLOCK` before execution | **det**: 40+ gauntlet rows | this doc | `tests/gauntlet.sh`, `tests/grounding.sh` pre-action rows | working |
| `before_read_file.sh` | Cursor `beforeReadFile` (`failClosed: true`) | hooks.json | every Read | on event | `permission: deny` or `{}` | secret file never enters model context | **det**: `.pem`, `.env`, path with spaces | this doc | `tests/gauntlet.sh`, `tests/hook_edges.sh` | working |
| `stop.sh` + `lib/diff_gate.sh` (**new**) | Cursor `stop` | hooks.json | `status == completed && loop_count == 0` | on event | `{}` or one `followup_message` | agent receives next-turn message naming gate/file/fix | **det**: 200-line file 100% rewritten → `rewrite`; 15-function reindent → `format_churn`; controls `{}` | this doc | `tests/grounding.sh` (12 stop rows) | working (platform: re-prompts, cannot refuse completion) |
| `agent.mdc`, `ponytail.mdc`, `pnpm.mdc`, `complexity.mdc`, `vibe.mdc` (`alwaysApply: true`) | Cursor rules engine | `~/.cursor/rules/*.mdc` | always | session start | full body (**obs**: first three present in this session; complexity/vibe flipped to alwaysApply 14:15 by operator request, observable from the next chat) | agent behavior (judgment) | none | this doc | `tests/grounding.sh` "always-on rule count is 5" | working; obs-level |
| 6 glob `.mdc` (`testing`, `next`, `vite`, `astro`, `postgres`, `types`) | Cursor rules engine | `~/.cursor/rules` / pack `.cursor/rules` | file path matches `globs` | on match | full body | judgment | none | this doc | **obs**: none attached in this session while editing `.sh`/`.md`/`.json` (no glob matches those extensions) | consistent; negative-only obs |
| `USER-RULES.paste.txt` | human → Cursor User Rules | manual paste | always | session start | full body (**obs**: present as user rules this session) | charter | none | this doc | drift check: paste says five hooks now | working; manual re-paste required after this change |
| root `AGENTS.md` | Cursor workspace instructions | repo root | always | session start | full body (**obs**) | judgment | none | this doc | **obs**: this session held the pre-pull text after `git pull` — stale until new chat | working; **stale-in-session** finding |
| nested `shared/*/AGENTS.md` | Cursor | directory of a Read file | attached when a file in that dir is Read (**obs**) | on Read | full body | judgment | none | this doc | **obs**: attached content was pre-pull text (commit `6a1bb0a` on disk) — index cache lag | working; **stale-cache** finding |
| `NOW.md` | `session_start.sh` | repo root / `workspace_roots[0]` | active headings | on event | 28 lines | agent knows Proof/Next | n/a | this doc | `tests/fixtures.sh`; token-blob skip `tests/gauntlet.sh` | working |
| `SECURITY.md`, `docs/*.md` | agent on Read | path | explicit Read | on Read | full | judgment | none | — | none (docs) | reference only |
| skills `shared/skills/*/SKILL.md` (10) | Cursor skill catalog + agent Read | catalog lists `name` + `description` (**obs**: catalog present this session) | description match or `/name` | **body only on Read** (**obs**: ponytail body appeared only after explicit Read) | full body on Read | judgment | none | this doc | `tests/grounding.sh` "every catalog skill has a description" | working; metadata-discovered |
| `shared/agents/{hunter,cut,prove}.md` | Cursor subagents | `~/.cursor/agents` | `/hunter` `/cut` `/prove` | on invoke | full | subagent report | none | — | doctor presence | on demand |
| `.cursorrules`, `CLAUDE.md`, `GLOBAL-RULES.md`, `HANDOFF.md` | — | absent (`rg` 0 hits) | — | — | — | — | — | — | doctor "HANDOFF retired" | absent by decision |
| `hooks.cloud.json` | Cursor cloud | repo `.cursor/hooks.json` via `project-hooks` | cloud agent | — | 3 events, no `stop` | — | — | — | `tests/fixtures.sh` | stop on cloud **unverified**; not registered |

## 2. Per-source answers (condensed)

| # | question | hooks | alwaysApply .mdc | glob .mdc | AGENTS.md | NOW.md | skills |
|---|---|---|---|---|---|---|---|
| 1 | who discovers | Cursor via hooks.json | Cursor rules engine | rules engine | Cursor workspace loader | `session_start.sh` | Cursor catalog + agent |
| 2 | what selects | event name | always | path glob | root: always; nested: dir of Read | headings regex | description / `/name` |
| 3 | load point | per event | session start | on match | start / on Read | sessionStart | on Read |
| 4 | content loaded | stdin JSON only | full | full | full | 5 sections, `head -n 40` | metadata always; body on Read |
| 5 | exact context | see §3 P12 | rule body | rule body | file body | `NOW:\n…` 28 lines | body |
| 6 | before decision | yes (before* events); stop is after | yes | yes | yes | yes | only if Read before Write |
| 7 | applied proof | permission/continue/followup in tool result | obs only | obs only | obs only | agent cites Proof | obs only |
| 8 | missing/malformed | `{}`/allow, exit 0 (**det** P6, P7); `beforeReadFile` failClosed | Cursor ignores? **n/a**; proxy: frontmatter linter test | same | absent = silent | quiet `{}` | catalog omits |
| 9 | cost | 62–133 ms each; stop 542 ms on this repo; timeout sum 90 s | 4,540 B total | 0 unless matched | 4,321 B root | 1,114 B | 0 until Read |
| 10 | simpler alternative | none (only deterministic layer) | fewer rules (already 3) | — | root only (nested are 3-line bridges) | — | — |

## 3. Controlled probes

All **det** rows run in `bash tests/run.sh` (174 PASS, 0 FAIL, 9.5 s wall, exit 0, 2026-09-03 14:04 -05).

| # | probe | fixture | command / observation | result | confidence |
|---|---|---|---|---|---|
| 1 | Root grounding | this repo | root `AGENTS.md` attached at session start; text matched pre-pull commit, not disk after `git pull` | applied; **stale within session** | obs |
| 2 | Nested grounding | Read `shared/hooks/hooks.json`, `shared/rules/agent.mdc`, `shared/skills/ponytail/SKILL.md` | tool result appended "relevant cursor rule files: shared/hooks/AGENTS.md" etc.; reading `scripts/doctor.sh` attached none | scoped to directory; content stale vs disk | obs |
| 3 | Glob-scoped rule | edited `.sh`, `.md`, `.json` all session | no glob rule attached (`complexity` globs `ts,js,py,go,rs`) | negative branch confirmed; positive branch not exercised this session | obs (negative only) |
| 4 | Always-on once | `grep -l '^alwaysApply: true'` = 5; `uniq -d` on `# ` headings = 0 | `tests/grounding.sh` | 5 files, no duplicate heading | det |
| 5 | Conflict/precedence | two conflicting `.mdc` | Cursor documents no precedence between alwaysApply rules; no trace exposed | **n/a**. Proxy: charter text "this charter wins"; test guarantees no duplicate canonical heading | n/a |
| 6 | Missing grounding | workspace dir without `NOW.md`; `stop` with non-git dir; `before_shell` with `{}` | `session_start` → `{}` or pack-fallback, exit 0; `stop` → `{}`; shell → allow | explicit fallback, never crash | det |
| 7 | Malformed grounding | `.mdc` with `alwaysApply: [unterminated`; `stop` with `not json` | frontmatter linter flags; hook emits `{}` exit 0 | actionable (`bad:<file>` in test name) | det |
| 8 | Skill discovery | catalog | all 10 `SKILL.md` have `description:` | routing contract present | det |
| 9 | Skill loading | ponytail | body absent from context until explicit `Read`; catalog description present from start | **metadata discovered, body on Read** | obs |
| 10 | Skill application | this audit task | `ponytail` body read explicitly; behaviors unique to body (split recovery, roofs) available only after | applied after Read | obs |
| 11 | Non-matching skill | earlier turns (git pull + install) | no skill body read; catalog only | no full-context cost | obs |
| 12 | Hook context | stdin/stdout | `stop`: `{status, loop_count, workspace_roots}` → `{}` or `{followup_message}`; `sessionStart` → `additional_context`; shell → `permission` | exact shapes in `tests/*.sh` | det |
| 13 | Pre-action gate | `seq 1 400 > src/big.ts` via Shell | `permission: deny`, `LEAN BYPASS BLOCK` — also hit live in this session before any write | policy present before the write | det + obs |
| 14 | Stop gate | `rewrite/` 200-line file 100% changed; `reindent/` 15 functions 2-space→4-space; `dup/` two `function helper`; `tracked/` new `def one` beside existing; controls `clean/` (3-line fix in 350-line file), `rename/`, this pack | rewrite → `followup_message`; reindent → `followup_message`; duplicate → `followup_message`; 3 controls → `{}` | **Ponytail-at-Stop working** for churn detection (rewrite, format, duplicate) | det |
| 15 | Duplicate channel | `session_start` output vs `.mdc` | `additional_context` contains no `## Ladder`, `alwaysApply`, or `Harness (` | NOW is state only; law arrives once via rules engine | det |

## 4. Ponytail and Stop

| question | answer | evidence |
|---|---|---|
| where it lives | `shared/rules/ponytail.mdc` (alwaysApply roof, 934 B) + `shared/skills/ponytail/SKILL.md` (procedure) + `lib/diff_gate.sh` (churn detection) | inventory |
| copies | pack + `~/.cursor` install copy (rule) and symlink (skill) — install artifacts, not duplicate canon | `verify_smoke` symlink check |
| discovery | rule: rules engine, always; skill: catalog description, `/ponytail`, or `Read` | P9 |
| before this change | rule + skill only; no hook; "No registered lean hook" in both files | `git show HEAD:shared/rules/ponytail.mdc` |
| Stop loads policy / calls script / invokes skill / word only | **calls a script**: `stop.sh` sources `lib/diff_gate.sh`; no skill invocation; no `ponytail` word-matching | file |
| before completion? | No. Cursor `stop` fires after the turn; output is `followup_message` (re-prompt). It cannot refuse completion. Documented platform contract. | cursor.com/docs/hooks |
| detects | unrequested rewrite of a tracked file (>50% lines changed, file ≥80 LOC), mass reindent (whitespace-only churn), duplicate top-level helper | P14 |
| does not detect | file size (300 LOC roof is guidance for new files, not a hook trigger), cyclomatic complexity, needless abstraction, unused dependencies, speculative architecture — judgment items; stay in `.mdc`/skill and `cut` agent | scope decision |
| actionable | message = `PONYTAIL STOP (stop.sh, runs once per turn). Fix, then run the repo proof.` + `rewrite: <file> changed N of M lines. Touch only the hunk of the defect (ponytail.mdc: reducing edits allowed, growth not).` or `format_churn: ...` | test "names the gate and the recovery action" |
| bounded | in-script `loop_count == 0` guard + `hooks.json` `loop_limit: 1`; `status != completed` → quiet | tests "loop_count 1 is quiet", "aborted is quiet" |
| false positives | 0 on `clean/` (3-line fix in 350-line file), `rename/` (body edit + distinct helper), `small_full` (50-line full rewrite, below 80 LOC floor), `real_fix_ws` (real 1-line fix), and this pack's working tree | P14 controls |
| development miss | first draft used a 300-LOC roof that triggered on file size alone — a 3-line fix in a 350-line file would demand a split (the drive-by the operator rejected). Replaced with churn detection (rewrite ratio + whitespace ratio). Second miss: duplicate-helper compared additions only to additions; a new helper duplicating an existing one passed. Fixed: added names counted against current content. Both regressions have tests. | `tests/grounding.sh` |

Classification: **Ponytail-at-Stop = working for unrequested rewrite, mass reindent, and duplicate helper; not implemented for file size, cyclomatic complexity, or judgment roofs.** Not claimed beyond that.

## 5. Skill activation

| skill | activation class | description routing check | positive | negative |
|---|---|---|---|---|
| ponytail | metadata discovered; body on Read; also pointed to by `ponytail.mdc` "Procedure" | specific ("Native Lean quality bar … when thin ponytail.mdc points here") | obs P10 | obs P11 |
| now | explicitly invoked (`/now`) or Read | specific | not exercised | obs |
| complexity | metadata; body on Read; `complexity.mdc` glob points here | specific | not exercised | obs |
| debugging | metadata; body on Read (no `.mdc`) | specific | not exercised | obs |
| testing | metadata; body on Read; `testing.mdc` glob points here | specific | not exercised | obs |
| design-stack, premium-ui-craft, landing-page-design, redesign-existing-projects, ux-web-research | metadata; body on Read; design-stack routes to one | specific to UI work | not exercised | obs |
| hunter / cut / prove | explicitly invoked subagents | — | not exercised | — |

No skill is hook-invoked. No skill is unreachable (all 10 symlinked, `verify_smoke`). No skill claims automatic loading; `ponytail/SKILL.md` and `ponytail.mdc` text was corrected to name exactly which two roofs are hook-checked. Nothing removed: each skill has a distinct description and no baseline `.mdc` duplicates a skill body (thin-roof pattern: `.mdc` points, skill explains).

## 6. Scorecard (measured)

| metric | before (`4abf279`) | after | how measured |
|---|---|---|---|
| always-on instruction files | 5 (3 `.mdc` + User Rules paste + root `AGENTS.md`) | 7 (5 `.mdc` + paste + root `AGENTS.md`); operator flipped `complexity`/`vibe` to alwaysApply at 14:15 | `grep -l alwaysApply: true`; catalog |
| always-on context bytes | 11,812 | 12,416 after five-hook rows; 14577 after complexity+vibe alwaysApply | `wc -c`, `git show HEAD:` |
| NOW inject | 28 lines / 1,114 B | same | `session_start.sh` output |
| duplicate rules (shared top heading) | 0 | 0 | `tests/grounding.sh` |
| registered hooks | 4 | 5 | `jq '.hooks|keys'` |
| worst-case hook runtime (timeout sum) | 60 s | 90 s | `jq '[.hooks[][].timeout]|add'` |
| measured hook wall (this Mac) | 95 + 62 + 133 + 63 = 353 ms | + 542 ms `stop` on this 27-file diff | `python3 time` around each script |
| fixture false positives / negatives | shell gauntlet 0/0 | shell 0/0; stop 0 FP on 3 controls, 0 FN on 3 planted defects | `tests/gauntlet.sh`, `tests/grounding.sh` |
| skills discovered / correctly activated | 10 / not measured | 10 / 1 positive + 1 negative in-session observation | catalog; P10–P11 |
| Stop violations detected / missed | 0 / all (no stop) | 3 / 0 in fixtures (rewrite, format_churn, duplicate); 2 missed during dev (loc_roof drive-by, duplicate-of-existing), both fixed + tested | P14 |
| installer / uninstaller tests | 18 pass | 18 pass (event count 5) | `tests/install_lifecycle.sh` |
| test suite | 148 PASS | 174 PASS, 0 FAIL | `bash tests/run.sh` |
| changed-function cyclomatic (manual count of branches) | — | `stop.sh` main path 6; `gate_loc_roof` 5; `gate_duplicate_helper` 4; `diff_additions` 3; all ≤ 10 | read |
| full validation duration | ~8.6 s tests | 9.5 s tests + ~1 s doctor | `time` |
| live install checksum | 6 files match | 8 files match (`stop.sh`, `lib/diff_gate.sh` added) | `scripts/doctor.sh` |

## 7. Findings

| finding | sev | status |
|---|---|---|
| Root and nested `AGENTS.md` served pre-pull content in a running session (root: loaded at start; nested: index cache) | P3 | documented. Recovery: open a new chat after pulling instruction files. No pack fix possible. |
| Ponytail had no enforcement at completion; law text claimed "no lean hook" (true) but nothing checked the roofs | P2 | **fixed**: `stop.sh` + `diff_gate.sh`, 12 tests. First draft used a 300-LOC roof (drive-by trigger); replaced with churn detection per operator review. |
| `stop` cannot refuse completion on this platform | — | documented in agent.mdc, ARCHITECTURE, SECURITY, ADR; not claimed |
| Precedence between two alwaysApply rules not observable | — | n/a; proxy = unique headings + charter statement |
| Positive glob-rule activation not exercised this session (no TS/JS files edited) | — | open; needs a TS/JS repo session to observe |
| `hooks.cloud.json` has no `stop` | — | deliberate; cloud support unverified |

## 8. Hard-stop compliance

No skill claimed auto-read (P9 says body-on-Read). No hook claimed to inject model context except `sessionStart` (`additional_context`, det) and `stop` (`followup_message`, platform-documented). Ponytail-at-Stop claimed only for the two script-checked roofs. No hidden prompt inspected; all loader observations come from tool-result attachments. Sentinels were line counts and function names in `mktemp` repos. No extra agent/rule/skill; one hook with owner (`stop.sh`), activation (`stop` event), tests (10), purpose (two roofs). Loop bounded twice.
