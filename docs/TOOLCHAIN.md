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
bash -n shared/hooks/stop_gate.sh
bash -n shared/hooks/lean_gate.sh
bash -n shared/hooks/pre_tool_use.sh
bash -n shared/hooks/fleet_sync.sh
```

## Smoke test

```bash
echo '{"prompt": "test code", "hook_event_name": "beforeSubmitPrompt"}' \
  | bash shared/hooks/before_submit_prompt.sh
```

Expect JSON with `additionalContext` (and, on stop fixtures, `followup_message` when INTENT is missing).

## Doctor + Tests

```bash
bash scripts/doctor.sh    # environment + repo health checks
bash tests/run.sh         # syntax + JSON + hook fixtures
```

## Fleet install / sync

```bash
FORCE=1 bash shared/hooks/fleet_sync.sh all
FORCE=1 bash shared/hooks/fleet_sync.sh verify
```

Installs `~/.cursor` hooks+rules+skills (global single registration layer), syncs `.cursor/rules` to every project under `shared/config/scan.roots`, and REMOVES per-repo `.cursor/hooks.json` — repo registration double-fired alongside the global one and doubled per-prompt token injection. Hooks spawn with cwd = workspace root, so HANDOFF/state stay per-project.

## Size roofs

Keep each **event** hook under 80 LOC (`session_start`, `before_submit_prompt`, `stop_gate`, `lean_gate`, `pre_tool_use`). Core logic lives in `shared/hooks/lib/`. `fleet_sync.sh` is install tooling, not an event hook. Fail closed: bad parse or failed exec should block or return deny JSON.

Wired policy only: `shared/hooks/policy/intent.json` (INTENT roofs) and `shared/hooks/policy/lean.json` (`file_loc_max`, `complexity_max`, `func_complexity_max`, `coupling_max`, `nesting_max`, `edit_velocity_max`).
