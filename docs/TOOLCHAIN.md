# Toolchain

Bash + jq. No Rust. No pack Python.

Need `bash` 3.2+ (no `flock`, `mapfile`, `realpath`, `stat -c`, awk `\<`) and `jq`. Windows: Git for Windows + `jq` (`winget install jqlang.jq`); `powershell -File Windows/install.ps1`.

```bash
chmod +x shared/hooks/*.sh shared/hooks/lib/*.sh scripts/*.sh
bash -n shared/hooks/before_submit_prompt.sh \
  shared/hooks/before_shell.sh shared/hooks/before_read_file.sh \
  shared/hooks/stop.sh shared/hooks/fleet_sync.sh
bash scripts/doctor.sh
bash tests/run.sh
FORCE=1 bash scripts/install.sh
```

Smoke: `echo '{"prompt":"test code","hook_event_name":"beforeSubmitPrompt"}' | bash shared/hooks/before_submit_prompt.sh`

Expect: `continue` (submit), `permission` (shell/read), `{}` or `followup_message` (stop; advisory). Submit and shell `failClosed` true. Read `failClosed` true. `stop.loop_limit` 1.

Event hooks ≤80 LOC (readability). Policy: `secret_paths.ere`, `secret_tokens.ere`, `lib/shell_gate.sh`, `lib/diff_gate.sh`. LOC 300 is `ponytail.mdc`, not a hook. SSOT: `SECURITY.md`. Pin Cursor; confirm event/timeout/ask/stop/load semantics.

## Install / doctor safety

- Idempotent: `FORCE=1 install` twice → same 4 events, same script count, no duplicate basenames (tested in `tests/install_lifecycle.sh` with isolated `HOME`).
- Ownership: differing user rules/agents kept unless `FORCE=1` (backed up once to `.pre-kleos-bak`, restored on uninstall). Uninstall removes owned-by-hash/manifest only; user files kept; second run is a no-op.
- Atomic: `hooks.json` merge/strip via `mktemp` + `mv`. Rules/hooks via `cp -f` (small files; `.bak` recovery). Interrupted install: re-run `FORCE=1 install`.
- Concurrent: no lock (`flock` unavailable on stock Bash 3.2). Avoid concurrent installs; last writer wins, `hooks.json` merge may interleave.
- Spaces: install/hook paths are quoted; read-hook blocks paths with spaces (tested). Windows: Git Bash shim (WSL fallback); verify separately.
- Symlinks: skills install as live symlinks (checkout edits affect live skills immediately; dev-friendly). Rules/hooks/agents are copies (require reinstall). Uninstall validates symlink targets (`*/kleosrules/*` or pack path) before removing; foreign links kept. No explicit dev-mode flag; document behavior and reinstall after checkout edits to rules/hooks.
- Doctor: `bash scripts/doctor.sh` inspects the selected `HOME` (real `~/.cursor` by default, read-only except a `mktemp` fixture install). Tests invoke doctor with `HOME` set to an isolated temp dir and never touch the real installation.

Uninstall: `bash scripts/uninstall.sh` (owned by hash/manifest; user files kept; `.pre-kleos-bak` restored). `manifest.json` also lists legacy cleanup targets (`wsl-shim.ps1`, `session_start.sh`) that are removed but never installed. Loads: `docs/token-budget.md`. Roofs: `docs/quality-roofs-audit.md`.

Install is machine-wide; review + restart sessions. Differing files backed up once. Skills: symlink (live) or copy (snapshot). WSL ≠ Git Bash; verify separately.
