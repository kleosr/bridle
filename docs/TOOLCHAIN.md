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

Expect JSON with Cursor-native keys: `continue` from beforeSubmitPrompt, `additional_context` from sessionStart, `permission` from beforeShellExecution / beforeReadFile. Cloud: `CLOUD=1 TARGET_REPO=/path/to/workspace bash shared/hooks/fleet_sync.sh project-hooks` (never against the pack). `beforeSubmitPrompt.failClosed` must be false. `beforeReadFile.failClosed` is true.

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

Installs `~/.cursor` hooks+rules+skills (global single registration layer). `hooks.json` commands stay `./hooks/*.sh` (user-hook cwd is `~/.cursor`). `sync` copies `.cursor/rules` to projects under `shared/config/scan.roots` and does **not** install or remove those projects’ `.cursor/hooks`. Hooks spawn with cwd = workspace root for project hooks; user hooks spawn with cwd = `~/.cursor`.

## Size roofs

Keep each **registered** event hook under 80 LOC (`session_start`, `before_submit_prompt`, `before_shell`, `before_read_file`). Core logic lives in `shared/hooks/lib/`. `fleet_sync.sh` is install tooling, not an event hook. `beforeReadFile` is failClosed; the other three are not.

Wired policy: `policy/*.ere` (destructive / secret_paths) consumed via `grep -f`.
