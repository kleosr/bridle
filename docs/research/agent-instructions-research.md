# Research corpus: agent instruction files, hooks, and rule architecture

Accessed: 2026-09-03. Purpose: generate hypotheses for `docs/engineering-rules-audit.md`. Nothing here entered the repository without a local test, consumer fact, or reproduction. Popularity metrics are reported, not used as evidence.

## Scope and limitations

- **Official sources: 4** (cap 10). Fetched with `curl` after the Exa MCP hit its free rate limit and the built-in fetch timed out on cursor.com; HTML stripped locally.
- **X posts: 20** from **2 queries** (cap 20). X API via the X MCP: first `get_usage_credits` returned 503; one retry succeeded (balance ~$99). Two `search_posts_all` calls, `max_results=10`, `sort_order=relevancy`, `start_time=2025-09-01`, English, ≥30/50 likes, no retweets/replies. Estimated cost < $0.30. No pagination. This is **not** a survey of "all famous threads"; it is the top-10 relevancy page for each query on one day.
- Not consulted: OpenAI Codex docs and the agents.md site (fetched but the page text did not survive HTML stripping; excluded rather than paraphrased from memory). Cursor forum threads: not fetched (would exceed the official-source budget with non-primary material).

## Queries

| # | Tool | Query | Returned |
|---|---|---|---|
| Q1 | X `search_posts_all` | `(AGENTS.md OR CLAUDE.md) (cursor OR "claude code" OR codex) -is:retweet -is:reply lang:en min_likes:50` | 10 |
| Q2 | X `search_posts_all` | `("cursor hooks" OR "claude code hooks" OR ".cursorrules" OR "cursor rules") (deny OR block OR fail OR safety OR enforce OR context) -is:retweet -is:reply lang:en min_likes:30` | 10 |
| W1 | curl | https://cursor.com/docs/context/rules | official |
| W2 | curl | https://cursor.com/docs/agent/hooks | official |
| W3 | curl | https://code.claude.com/docs/en/memory | official |
| W4 | curl | https://agents.md/ | fetched, unusable after stripping → excluded |

## Official sources (category: official fact)

| ID | Publisher | URL | Claim used (exact/paraphrased) | Confidence | Local hypothesis / test informed |
|---|---|---|---|---|---|
| W1 | Cursor docs, "Rules" | https://cursor.com/docs/context/rules | "Cursor supports AGENTS.md in the project root and subdirectories." Nested files "are combined with parent directories, with more specific instructions taking precedence." Rule types: `alwaysApply` / `globs` / description; "Separate multiple patterns with commas." Precedence "Team Rules → Project Rules → User Rules". `@filename` includes files "in your rule's context" (rules FAQ; not stated for AGENTS.md). | high | F-06 (nested adapters redundant; `@` import not an AGENTS.md feature), F-16 (globs syntax `unknown`), precedence statement in decision doc. |
| W2 | Cursor docs, "Hooks" | https://cursor.com/docs/agent/hooks | User hooks run from `~/.cursor/`; project hooks from project root. Exit 0 → use JSON; exit 2 → deny; other → "fail-open by default". `failClosed` blocks on "crash, timeout, invalid JSON". `beforeShellExecution` input `{command, cwd, sandbox}`, output `permission: allow\|deny\|ask`. `beforeReadFile` input `{file_path, content, attachments}`, output `permission: allow\|deny`. `beforeSubmitPrompt` output `{continue, user_message}` (message "when the prompt is blocked"). `sessionStart` input `{session_id, is_background_agent, composer_mode: agent\|ask\|edit}`, output `additional_context`; "fire-and-forget". "User-level hooks (~/.cursor/hooks.json) are not available in cloud agents." | high | F-01 (`ask` is a valid shell output), F-02 (failClosed contract), F-12 (timeout field), F-17 (`plan` undocumented), F-18 (no `ask` for reads), cloud `project-hooks` justification, hook matrix in audit §6. |
| W3 | Anthropic, Claude Code "Memory" | https://code.claude.com/docs/en/memory | "CLAUDE.md files can import additional files using @path/to/import syntax." "Claude Code reads CLAUDE.md, not AGENTS.md. If your repository already uses AGENTS.md … create a CLAUDE.md that imports it." Size guidance "target under 200 lines". | high | Core question 1–2: `@../../AGENTS.md` is a Claude idiom; `CLAUDE.md` only with a Claude consumer. |
| W4 | agents.md | https://agents.md/ | — (excluded, see limitations) | — | — |

