# Toolchain: Bash & jq Validation

No Rust. No Cargo. No Python. Mechanical checks are Bash.

## Prerequisites

- `bash` (v3.2+ — stock macOS bash works; hooks avoid GNU-only utils: no `flock`, `mapfile`, `realpath`, `stat -c`, awk `\<` boundaries)
- `jq` (JSON parsing in hooks; macOS: `brew install jq`)
- Cursor IDE (runs the hooks)

## Syntax check

```bash
chmod +x MacOS/hooks/*.sh MacOS/hooks/lib/*.sh

bash -n MacOS/hooks/session_start.sh
bash -n MacOS/hooks/before_submit_prompt.sh
bash -n MacOS/hooks/stop_gate.sh
bash -n MacOS/hooks/lean_gate.sh
bash -n MacOS/hooks/pre_tool_use.sh
bash -n MacOS/hooks/fleet_sync.sh
```

## Smoke test

```bash
echo '{"prompt": "test code", "hook_event_name": "beforeSubmitPrompt"}' \
  | bash MacOS/hooks/before_submit_prompt.sh
```

Expect JSON with `additionalContext` (and, on stop fixtures, `followup_message` when INTENT is missing).

## Doctor + Tests

```bash
bash scripts/doctor.sh    # environment + repo health checks
bash tests/run.sh         # syntax + JSON + hook fixtures
```

## Fleet install / sync

```bash
FORCE=1 bash MacOS/hooks/fleet_sync.sh all
FORCE=1 bash MacOS/hooks/fleet_sync.sh verify
```

Installs `~/.cursor` hooks+rules+skills, syncs `.cursor/rules` + Bash hooks to every project under `config/scan.roots`.

## Size roofs

Keep each **event** hook under 80 LOC (`session_start`, `before_submit_prompt`, `stop_gate`, `lean_gate`, `pre_tool_use`). Core logic lives in `MacOS/hooks/lib/`. `fleet_sync.sh` is install tooling, not an event hook. Fail closed: bad parse or failed exec should block or return deny JSON.

Wired policy only: `MacOS/hooks/policy/intent.json` (INTENT roofs) and `MacOS/hooks/policy/lean.json` (`file_loc_max`, `complexity_max`, `func_complexity_max`, `coupling_max`, `nesting_max`, `edit_velocity_max`).
