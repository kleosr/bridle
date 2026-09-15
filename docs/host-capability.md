# Host Capability Matrix: Empirical Evidence, Not Guarantees

**Status:** Living Document · Empirical Observations · Not Law  
**Host Target:** Cursor Desktop & Cloud Agents  

Let me be completely transparent about what this file is and isn't.

A lot of AI tooling makes wild promises about security. But passing test fixtures in `tests/` proves only one thing: that our Bash scripts emit the expected JSON verdicts when fed sample payloads. It does **not** prove what Cursor's Electron host or Cloud Agent VM actually does when it receives that JSON.

Does Cursor actually halt when `permission: deny` is emitted? Does it genuinely pause on `ask`? Does it block prompt transmission on `continue: false`?

Those questions can only be answered by real production sessions, real telemetry logs, and honest notes. That is what this document tracks. We never claim host guarantees that haven't been measured live.

The single source of truth for script policies is `SECURITY.md`. The design rationale for hooks is in `docs/DECISIONS/hooks.md`.

---

## Execution Lanes: Local vs. Cloud

Cursor executes hooks across two very different environments:

| Execution Lane | Hook Configuration Loaded | What bridle Does |
|---|---|---|
| **Local Agent / Chat** | User hooks: `~/.cursor/hooks.json` | Default install (`FORCE=1 bash scripts/install.sh`). Protects your local machine. |
| **Cloud Agent** | Project hooks only: `<repo>/.cursor/hooks.json` | **Opt-in.** `CLOUD=1 TARGET_REPO=<other-repo> project-hooks` writes `hooks.cloud.json` to the target repo. Never installed into this pack. |
| **Cloud Agent + User Hooks** | `~/.cursor/hooks.json` is **not mounted** on the cloud VM | Your local user hooks do not follow into Cloud Agent instances. |
| **This Pack Repository** | No repo-level `.cursor/hooks.json` | Prevents recursive hook execution during local development. |

---

## Event Matrix

| Event | Local Availability | Local Harness Registration | Cloud Availability | Cloud Harness (`hooks.cloud.json`) |
|---|---|---|---|---|
| `beforeSubmitPrompt` | Yes | Registered (`failClosed:true`, timeout: 30s) | Yes | Registered (`failClosed:true`, timeout: 30s) |
| `beforeShellExecution` | Yes | Registered (`failClosed:true`, timeout: 60s) | Yes | Registered (`failClosed:true`, timeout: 60s) |
| `beforeReadFile` | Yes | Registered (`failClosed:true`, timeout: 30s) | Yes | Registered (`failClosed:true`, timeout: 30s) |
| `stop` | Yes | Registered (`failClosed:false`, `loop_limit:1`, timeout: 30s) | Documented | **Omitted** (unverified on cloud VMs) |
| `beforeMCPExecution` / `afterMCPExecution` | Yes | Omitted | Deferred in docs | Omitted |
| `preToolUse` / `postToolUse` | Yes | Omitted | Yes | Omitted |
| `subagentStart` / `subagentStop` | Yes | Omitted | Yes | Omitted |
| `sessionStart` / `sessionEnd` | Yes | Omitted | No | Omitted |

### Default Failure Semantics: Fail-Closed is Law
In stock Cursor, the default behavior for unconfigured or crashing hooks is **fail-open** (letting the action run anyway). 

`bridle` explicitly sets `"failClosed": true` on `beforeSubmitPrompt`, `beforeShellExecution`, and `beforeReadFile`. If a hook crashes, times out, or produces invalid output, Cursor blocks the tool call immediately. It is always safer to block a valid command and fix the hook than to silently let a destructive command through.

---

## Live Verification Log

Every entry here comes from real sessions on real machines.

### 2026-09-14 — Cursor 3.20.15 (x64, Windows 11), via `git-bash-shim.ps1`
*Telemetry source: `%TEMP%\kleos-hooks.log` across 742 real turns in one working day.*

| Check | What Actually Happened | Verdict |
|---|---|---|
| **Local Hook Invocations** | Hooks fired continuously across the entire working day: 433 reads, 198 shell executions, 69 prompt submits, 44 stop advisories. | **Confirmed** |
| **Shell Deny Honored** | Destructive shell command was immediately blocked by Cursor's UI; standard commands (`git status`, etc.) ran smoothly. | **Confirmed** |
| **`ask` Permission Pause** | The script emitted `ask` on database mutations, but host UI pause behavior remains unverified live. Don't rely on `ask` for critical safety. | **Unverified** |
| **Read Deny on Nonexistent Path** | When the agent tried to read a non-existent `.env`, Cursor didn't even invoke `beforeReadFile` (the host short-circuited on ENOENT). | **Host Pre-empted** |
| **Secret Prompt `continue:false`** | The script emitted `continue:false` on credential tokens. Whether remote submission was halted by host UI was not recorded in logs. | **Unverified** |
| **Process Spawn Latency** | Chained compound commands (30 segments) with multiple external tool invocations (`grep`, `sed`) hit Cursor's timeout, causing spurious fail-closed blocks. | **Defect Identified** |

