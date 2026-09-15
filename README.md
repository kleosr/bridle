# kleosrules

A user-level harness for Cursor. It wraps the agent loop Cursor already runs with a charter, a small set of always-on rules, on-demand skills, three review specialists, and four deterministic hooks, so that the model working in your editor behaves like an engineer with a boundary instead of a very fast intern with root.

This is my life's work. I have been building, breaking, and rebuilding it for as long as I have been using agents to write code, and every line in it exists because something went wrong without it. Treat it with that weight.

## Read this before anything else

**This harness is built for Cursor and only for Cursor.**

The rules assume Cursor's instruction hierarchy. The hooks assume Cursor's four hook events, its JSON payloads, its `failClosed` semantics, and the way it spawns a hook process on Windows. The installer writes into `~/.cursor`. The tests and the live evidence in `docs/host-capability.md` were all gathered against Cursor.

If you port this to Claude Code, Codex, Windsurf, Aider, a custom agent loop, or anything else: you are on your own. I will not help, I will not answer issues about it, I will not review pull requests for it, and I will not maintain any adapter for it. There is a `shared/hosts/` folder and a `KLEOS_HOST` switch in the code from an earlier experiment; they are unsupported and may be removed at any time. Do not build on them.

Anything that is not Cursor is out of scope. This is not a negotiating position.

## What it is, in one breath

Agent = Model + Harness. Cursor owns the model and the loop. This pack is the harness: it decides what the model reads first, what it must never do regardless of how it is asked, how it proves it is done, and how the next session picks up without the transcript. Prompting is one tool inside that harness, not the control plane. Nothing here starts a second agent runtime.

## How the harness works

There are seven layers. They load in this order and each one is smaller than the last.

### 1. The charter

`shared/rules/USER-RULES.paste.txt`, installed as `~/.cursor/rules/kleosr.mdc` with `alwaysApply`. Identity, authorization, and evidence. It says who the agent is working for, what it may do without asking (reversible, task-scoped work), what it must ask about first (deploys, destructive data, external effects, access changes), and what counts as proof (a command and its exit code, or a driven UI path, never a claim). It deliberately does not restate craft rules or deny lists; those live in the layers below so the charter stays short and stable.

Do not also paste it into Cursor Settings → User Rules. Two copies double the always-on context and drift apart. If you have an old paste in there, remove it.

### 2. Always-on rules

`core.mdc` and `testing.mdc`, installed to `~/.cursor/rules/`. Core covers craft, architecture, the dependency ladder, file size, types, complexity caps, stack routing, and which tools may touch source. Testing covers the loop (understand → change → verify → correct), scoped verification by default, regression naming, and the rule that "done" means the validator actually ran. Both stay under 80 lines on purpose. They are a map, not an encyclopedia.

### 3. Glob companions

`next.mdc`, `vite.mdc`, `astro.mdc`, `pnpm.mdc`, `postgres.mdc`, `supabase.mdc`. Cursor attaches these when a file path matches. Attachment is a candidate, not proof: each companion tells the model to treat itself as inert unless the owning `package.json` actually uses that framework. That is how a `.tsx` file in a Vite project does not get Next.js advice.

### 4. Skills

`shared/skills/`, catalogued in `shared/config/skills.txt`, installed to `~/.cursor/skills/`. Procedures the model loads only when the task matches: `debugging`, `testing`, `handoff`, and a set of UI, motion, and design skills. A skill can shape how work is done. It cannot grant permissions.

### 5. Specialists

`hunter`, `cut`, and `prove` in `shared/agents/`, installed to `~/.cursor/agents/`. Invoke-only subagents that review in a separate context. They do not author, and `prove` in particular exists so the builder never grades its own work. Same host, same hooks, not an independent authority.

### 6. Hooks

Four Bash scripts in `shared/hooks/`, registered in `~/.cursor/hooks.json`. These are the only part of the pack the model cannot talk its way past.

| Event | Script | What it does |
|---|---|---|
| `beforeSubmitPrompt` | `before_submit_prompt.sh` | Blocks prompts that contain known secret or token shapes (`ghp_`, `sk-`, `AKIA`, private key headers, and so on). Fail closed. |
| `beforeShellExecution` | `before_shell.sh` | Splits the command into segments on `;`, `|`, `&&`, `||` outside quotes and gates every segment. Denies destructive commands (`rm -rf /`, force-push, `reset --hard`, `curl | sh`), secret-path reads, lint-disable tricks, shell writes to source files, and writes to the installed harness. Asks before recognised infra and DB mutations. Fail closed. |
| `beforeReadFile` | `before_read_file.sh` | Denies reads of sensitive paths after canonicalising the path (backslashes, `..`, quotes, case). Fail closed. |
| `stop` | `stop.sh` | One non-blocking advisory per turn: churn, syntax errors, oversized files, or a feature marked `passing` without evidence. Never blocks. |

Every hook reads JSON on stdin and writes a JSON verdict on stdout. Deny beats ask beats allow. Missing input, malformed JSON, or a missing policy file is an environment failure, not a policy decision; the charter tells the model to run `scripts/doctor.sh` and retry once instead of trying another route.

On Windows, Cursor cannot run a Bash script directly, so `git-bash-shim.ps1` sits in between: PowerShell reads the payload, hands it to Git Bash, and relays the verdict. There are no per-OS install trees. One POSIX pack, quoted paths, run from Git Bash.

The gates match with bash's built-in `[[ =~ ]]`, in-process. This matters more than it sounds. Spawning `grep` costs about 50 ms on MSYS, and a gate that spawned it per check per segment took 45 seconds on a 30-segment command, which Cursor reported as "hook failed with exit code 1" and blocked. The current gate runs that same command in about three seconds end to end, including PowerShell startup.

