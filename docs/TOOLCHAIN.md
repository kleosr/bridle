# Toolchain

Bash + jq. No Rust. No pack Python.

Need `bash` 3.2+ (no `flock`, `mapfile`, `realpath`, `stat -c`, awk `\<`) and `jq`.

```bash
chmod +x shared/hooks/*.sh shared/hooks/lib/*.sh scripts/*.sh
bash -n shared/hooks/session_start.sh shared/hooks/before_submit_prompt.sh \
  shared/hooks/before_shell.sh shared/hooks/before_read_file.sh \
  shared/hooks/stop.sh shared/hooks/fleet_sync.sh
bash scripts/doctor.sh
bash tests/run.sh
FORCE=1 bash scripts/install.sh
```

Smoke: `echo '{"prompt":"test code","hook_event_name":"beforeSubmitPrompt"}' | bash shared/hooks/before_submit_prompt.sh`

Expect: `continue` (submit), `additional_context` (sessionStart), `permission` (shell/read), `{}` or `followup_message` (stop). Submit `failClosed` false. Read `failClosed` true. `stop.loop_limit` 1.

Event hooks ≤80 LOC. Policy: `secret_paths.ere`, `secret_tokens.ere`, `lib/shell_gate.sh`, `lib/diff_gate.sh`. LOC 300 is `ponytail.mdc`, not a hook. SSOT: `SECURITY.md`. Doctor uses an isolated HOME.

Uninstall: `bash scripts/uninstall.sh`. Caps: `docs/token-budget.md`. Roofs: `docs/quality-roofs-audit.md`.