### 2026-09-15 — Cursor 3.20.15 (x64, Windows 11), In-Process Rewrite
*Fixing the Windows process-spawn timeout.*

- **The Problem:** Cursor reported `Hook "...git-bash-shim.ps1 before_read_file.sh" failed with exit code 1` and blocked legitimate reads, while the hook log showed `exit=0 stdout=22B`.
- **The Discovery:** A hook process that exceeds Cursor's configured `timeout` is terminated by the host and reported as `exit code 1`. The external grep/sed/tr pipelines incurred ~50 ms process startup latency per fork on MSYS, totaling 45 seconds on 30-segment commands.
- **The Fix:** 
  1. Rewrote pattern matching in `shell_gate.sh`, `common.sh`, and `sql_scope.sh` to run **purely in-process** via native Bash regex (`[[ =~ ]]`).
  2. Cached the C# P/Invoke helper in `git-bash-shim.ps1` as `~/.cursor/hooks/KleosPipeUtil.dll`, eliminating repetitive compilation.
  3. Replaced external `cygpath` invocations with pure PowerShell drive-letter path normalization.
  4. Raised hook timeouts to 30s (`read`/`submit`/`stop`) and 60s (`shell`).

| Benchmark / Probe | Old Architecture | In-Process Architecture | Status |
|---|---|---|---|
| `before_shell.sh` (1 segment) | ~2.0 – 4.0 s | **1.5 s** | Green |
| `before_shell.sh` (30 segments) | ~45.0 s (Killed by host timeout) | **3.2 s** | Green |
| 6 Parallel `before_read_file.sh` bursts | Intermittent timeouts / `stdin=0B` errors | **All exit 0 (1.8 – 2.8 s)** | Green |
| Live 6-way Native File Read | Blocked by host fail-closed | **All 6 served concurrently** | Green |
| Full Test Gauntlet (`tests/run.sh`) | ~3 minutes | **~25 seconds (134 passing, 0 failing)** | Green |

### 2026-09-15 (later) — Cursor 3.20.15 (x64, Windows 11), Read hook off the retrieval hot path (H16)
*Telemetry source: `%TEMP%\kleos-hooks.log`, 1,383 `before_read_file.sh` invocations; payload `stdin` median ≈2 KB, p90 ≈13 KB, max 160 KB.*

- **The Problem:** the host sends the whole file `content` on every native Read and the hook spent one interpreter spawn resolving the JSON codec (`node … ping`), one decoding, and one emitting `allow` — about 550–650 ms of pure overhead per Read in Git Bash, before the PowerShell shim. Retrieval-heavy turns (6–10 Reads) paid seconds for a verdict that is almost always `allow`.
- **The Fix:** codec resolution cached in-process (`lib/json.sh`); `emit_allow` prints static JSON when it has no message; `before_read_file.sh` lifts every `file_path`/`path` value with a bash regex and allows when none matches policy. The codec still decides every deny and every ambiguous payload, so the deny set and the fail-closed classes are unchanged. Cursor's documented payload is `{file_path, content, attachments:[{type, file_path}]}`; attachments are why "all candidates clean" rather than "exactly one key" is the rule.

| Benchmark (bash, best of 5, no shim) | Before | After |
|---|---|---|
| `before_read_file.sh` allow | 541 ms | **186 ms** |
| `before_read_file.sh` deny (`.env`) | 557 ms | 435 ms |
| `before_shell.sh` allow (`git status`) | 595 ms | 399 ms |
| `before_submit_prompt.sh` clean prompt | 527 ms | 383 ms |

Verified: `TESTS=fixtures,gate_edges,harness,overlay_edges bash tests/run.sh` → 248 pass, 0 fail (this entry's regression cases are in `tests/fixtures.sh` under the H16 comment). The shim's own PowerShell startup is unchanged and still dominates the wall clock the host sees.

---

## The Rule We Live By

Treat `beforeShellExecution` deny as **authoritatively confirmed by host behavior**. 

Treat `beforeReadFile` deny, `ask` pauses, and prompt-scan transmission suppression as **enforced by script law, but subject to ongoing host validation**. Never claim host security guarantees that have not been demonstrated with dated empirical logs.
