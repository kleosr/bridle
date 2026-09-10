# Host capability matrix (v2)

Living. Not law. Not injected. Not installed.

Scripts and `hooks.json` are the pack contract. This file records **where those contracts can run** and **what a live host actually did**. Script fixtures in `tests/` do not prove host behavior. A dated check does not survive a Cursor update.

SSOT for steel (what scripts emit): `SECURITY.md`. SSOT for why four events: `docs/DECISIONS/hooks.md`.

## Lane split

| Lane | Hook config the host loads | This pack |
|---|---|---|
| Local Agent / Chat | User hooks: `~/.cursor/hooks.json` | Default install (`FORCE=1 bash scripts/install.sh`) |
| Cloud agent | **Project** hooks only: `<repo>/.cursor/hooks.json` | **Opt-in.** `CLOUD=1 TARGET_REPO=<other-repo> project-hooks` writes `hooks.cloud.json` into that repo. Never this pack. |
| Cloud agent + user hooks | `~/.cursor/hooks.json` is **not** available on the cloud VM | Local steel does **not** follow the user into cloud |
| This pack checkout | No repo-level `.cursor/hooks.json` | Cloud work **on this repo** has no pack hooks unless someone adds project hooks |

## Event matrix

`reg` = registered in that JSON. `avail` = Cursor documents the event for that lane. `—` = not available or not registered.

| Event | Local avail | Local pack | Cloud avail | Cloud pack (`hooks.cloud.json`) |
|---|---|---|---|---|
| `beforeSubmitPrompt` | yes | **reg**, `failClosed:true` | yes | **reg**, `failClosed:true` (if project-hooks applied) |
| `beforeShellExecution` | yes | **reg**, `failClosed:true` | yes | **reg**, `failClosed:true` |
| `beforeReadFile` | yes | **reg**, `failClosed:true` | yes | **reg**, `failClosed:true` |
| `stop` | yes | **reg**, `failClosed:false`, `loop_limit:1` | yes (docs) | **omitted** (unverified on cloud) |
| `beforeMCPExecution` / `afterMCPExecution` | yes | omitted | deferred (docs) | omitted |
| `preToolUse` / `postToolUse` / `afterFileEdit` | yes | omitted (no `updated_input`) | yes | omitted |
| `subagentStart` / `subagentStop` | yes | omitted | yes | omitted |
| `sessionStart` / `sessionEnd` | yes | omitted | no | omitted |
| Tab read/edit | yes | omitted | no | omitted |

Default `failClosed` in Cursor is **false** (fail-open on crash/timeout/invalid JSON). This pack sets `true` on submit/shell/read. That is a **request**. Host honor of `failClosed` is a live-check row, not a script guarantee.

`ask` is a documented permission result for `beforeShellExecution`. It is useful only if the client pauses. Do not treat `ask` as a critical gate.

## Live checks

No v2 live check has been run yet. The v18 check (2026-09-10, Cursor 3.19.19) observed: Shell deny honored; Shell `ask` did not pause; Read deny from the script was not applied to the native Read tool; `failClosed` crash path and prompt-scan-before-transmit not run. That evidence belongs to the v18 tree and is **not** carried forward as a v2 claim.

Re-run the `SECURITY.md` checklist in a live session with this pack installed and record a new dated section here; do not silently overwrite. Re-run after a Cursor upgrade, hook-install change, or a report that deny/ask/read behavior changed.
