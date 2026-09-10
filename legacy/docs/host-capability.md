# Host capability matrix

Living. Not law. Not injected. Not installed.

Scripts and `hooks.json` are the pack contract. This file records **where those contracts can run** and **what a live host actually did**. Script fixtures in `tests/` do not prove host behavior. A dated check does not survive a Cursor update.

SSOT for steel (what scripts emit): `SECURITY.md`. SSOT for why four events: `docs/DECISIONS/hooks-architecture.md`.

## Lane split

| Lane | Hook config the host loads | This pack |
|---|---|---|
| Local Agent / Chat | User hooks: `~/.cursor/hooks.json` (cwd `~/.cursor`) | Default install (`FORCE=1 bash scripts/install.sh` / `Windows/install.ps1`) |
| Cloud agent | **Project** hooks only: `<repo>/.cursor/hooks.json`. Enterprise may also load team/dashboard hooks | **Opt-in.** `CLOUD=1 TARGET_REPO=<other-repo> project-hooks` writes `hooks.cloud.json` into that repo. Never this pack. |
| Cloud agent + user hooks | `~/.cursor/hooks.json` is **not** available (cloud VM has no home install) | Local steel does **not** follow the user into cloud |
| This pack checkout | No repo-level `.cursor/hooks.json` (doctor: “no repo-level hooks in pack”) | Cloud work **on this repo** has no pack hooks unless someone adds project hooks |

Cursor docs (retrieved 2026-09-10, [Hooks](https://cursor.com/docs/hooks)): cloud also skips hooks on early read-only exploratory turns; starts them once the environment is writable. Cloud runs command-based hooks only.

## Event matrix

`reg` = registered in that JSON. `avail` = Cursor documents the event for that lane. `—` = not available or not registered.

| Event | Local avail | Local pack | Cloud avail | Cloud pack (`hooks.cloud.json`) |
|---|---|---|---|---|
| `beforeSubmitPrompt` | yes | **reg**, `failClosed: true` | yes | **reg**, `failClosed: true` (if project-hooks applied) |
| `beforeShellExecution` | yes | **reg**, `failClosed: true` | yes | **reg**, `failClosed: true` |
| `beforeReadFile` | yes | **reg**, `failClosed: true` | yes | **reg**, `failClosed: true` |
| `stop` | yes | **reg**, `failClosed: false`, `loop_limit: 1` | yes (docs) | **omitted** (support on cloud still unverified here) |
| `beforeMCPExecution` / `afterMCPExecution` | yes | omitted (ADR; fixtures assert absent) | **no** (docs: deferred) | omitted |
| `preToolUse` / `postToolUse` / `afterFileEdit` | yes | omitted (no `updated_input`) | yes | omitted |
| `subagentStart` / `subagentStop` | yes | omitted | yes | omitted |
| `sessionStart` / `sessionEnd` | yes | omitted | **no** | omitted |
| Tab read/edit | yes | omitted | **no** | omitted |

Default `failClosed` in Cursor is **false** (fail-open on crash/timeout/invalid JSON). This pack sets `true` on submit/shell/read. That is a **request**. Host honor of `failClosed` is a live-check row, not a script guarantee.

`ask` is a documented permission result for `beforeShellExecution` and `beforeMCPExecution`. It is useful only if the client pauses. Do not treat `ask` as a critical gate.

## Last live host check

| Field | Value |
|---|---|
| Date | 2026-09-10 (local, America/Chicago) |
| Host | Cursor 3.19.19 (`6496ea8a068aebfcd21990e70ff522e9abf10c80`), VS Code 1.128.0, win32 10.0.26200 x64 |
| Lane | Local Agent Chat. Live `~/.cursor/hooks.json`: four events, Windows Git Bash shim, `failClosed` true/true/true/false |
| Install | `bash scripts/doctor.sh` (live, not `DOCTOR_SKIP_LIVE`) → `ALL CHECKS PASSED`; live script checksums match this checkout |
| Operator | Agent ran the `SECURITY.md` checklist in this session. User authorized Phase 1 only |

### Named residuals (requested)

| Concern | Result | Evidence |
|---|---|---|
| `failClosed` (crash/timeout/invalid JSON blocks) | **unverified** | Config requests it. No crash/timeout was induced. Do not claim host fail-closed. |
| `ask` pause | **fail** | Live `before_shell.sh` returns `permission: ask` / `reason=ask-infra` for `psql -c "select 1"`. Host ran the command. No approval card. `psql` not on PATH (`CommandNotFoundException`). |
| Prompt-scan-before-transmit | **unverified** | Agent cannot submit a user prompt. Even a later `continue: false` would not prove the scan ran before remote transmit (`SECURITY.md`). |

### Six-step checklist

| Step | Expect | Result | Notes |
|---|---|---|---|
| 1. User prompt with synthetic token | `continue: false` | **not run** | Requires a **user** submit. Agent output is not `beforeSubmitPrompt`. |
| 2a. Shell `rm -rf /` | deny before exec | **pass** | Host: `Rejected: … AUTONOMY BLOCK: destructive command denied.` Command did not run. |
| 2b. Shell `git status --short` | allow | **pass** | Ran; exit 0. |
| 3. Shell `psql -c "select 1"` | approval card pauses | **fail** | See `ask` row above. Script ask ≠ host pause. |
| 4a. Read sensitive path | deny | **fail (host)** | Wrote gitignored `state/.env` with `KLEOS_HOSTCHECK=synthetic` only. Native Read returned the body. Same path piped to live `before_read_file.sh` → `permission: deny` / `reason=secret-path`. File deleted after. Repo-root `.env` missing → Read `File not found` (inconclusive). |
| 4b. Read `.env.example` | allow | **pass** | Script allow. Native Read of `state/.env.example` returned the body. Deleted after. |
| 5. Stop churn followup | one advisory `followup_message`; cannot refuse | **not run** | Would require ≥50% rewrite of a tracked file ≥80 LOC, then a later turn. Not a security control. |
| 6. Write / MCP / Tab ungated | law only | **pass (gap confirmed)** | Native Write of `state/.env` succeeded (then deleted). MCP tools ran earlier this session with no pack MCP hook. Tab not exercised (IDE feature). |

Extra: Shell `echo drop table kleos_hostcheck` was host-denied (`destructive` FP, kept). That is the same deny path as 2a, not a new gate.

### How to read this

- **deny on Shell** was enforced on this host/version.
- **ask on Shell** was not a pause on this host/version.
- **deny on Read** was produced by the installed script and **not** applied to the native Read tool on this host/version. Secret-path screening is not a confidentiality guarantee.
- Do not re-run `rm -rf /` to “confirm again.” Do not recreate `.env` except for a later authorized check; delete it after.

Re-run the checklist after a Cursor upgrade, hook-install change, or a report that deny/ask/read behavior changed. Record a new dated section; do not silently overwrite this one.
