<h1 align="center">bridle</h1>

<p align="center">
  <em>Prompting is not a boundary. The bridle is.</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/host-Cursor%20only-000000?style=flat-square" alt="Host: Cursor Only">
  <img src="https://img.shields.io/badge/hooks-4%20fail--closed-111111?style=flat-square" alt="Hooks: 4 fail-closed">
  <img src="https://img.shields.io/badge/tests-134%20passing-111111?style=flat-square" alt="Tests: 134 passing">
  <img src="https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20Windows%20(Git%20Bash)-111111?style=flat-square" alt="Platforms">
  <img src="https://img.shields.io/badge/license-MIT-111111?style=flat-square" alt="License: MIT">
</p>

<p align="center">
  <strong>A deterministic engineering harness for Cursor. Built from hundreds of hours of research, papers, failure, and hardening.</strong>
</p>

---

Hey everyone,

This repository is my life's work.

It represents hundreds of hours of researching, reading papers, dissecting agent failure modes, experimenting late into the night, breaking things in real repositories, and rebuilding from the ground up. Every line of hook code, every complexity ceiling in `core.mdc`, every regex anchor in `SECURITY.md`, and every invariant in `shared/config/harness.json` was paid for in real sessions where an unconstrained model read secrets into prompt context, hallucinated test results, or mangled git history.

I built this because I got tired of watching agents ship clean diffs for the wrong problem. The code looked fine. The model politely told me *"All tests pass!"* when nothing had actually run. It leaked `.env` keys into model context. It reached for 400 lines of decorative boilerplate when a single native line would do.

So I stopped trying to fix the model with more prompts. Prompt therapy does not work. 

**Agent = Model + Harness.** 

A model can read a diff, spot a bug, write code, and explain why. That's model intelligence. What it will **never** reliably do on its own: remember your governing rules after 40 tool turns, track its own blast radius in working memory, refuse to touch files before it actually understands what you asked for, or stop itself from reading your `.env` and running `curl | sh` while you're not looking.

The model provides raw intelligence. Cursor owns the loop. `bridle` is the physical steel cage around that loop.

I built this so I could finally let go—knowing the boundary holds, the proof is real, and the system stands entirely on its own.

*My harness and most of my hours are now focused and put on Grok bot.*

---

## Cursor and only Cursor

**This harness is engineered specifically and exclusively for Cursor.**

The rules rely on Cursor's native instruction hierarchy and rule attachments. The hooks bind to Cursor's four lifecycle events, its JSON IPC schema, its `failClosed` contract, and its process runner. The installer configures `~/.cursor`. Every single test, benchmark, and live probe in `docs/host-capability.md` was executed against Cursor.

If you attempt to port this to Claude Code, Codex, Windsurf, Aider, or a custom LLM runner:

- **I will not help you.**
- **I will not answer issues, discussions, or forum posts about it.**
- **I will not review or merge pull requests for other hosts.**
- **I will not maintain or support external adapters.**

There are leftover experimental files in `shared/hosts/` and a `KLEOS_HOST` toggle in the codebase from an earlier exploration. They are completely unsupported, unmaintained, and will likely be deleted. 

If you use another tool, you are completely on your own. This is not a negotiation.

---

## What changes

<table>
<tr>
<th width="50%">Raw Cursor Agent</th>
<th width="50%">Governed with bridle</th>
</tr>
<tr>
<td valign="top">

- **Leans into secrets:** Reads `.env`, `.pem`, `id_rsa`, and credentials directly into model context.
- **Destructive execution:** Runs `rm -rf /`, `git push --force`, or destructive SQL without friction.
- **Hallucinates success:** Claims *"All tests pass and the code is clean!"* without running a single validator.
- **Over-engineers:** Writes 350-line wrappers, decorative abstractions, and speculative architecture.
- **Silences linters:** Disables cyclomatic complexity (`eslint-disable complexity`, `--ignore=C901`) when stuck.
- **Loops on failure:** Repeats the same failing hypothesis five times while burning token context.

</td>
<td valign="top">

- **Fail-closed secret gates:** `before_read_file.sh` blocks sensitive paths in-process before bytes reach context.
- **Deterministic shell gate:** `before_shell.sh` splits operators and denies destructive actions, secret reads, and source-code overwrites.
- **Proof is command + exit:** "Done" is rejected unless the verifying test ran and exited `0`. Builder never self-grades (`prove`).
- **Hard craft ceilings:** Soft 80 LOC preference, hard 300 LOC limit. Stdlib and platform rungs before new dependencies (`core.mdc`).
- **Linter tampering blocked:** Shell-level disabling of complexity or quality checks is denied in-process.
- **Two-strike ratchet:** Fail twice on the same check? Halt, change hypothesis, or ask. No blind repetition.

