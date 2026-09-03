# Toolchain: Bash & jq Validation

No Rust. No Cargo. No Python. Mechanical checks are Bash.

## Prerequisites

- `bash` (v3.2+ — stock macOS bash works; hooks avoid GNU-only utils: no `flock`, `mapfile`, `realpath`, `stat -c`, awk `\<` boundaries)
- `jq` (JSON parsing in hooks; macOS: `brew install jq`)
- Cursor IDE (runs the hooks)

## Syntax check

```bash
chmod +x shared/hooks/*.sh shared/hooks/lib/*.sh

bash -n shared/hooks/session_start.sh
bash -n shared/hooks/before_submit_prompt.sh
bash -n shared/hooks/before_shell.sh
bash -n shared/hooks/before_read_file.sh
bash -n shared/hooks/fleet_sync.sh
```

## Smoke test

```bash
echo '{"prompt": "test code", "hook_event_name": "beforeSubmitPrompt"}' \
  | bash shared/hooks/before_submit_prompt.sh
```

Expect JSON with Cursor-native keys: `continue` from beforeSubmitPrompt, `additional_context` from sessionStart, `permission` from beforeShellExecution / beforeReadFile. `beforeSubmitPrompt.failClosed` must be false. `beforeReadFile.failClosed` is true.

## Doctor + Tests

```bash
bash scripts/doctor.sh    # environment + repo health checks
bash tests/run.sh         # syntax + JSON + hook fixtures
```

## Fleet install / update / uninstall

```bash
FORCE=1 bash scripts/install.sh                 # install or update (idempotent)
FORCE=1 bash shared/hooks/fleet_sync.sh verify  # post-install smoke
bash scripts/uninstall.sh                       # remove only pack-owned files from ~/.cursor
```

Uninstall removes: `~/.cursor/hooks.json` (only when it references `before_submit_prompt.sh`), the four hook scripts, `lib/common.sh`, `lib/shell_gate.sh`, `policy/*.ere`, the ten pack `.mdc` rules, pack skill symlinks (only when they point into this pack), `agents/{hunter,cut,prove}.md`, and the pack's own `.cursor/rules/types.mdc`. Anything else under `~/.cursor` is left alone. Tested in `tests/audit.sh` against a fake `HOME`.

Installs `~/.cursor` hooks+rules+skills+agents (global single registration layer). `hooks.json` commands stay `./hooks/*.sh` (user-hook cwd is `~/.cursor`). `sync` is opt-in (`shared/config/scan.roots` empty by default) and does **not** install or remove those projects’ `.cursor/hooks`. User hooks spawn with cwd = `~/.cursor`.

## Size roofs

Keep each **registered** event hook under 80 LOC (`session_start`, `before_submit_prompt`, `before_shell`, `before_read_file`). Core logic lives in `shared/hooks/lib/`. `fleet_sync.sh` is install tooling, not an event hook. `beforeReadFile` is failClosed; the other three are not.

Wired policy: `policy/secret_paths.ere` (`before_read_file.sh` + `before_shell.sh` via `grep -f`). `policy/secret_tokens.ere` (`before_submit_prompt.sh`). Destructive, Shell source-write, and cyclomatic-lint disable lists live inline in `lib/shell_gate.sh`. Human-readable SSOT: `SECURITY.md`. `bash scripts/doctor.sh` checksums `~/.cursor/hooks` against the pack when the global install exists.

## Failure semantics (tested in `tests/audit.sh`)

| Input | `before_shell.sh` | `before_read_file.sh` | `before_submit_prompt.sh` | `session_start.sh` |
|---|---|---|---|---|
| Valid payload | allow / deny / ask | allow / deny | continue true/false | `additional_context` or `{}` |
| Non-JSON | `ask` + message | `deny` + message | `continue:false` | `{}` or NOW inject (payload unused) |
| Field missing | `ask` + message | allow (no path to judge) | `continue:true` | inject |
| Policy file missing | secret-path scan skipped; other gates run | `deny` + message | `continue:true` | inject |
| `jq` broken | exit 127, no stdout → Cursor fail-open (`failClosed:false`) | exit 127 → Cursor `failClosed:true` denies | exit non-zero → fail-open | exit non-zero → no inject |
| Timeout | Cursor enforces `timeout` from `hooks.json` (30s shell, 10s others); hooks do one `grep` pass, no network, no loops over input | | | |

Interruption: every hook reads all of stdin, decides, and prints exactly one JSON object at the end; there is no partial-output path. Not automated.
