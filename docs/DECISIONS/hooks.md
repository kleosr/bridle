# Architecture Decision Record: Why Exactly Four Hooks (And Why We Froze Them)

**Status:** Accepted, locked, and non-negotiable.  
**Context:** Cursor lifecycle events and physical boundary enforcement.  

## The Decision

When people first discover hooks in Cursor, the immediate temptation is to hook into everything. You see developers registering hooks on every tool call, injecting massive prompts on `sessionStart`, or trying to build a secondary ReAct loop inside the hook scripts. 

I went down that road early on in my research. It was a complete disaster. It creates nested reasoning loops, inflates token counts, slows down every interaction, and makes the agent brittle.

So we made an uncompromising architectural decision: **`bridle` enforces safety through exactly four deterministic hooks, and the hook surface is permanently frozen.**

1. `beforeSubmitPrompt`
2. `beforeShellExecution`
3. `beforeReadFile`
4. `stop`

Physical security belongs in deterministic sensors. Coding standards belong in `.mdc` rules. Specialized workflows belong in on-demand skills.

## The Four Hooks

| Hook Script | Host Event | Enforced Policy | Failure Mode |
|---|---|---|---|
| `before_submit_prompt.sh` | `beforeSubmitPrompt` | Blocks secret tokens (`ghp_`, `sk-`, `AKIA`, private keys) from leaving the machine into model context | Fail-closed (`continue:false`) |
| `before_shell.sh` | `beforeShellExecution` | Evaluates command segments; denies destructive actions, secret reads, source rewrites, and lint-disable tampering; asks on infra changes | Fail-closed (`permission:deny`) |
| `before_read_file.sh` | `beforeReadFile` | Canonicalizes paths and denies reads targeting sensitive files (`.env`, certificates, SSH keys) | Fail-closed (`permission:deny`) |
| `stop.sh` | `stop` | Evaluates turn output and emits one non-blocking advisory if churn, syntax errors, unfinished-work markers (unresolved conflicts, not-implemented stubs), or false feature completion is detected | Non-blocking (`loop_limit:1`, `failClosed:false`) |

## What We Protect (And What Remains Outside the Boundary)

I believe in brutal honesty about what software actually does. Too many AI safety tools claim 100% protection when they're really just string matches. Here is the exact coverage boundary:

| Protected Action | Event Intercepted | Enforced Verdict | The Remaining Reality |
|---|---|---|---|
| Reading sensitive files (`.env`, `.pem`, `id_rsa`) | `beforeReadFile` | `permission:deny` | Blocked at the hook level. But if a native `Write` or `StrReplace` tool touches it, host hooks don't intercept that—that is governed by Charter law and OS permissions. |
| Destructive shell commands (`rm -rf /`, force push) | `beforeShellExecution` (split on operators outside quotes) | `permission:deny` | Denied across chained commands. But a compiled binary or encoded command (`base64 -d | sh`) won't be caught by regex; true isolation requires an OS sandbox. |
| Commit / PR message false positives | `beforeShellExecution` | Filtered allow inside `-m`/`--message`/`--body` | If your commit message mentions *"fix: drop table users bug"*, it won't trigger a false deny. Unquoted multi-word args stay visible to prevent bypasses. |
| Infrastructure changes (`psql`, `terraform`, `docker rm -f`) | `beforeShellExecution` | `permission:ask` | Causes Cursor to show an approval card. Note: whether Cursor's host genuinely pauses execution is tracked in `docs/host-capability.md`. |
| Leaking secret tokens in prompts | `beforeSubmitPrompt` | `continue:false` | Blocks known token prefixes before Cursor sends the prompt to the API. |
| Shell overwriting source code (`> src/app.ts`, `sed -i`) | `beforeShellExecution` | `permission:deny` | Forces the model to use Cursor's native `Write` and `StrReplace` tools instead of messy bash redirects. |
| Modifying the harness itself (`rm ~/.cursor/hooks.json`) | `beforeShellExecution` | `permission:deny` | The agent is forbidden from tampering with its own cage. Updates must be run with `FORCE=1 bash scripts/install.sh`. |

## The Windows Process Spawn Nightmare (And How We Fixed It)

Here is a real war story from building this:

In Git Bash on Windows (MSYS), every time you spawn an external executable (`grep`, `sed`, `tr`, `awk`), Windows takes ~50 ms to initialize the process. 

In my early implementation, `shell_gate.sh` evaluated command segments by piping each segment through multiple grep and sed filters. If an agent ran a compound command with 30 segments (e.g. chained builds or lint checks), evaluating that command took **45 seconds**. 

Cursor's internal hook runner gave up, killed the process, and reported:  
`Hook ... failed with exit code 1`.  
Because the hook was configured as `failClosed: true`, legitimate commands were completely blocked.

To fix this once and for all:
1. **In-Process Regex:** All pattern matching now runs **directly in-process** using Bash's built-in regular expression engine (`[[ $str =~ $regex ]]`). Zero forks.
2. **Policy Caching:** Policy files (`secret_paths.ere`, etc.) are read once into memory arrays.
3. **P/Invoke Caching:** On Windows, `git-bash-shim.ps1` compiles its Windows API helper once into `~/.cursor/hooks/KleosPipeUtil.dll`, eliminating the 1-3 second C# compilation step on every turn.
4. **Result:** That same 30-segment command went from 45 seconds down to **3.2 seconds** end-to-end.

## Why We Explicitly Rejected Other Hook Events

- **No `sessionStart` / `sessionEnd`:** Stuffing a massive doctrine into the model at session start burns prompt cache and degrades reasoning before the agent has even read the task. Progressive disclosure via `AGENTS.md` is cleaner, faster, and cheaper.
- **No `preToolUse` / `postToolUse`:** Cursor already gives us targeted events (`beforeReadFile`, `beforeShellExecution`). A generic tool hook introduces massive latency on every single tool call without adding real security.
- **No Pack-Owned ReAct Loops:** The model loop belongs to Cursor. When you build a loop inside a harness, you get compounding error rates, runaway costs, and endless lag. We provide the rules and the sensors; Cursor drives the model.