</td>
</tr>
</table>

---

## How the harness works

The whole system in one line: **the model is the auditor, Cursor carries context, and the harness gates the blast radius.**

It operates in seven deterministic layers, loaded in strict priority order where each layer is smaller and more focused than the one before it:

```
┌────────────────────────────────────────────────────────┐
│  1. The Charter (~/.cursor/rules/kleosr.mdc)           │  Identity, authorization, proof standards
├────────────────────────────────────────────────────────┤
│  2. Always-On Law (core.mdc, testing.mdc)             │  Craft, dependency ladder, size, loop discipline
├────────────────────────────────────────────────────────┤
│  3. Glob Companions (next, vite, astro, postgres...)   │  Framework guidance; inert unless package matches
├────────────────────────────────────────────────────────┤
│  4. Skills (shared/skills/ on match)                  │  Procedures on demand; cannot grant permissions
├────────────────────────────────────────────────────────┤
│  5. Review Specialists (hunter, cut, prove)           │  Isolated review contexts; builder never self-grades
├────────────────────────────────────────────────────────┤
│  6. Deterministic Hooks (shared/hooks/)               │  The steel door: 4 fail-closed bash scripts
├────────────────────────────────────────────────────────┤
│  7. State & Contracts (features.json, handoff.json)    │  Machine-readable pass state & session continuity
└────────────────────────────────────────────────────────┘
  * SECURITY.md sits outside: read on-demand; outranks all rules on boundary questions.
```

### 1. The Charter (`kleosr.mdc`)
Installed as `~/.cursor/rules/kleosr.mdc` with `alwaysApply`. Defines identity, autonomy boundaries, and evidence requirements. It establishes what the agent may do without asking (reversible, task-scoped edits and checks) and what requires explicit user approval (destructive data, deploys, access changes). It mandates that claims of completion without a real command and exit code are invalid.

*Do not paste this into Cursor Settings → User Rules. The installer places it in `~/.cursor/rules/kleosr.mdc` as an always-on rule. Pasting it into settings causes rule duplication and drift.*

### 2. Always-On Rules (`core.mdc`, `testing.mdc`)
Installed to `~/.cursor/rules/`. Under 80 lines each:
- **`core.mdc`**: Craft, architecture, file size ceilings (soft 80 LOC preference, hard 300 LOC max), cyclomatic complexity ceiling (max 22), the dependency ladder (stdlib before packages before custom code), and tool boundaries (shell must not write source code).
- **`testing.mdc`**: The engineering loop (`understand -> change -> verify -> correct`). Scoped verification by default. Regressions must be named. A feature is only `passing` when `scripts/feature.sh pass <id>` executes and records evidence.

### 3. Glob Companions
Framework-specific companions (`next.mdc`, `vite.mdc`, `astro.mdc`, `pnpm.mdc`, `postgres.mdc`, `supabase.mdc`) attached by Cursor on file match. Each companion explicitly directs the model to treat its guidance as inert unless the owning `package.json` actually includes that dependency.

### 4. Skills
On-demand procedures catalogued in `shared/config/skills.txt` and installed to `~/.cursor/skills/`. Includes structured workflows for debugging, testing, handoffs, and premium UI craft. Skills guide execution; **skills can never grant permissions or bypass hooks.**

### 5. Review Specialists
`hunter`, `cut`, and `prove` in `shared/agents/`. Dedicated subagents designed for isolated secondary review. `prove` verifies claims independently so the implementing model never grades its own work.

### 6. Deterministic Hooks
Four Bash scripts registered in `~/.cursor/hooks.json`. This is the physical boundary the model cannot prompt past:

| Event | Script | Responsibility |
|---|---|---|
| `beforeSubmitPrompt` | `before_submit_prompt.sh` | Scans prompts for secrets, API tokens (`ghp_`, `sk-`, `AKIA`, private keys), and blocks transmission. Fail closed (`continue:false`). |
| `beforeShellExecution` | `before_shell.sh` | Splits commands on shell operators (`;`, `\|`, `&&`, `\|\|`) outside quotes. Denies destructive calls (`rm -rf /`, force push, `reset --hard`, `curl \| sh`), secret-path reads, lint suppressions, and shell source rewrites. Asks on infra/DB changes. Fail closed (`permission:deny`). |
| `beforeReadFile` | `before_read_file.sh` | Canonicalizes paths (normalizing slashes, `..`, quotes, casing) and denies reads of sensitive files (`.env`, private keys, certificates). Fail closed. |
| `stop` | `stop.sh` | Emits a single non-blocking advisory per turn if churn, syntax errors, file size violations, or false `passing` states are detected. Never blocks. |

