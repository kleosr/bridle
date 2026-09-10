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
- Symlinks: skills install as live symlinks (checkout edits affect the Unix installed snapshot immediately). Windows `install.ps1` copies skills (snapshot; checkout edits do not update the session catalog). Pack retired leftovers are moved to `~/.cursor/kleos-bak/skills/` (never `SKILL.md` under `~/.cursor/skills/*.pre-kleos-bak` for retired stems). Existing kleos-bak entries are not overwritten. Foreign `*.pre-kleos-bak` names are left in `skills/`. Rules/hooks/agents are copies (require reinstall). Uninstall validates symlink targets (`*/kleosrules/*` or pack path) before removing; foreign links kept. No explicit dev-mode flag. `Windows/hooks/bash-shim.ps1` exits with the hook process code (or 1 if bash does not start). That is shim process status, not proof of Cursor `failClosed` enforcement.
- Doctor modes (same script; fixture is **not** proof of live): default = pack + isolated fixture + optional live checksum. `DOCTOR_SKIP_LIVE=1` = pack + fixture; success is checkout-only (`CHECKOUT CHECKS PASSED`) and does **not** claim the active `~/.cursor` was verified. `DOCTOR_SKIP_FIXTURE=1` = pack + live diagnosis only. Live drift remains `[fail]` when live checks run.
- Dry-run: `DRY_RUN=1 bash shared/hooks/fleet_sync.sh install` prints planned writes and exits without touching `$HOME`.

Uninstall: `bash scripts/uninstall.sh` (owned by hash/manifest; user files kept; `.pre-kleos-bak` restored). `manifest.json` also lists legacy cleanup targets (`wsl-shim.ps1`, `session_start.sh`) that are removed but never installed. Loads: `docs/token-budget.md`. Roofs: `docs/quality-roofs-audit.md`.

Install is machine-wide; review + restart sessions. Differing files backed up once. Skills: symlink (live) or copy (snapshot). WSL ≠ Git Bash; verify separately.

## Policy evidence (scripts)

| Policy | Allowed | Denied/ask | Failure |
|---|---|---|---|
| Sensitive reads | Ordinary source | Protected path | Missing policy / non-JSON → deny |
| Shell gate | Normal build / `git status` | Destructive / source-write / secret path | Malformed / non-string / missing jq → deny |
| Infra | — | Recognized DB/infra strings → ask | Host pause unverified |
| Installer ownership | Preserve unrelated entry | Remove owned unchanged | Differing owned kept unless FORCE=1 |
| Framework companion | Owning package matches | Unmatched package → inert (law) | Missing package.json → silent stack pick |

Unit/fixture tests: `tests/run.sh`. Host integration: `SECURITY.md` manual check. Model-behavior evals: `tests/eval_corpus.sh` `[info]` rubric (not executable proof).