## X corpus (20 posts)

Categories: **P** practitioner experience, **O** opinion, **M** maintainer statement (none found in this sample). Dates are post `created_at`; all accessed 2026-09-03. Metrics (likes) shown for transparency only.

| # | Handle | Date | URL | Relevant claim | Cat. | Conf. | Hypothesis / disposition |
|---|---|---|---|---|---|---|---|
| X1 | @PovilasKorop | 2026-06-15 | https://x.com/PovilasKorop/status/2066531928077946908 | `ln -s AGENTS.md CLAUDE.md` so AGENTS.md is the "(only) source of truth" (69 likes) | P | med | Confirms one-canonical-file instinct; symlink is one bridge option **if** Claude Code is used. Rejected here: no consumer. |
| X2 | @PawelHuryn | 2026-06-14 | https://x.com/PawelHuryn/status/2066052757895749891 | "Instructions: @AGENTS.md in CLAUDE.md. One source of truth." (201) | P | med | Same as X1 via `@import`. Rejected: no consumer. |
| X3 | @KSimback | 2026-04-26 | https://x.com/KSimback/status/2048429158812807284 | "Codex uses AGENTS.md just like [Claude uses CLAUDE.md]" (240) | P | med | AGENTS.md is the multi-tool baseline; supports keeping a single root `AGENTS.md`. Adopted (already true). |
| X4 | @sunnykgupta | 2026-04-23 | https://x.com/sunnykgupta/status/2047406063310532745 | engineers feel behind because of a "mysterious combo of rules, hooks, skills and best practices" (276) | O | low | Motivates: every file must have a named purpose (audit §3). Not evidence for any specific change. |
| X5 | @iuditg | 2026-09-01 | https://x.com/iuditg/status/2094710370451718357 | Codex limits exhausted in <2 days despite "PonyTail, RTK … updated Agents.md, YAGNI and KISS" (819) | P | low | Context cost is real; instruction files are not free. Informs §7 cost table. No rule adopted. |
| X6 | @Voxyz_ai | 2026-07-19 | https://x.com/Voxyz_ai/status/2078857039116156978 | banning phrases ("no em dashes", "stop saying delve") is not a writing system (4,273) | O | low | Parallels the audit's "slogans are not rules"; `ponytail/bans.txt` is documented as soft/fail-open. No change. |
| X7 | @Numan_Ai12 | 2026-07-23 | https://x.com/Numan_Ai12/status/2080098840972312727 | duplicate of X6 content (94) | O | low | Excluded as duplicate. |
| X8 | @robinebers | 2026-01-22 | https://x.com/robinebers/status/2014221559419072755 | agents default to "enterprise-grade" unless told the scale (77) | O | low | Supports ladder rung "NO CODE / reuse" in ponytail. No change. |
| X9 | @starmexxx | 2026-07-02 | https://x.com/starmexxx/status/2072662149747355883 | hardware/LLM hosting (81) | O | — | Off-topic; excluded. |
| X10 | @IBuzovskyi | 2026-07-10 | https://x.com/IBuzovskyi/status/2075543353333096840 | another agent loads a `.hermes.md` into system prompt every session (230) | O | low | Every tool has its own file; add one only per consumer. Consistent with decision. |
| X11 | @hackernoon (Sonar) | 2026-08-24 | https://x.com/hackernoon/status/2091896953407709225 | hooks "can enforce checks, block unwanted commands, and validate AI-generated code" (160) | O | low | Hooks as enforcement layer — matches architecture; no specific claim adopted. |
| X12 | @dani_avila7 | 2026-02-06 | https://x.com/dani_avila7/status/2019900748620870032 | hook inspects the command before run; "You can do the same with native Git hooks" (172) | P | med | Reinforces keeping hooks narrow and not duplicating what git/lint already enforce. No change. |
| X13 | @dani_avila7 | 2025-09-28 | https://x.com/dani_avila7/status/1972352021987508680 | Claude Code hook event overview (208) | P | med | Background only. |
| X14 | @dani_avila7 | 2026-01-29 | https://x.com/dani_avila7/status/2016881811117248867 | "Your … hooks are useless if you ignore exit codes … Exit 2: blocking … Other codes: non-blocking" (87) | P | med | Hypothesis: audit exit paths explicitly. Verified against W2 (Cursor: 2 = deny, other = fail-open unless `failClosed`) → F-01/F-02 fixes and the TOOLCHAIN failure table. |
| X15 | @dani_avila7 | 2026-03-27 | https://x.com/dani_avila7/status/2037598893157032421 | Claude hooks gained `if` conditions / matchers (144) | P | med | Cursor has `matcher` too (W2). Not adopted: our hooks need the full command to gate. |
| X16 | @chiefofautism | 2026-04-17 | https://x.com/chiefofautism/status/2045239015276761253 | shared-memory layer via "pure shell scripts + claude code hooks, no daemons" (37) | O | low | Contrast: kleosrules keeps memory in a plain file and hooks stateless (F-04). No change. |
| X17 | @alexhillman | 2026-01-21 | https://x.com/alexhillman/status/2013820793671536778 | agents don't know the date/timezone; inject it (328) | P | low | Possible sessionStart `additional_context` item. Not adopted: no local failure mode observed; would add per-session cost. |
| X18 | @AISecHub | 2026-03-05 | https://x.com/AISecHub/status/2029592709791395845 | Semgrep rule pack covering "Claude Code & Cursor hooks" (93) | O | low | Background; no local test. |
| X19 | @cyrilXBT | 2026-05-12 | https://x.com/cyrilXBT/status/2054118129274368055 | CLAUDE.md as "permanent context file" (61) | O | low | Restates W3; excluded from evidence. |
| X20 | @akshay_pachaar | 2026-03-27 | https://x.com/akshay_pachaar/status/2037523396876173783 | "CLAUDE.md is just a suggestion. Hooks are a guarantee." (955) | O | med | Aligns with separating guidance (`.mdc`) from enforcement (hooks) — already the pack's stance. Virality not used as proof; the local proof is the fixture suite. |