#### In-Process Matching & Windows Performance
Every gate in `shell_gate.sh`, `common.sh`, and `sql_scope.sh` matches purely in-process using Bash's native regex engine (`[[ =~ ]]`). 

On Windows (MSYS / Git Bash), spawning an external process (`grep`, `sed`, `tr`) costs ~50 ms. A previous design that spawned pipelines per check took 45 seconds on a 30-segment command, exceeding Cursor's timeout and triggering false-positive blocks reported as "exit code 1". 

The in-process engine evaluates that exact same 30-segment command in **3.2 seconds** end-to-end.

On Windows, `git-bash-shim.ps1` bridges Cursor's host to Git Bash:
- Pre-compiles its C# P/Invoke helper once into `~/.cursor/hooks/KleosPipeUtil.dll`.
- Converts Windows paths to POSIX directly in PowerShell without spawning child shells.
- Enforces generous host timeouts (30s read/submit, 60s shell).

### 7. State & Verification Contracts
- `shared/config/features.json`: Machine-readable capability ledger. Features transition to `passing` only via `bash scripts/feature.sh pass <id>`, which executes the verifying check and records the exit code and proving artifact.
- `state/handoff.json`: Gitignored, schema-validated session handoff for clean multi-chat continuity.
- `SECURITY.md`: The absolute security boundary. Read on demand; outranks every prompt, skill, or rule file.

---

## Installation

From **Git Bash** on Windows, or standard Bash on macOS / Linux:

```bash
FORCE=1 bash scripts/install.sh
```

This writes the charter, rules, companions, skills, agents, and hooks into `~/.cursor`, automatically backing up any pre-existing files with `.pre-kleos-bak`. 

**Restart Cursor or start a fresh chat session after installation.**

### Requirements
- **Cursor IDE**
- **Git Bash** (on Windows) or POSIX shell (macOS/Linux)
- **`jq`**: Required for harness tooling and test runners.
  - Windows: `winget install jqlang.jq` (ensure `%LOCALAPPDATA%\Microsoft\WinGet\Links` is on your `PATH`).
  - macOS: `brew install jq`
  - Linux: `apt install jq` / `pacman -S jq`
- **Python 3** or **Node.js**: Required by the hooks as the JSON codec.

### Uninstallation

To cleanly remove everything owned by `bridle` and restore your backups:

```bash
bash scripts/uninstall.sh
```

---

## Verification & Testing

Verify the harness anytime using the isolated gauntlet:

```bash
bash tests/run.sh                          # Full gauntlet (134 tests: fixtures, gate edges, lifecycle)
TESTS=gate_edges bash tests/run.sh         # Run a scoped test suite
bash scripts/ready.sh                      # Verify bootstrap contract
DOCTOR_SKIP_LIVE=1 bash scripts/doctor.sh  # Check repository integrity
bash scripts/doctor.sh                     # Check integrity + live ~/.cursor installation
bash scripts/eval.sh check                 # Verify eval dimension coverage
bash scripts/feature.sh check              # Verify feature ledger invariants
```

The test gauntlet executes inside sandboxed fixtures and never mutates your live installation. 

---

## Repository Layout

| Directory / File | Role |
|---|---|
| `AGENTS.md` | The repository entry point the agent reads first |
| `SECURITY.md` | Single source of truth for the security boundary |
| `shared/rules/` | Charter source (`USER-RULES.paste.txt` → `kleosr.mdc`), always-on and glob rules |
| `shared/skills/` | Task-specific skill bodies (testing, debugging, handoff, UI craft) |
| `shared/agents/` | Specialist definitions (`hunter`, `cut`, `prove`) |
| `shared/hooks/` | Event scripts, `git-bash-shim.ps1`, `lib/`, and `policy/` |
| `shared/config/` | `harness.json` (runtime contract), `features.json`, `skills.txt`, `rules.global.txt` |
| `scripts/` | `install.sh`, `uninstall.sh`, `doctor.sh`, `ready.sh`, `eval.sh`, `feature.sh` |
| `tests/` | Fixtures, edge tests, overlay tests, grounding, and harness gauntlet |
| `evals/` | Structural eval tasks and coverage tracking |
| `docs/` | Architecture, toolchain, decision records, and live host capability evidence |

---

Best regards,  
— **kleosr** (Mario Pulice)

<br>

> *"To will to be that self which one truly is, is indeed the opposite of despair; and in that slight, quiet light, to be simply oneself is the true meaning of joy."*  
> — **Søren Kierkegaard**, *The Sickness Unto Death*