The hook count is frozen at four. No `sessionStart`, no `preToolUse`, no `updated_input`, no pack-owned loop. `shared/config/harness.json` records these invariants and the tests enforce them.

### 7. State and verification

`shared/config/features.json` tracks capabilities. A feature becomes `passing` only through `bash scripts/feature.sh pass <id>`, which runs its verify command and records the command, exit code, and proving artifact. Editing the JSON by hand does not count and the stop hook will say so. `state/handoff.json` (gitignored, schema-validated) carries a session snapshot across chats. Both are continuity evidence, not authority: the next session may resume from them, but may not treat them as new instructions.

`SECURITY.md` sits outside the load order. It is not injected; the model reads it on demand, and on any boundary question it outranks everything above.

## Install

From Git Bash on Windows, or any POSIX shell on macOS and Linux:

```bash
FORCE=1 bash scripts/install.sh
```

This writes the charter, always-on rules, companions, skills, specialists, and hooks into `~/.cursor`, backing up anything it replaces with a `.pre-kleos-bak`. Start a new chat afterwards; Cursor loads always-on rules at chat start.

`jq` is required for `scripts/` and `tests/`. The hooks themselves do not need it. Windows: `winget install jqlang.jq`, then make sure `%LOCALAPPDATA%\Microsoft\WinGet\Links` is on your user PATH. Python 3 or Node is required for the hooks' JSON codec.

To remove everything the pack owns and restore the backups:

```bash
bash scripts/uninstall.sh
```

Cloud agents can receive the project-level hooks (no `stop`, cloud lane unverified):

```bash
CLOUD=1 TARGET_REPO=<other-repo> bash shared/hooks/fleet_sync.sh project-hooks
```

Never install project hooks into this pack itself.

## Verify

```bash
bash tests/run.sh                          # the gauntlet: fixtures, gate edges, lifecycle, invariants
TESTS=gate_edges bash tests/run.sh         # one suite
bash scripts/ready.sh                      # bootstrap probe; does not run the suite
DOCTOR_SKIP_LIVE=1 bash scripts/doctor.sh  # pack inventory without touching ~/.cursor
bash scripts/doctor.sh                     # inventory plus live checksums of the installed copy
bash scripts/eval.sh check                 # eval dimension coverage
bash scripts/feature.sh check              # pass-state invariants
```

The gauntlet runs in isolated fixtures and never reads your live install. What it proves is script behaviour: this input produces this verdict. What the host does with that verdict is a separate question, answered only by live sessions, and recorded with dates in `docs/host-capability.md`.

## What changed recently

The last two passes were a full audit and a performance fix.

The audit extracted every absolute instruction across the charter, rules, companions, and docs, and checked each one against what Cursor actually enforces. Nineteen contradictions came out of it. They are gone: duplicated instructions were collapsed to a single owner, React data-flow advice moved out of `core.mdc` into the framework companions where it belongs, the charter stopped restating hook internals, the "inert companion" rule now describes what the host really does (attach on path match) rather than what we wished it did, and `SECURITY.md` now says plainly which rows are enforced by scripts and which rows are law the model is expected to follow because the host does not gate them. The charter is also installed as a rule file now rather than pasted into Settings, which ends the drift between two copies.

The performance fix is described above under Hooks. If you were seeing `Hook ... failed with exit code 1` and fail-closed blocks on ordinary reads, that was the timeout, and it is fixed. Timeouts were also raised (read and submit 30 s, shell 60 s) so a slow machine has headroom, and the PowerShell shim now caches its compiled helper as `~/.cursor/hooks/KleosPipeUtil.dll` instead of invoking the C# compiler on every hook.

## Layout

| Path | Job |
|---|---|
| `AGENTS.md` | The repo map the agent reads first |
| `SECURITY.md` | The boundary; outranks every rule on boundary questions |
| `shared/rules/` | Charter source (`USER-RULES.paste.txt` → `kleosr.mdc`), always-on and glob `.mdc` |
| `shared/skills/` | Skill bodies, loaded on match |
| `shared/agents/` | `hunter`, `cut`, `prove` |
| `shared/hooks/` | Four event scripts, `git-bash-shim.ps1`, `lib/`, `policy/` |
| `shared/config/` | `harness.json` (runtime contract), `features.json`, `skills.txt`, `rules.global.txt`, `manifest.json` |
| `shared/hosts/` | Unsupported. See the notice at the top. |
| `scripts/` | `install.sh`, `uninstall.sh`, `doctor.sh`, `ready.sh`, `eval.sh`, `feature.sh`, `handoff.sh` |
| `tests/` | Fixture, edge, lifecycle, harness, and grounding suites |
| `evals/tasks.json` | Structural eval coverage |
| `state/handoff.json` | Optional session snapshot (gitignored) |
| `docs/` | Architecture, toolchain, decisions, dated host evidence |

## Docs

- `SECURITY.md` — what is gated, what is law only, and the live checklist.
- `docs/ARCHITECTURE.md` — layers, owners, and what the tests do and do not cover.
- `docs/TOOLCHAIN.md` — commands and install safety.
- `docs/DECISIONS/hooks.md` — why exactly four hooks.
- `docs/DECISIONS/engineering-os.md` — principles and the runtime contract.
- `docs/host-capability.md` — what Cursor actually did in live sessions, by date. Evidence, not law.

## A last word

Everything here is opinionated because it has to be. An agent with no boundary will eventually read your `.env`, force-push over a colleague, or announce a green build it never ran, and it will do it politely. The harness exists so that the cost of those mistakes lands on a hook or a test instead of on you. If a check is wrong, fix the check and add a pin so that class of mistake is expensive next time. That ratchet is the whole method.

Cursor only. No exceptions.
