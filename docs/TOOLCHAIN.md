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
bash -n shared/hooks/stop.sh
bash -n shared/hooks/fleet_sync.sh
```

## Smoke test

```bash
echo '{"prompt": "test code", "hook_event_name": "beforeSubmitPrompt"}' \
  | bash shared/hooks/before_submit_prompt.sh
```

Expect JSON with Cursor-native keys: `continue` from beforeSubmitPrompt, `additional_context` from sessionStart, `permission` from beforeShellExecution / beforeReadFile, `{}` or `followup_message` from stop. `beforeSubmitPrompt.failClosed` must be false. `beforeReadFile.failClosed` is true. `stop.loop_limit` is 1.

## Doctor + Tests

```bash
bash scripts/doctor.sh    # environment + repo health checks
bash tests/run.sh         # syntax + JSON + hook fixtures
```

## Fleet install / sync

```bash
FORCE=1 bash scripts/install.sh
FORCE=1 bash shared/hooks/fleet_sync.sh verify
```

Installs `~/.cursor` hooks+rules+skills+agents (global single registration layer). `hooks.json` commands stay `./hooks/*.sh` (user-hook cwd is `~/.cursor`). `sync` is opt-in (`shared/config/scan.roots` empty by default) and does **not** install or remove those projects’ `.cursor/hooks`. User hooks spawn with cwd = `~/.cursor`.

## Size roofs

Keep each **registered** event hook under 80 LOC (`session_start`, `before_submit_prompt`, `before_shell`, `before_read_file`, `stop`). Core logic lives in `shared/hooks/lib/`. `fleet_sync.sh` is install tooling, not an event hook. `beforeReadFile` is failClosed; the other four are not.

Wired policy: `policy/secret_paths.ere` (`before_read_file.sh` + `before_shell.sh` via `grep -f`). `policy/secret_tokens.ere` (`before_submit_prompt.sh`). Destructive, Shell source-write, and cyclomatic-lint disable lists live inline in `lib/shell_gate.sh`. Ponytail diff roofs (LOC 300, duplicate helper) live inline in `lib/diff_gate.sh`. Human-readable SSOT: `SECURITY.md`. `bash scripts/doctor.sh` verifies the pack using an **isolated fixture HOME** (passes in CI/agent env without a live `~/.cursor` install). When your machine has a kleosrules install, doctor also reports live hook checksum drift.

**Uninstall:** `bash scripts/uninstall.sh` — removes fingerprinted kleosrules artifacts from `~/.cursor` only.

**Audit:** See `docs/engineering-rules-audit.md` for hook matrix and inventory; `docs/runtime-grounding-audit.md` for the lifecycle matrix, runtime probes, and scorecard; `docs/engineering-system.md` for the GROUND→STOP loop.