## Adopted vs rejected

| Recommendation (source) | Disposition | Local proof |
|---|---|---|
| One canonical instruction file per repo; bridges only for real consumers (W1, W3, X1–X3) | adopted (already the case; enforced by doctor/test) | `tests/audit.sh` "exactly one AGENTS.md", "no CLAUDE.md / .cursorrules" |
| Audit every hook exit/decision path explicitly (W2, X14) | adopted | `tests/audit.sh` malformed / missing-dep / missing-policy cases |
| Hooks stay narrow; do not re-implement git/lint (X12, W2) | adopted (no change needed) | gauntlet keeps `git commit`/`gh pr` exemptions |
| Inject date/time at sessionStart (X17) | rejected | no observed failure; adds cost every session |
| `matcher`-scoped hooks (X15, W2) | rejected | gate needs full command text |
| Symlink `CLAUDE.md → AGENTS.md` (X1) | rejected | no Claude Code consumer |
| Convert `globs` arrays to comma strings (W1 example) | deferred, `unknown` | brace patterns in `next.mdc` would break |

## Exclusions

- X7 duplicate of X6; X9 off-topic; X19 restates official doc.
- W4 agents.md: fetched (81 KB HTML) but no usable text after stripping; not paraphrased.
- Cursor forum / Reddit / blog posts: not fetched (budget; non-primary).
