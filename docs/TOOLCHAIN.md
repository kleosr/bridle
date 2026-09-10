# Toolchain

Bash + jq. No Rust. No pack Python.

Need `bash` 3.2+ (no `flock`, `mapfile`, `realpath`, `stat -c`) and `jq`. Windows: Git for Windows + `jq`; run everything from Git Bash.

```bash
chmod +x shared/hooks/*.sh shared/hooks/lib/*.sh scripts/*.sh
bash -n shared/hooks/before_submit_prompt.sh \
  shared/hooks/before_shell.sh shared/hooks/before_read_file.sh \
  shared/hooks/stop.sh shared/hooks/fleet_sync.sh
bash scripts/doctor.sh
bash tests/run.sh
FORCE=1 bash scripts/install.sh
```

Smoke: `echo '{"prompt":"test code"}' | bash shared/hooks/before_submit_prompt.sh`

Expect: `continue` (submit), `permission` (shell/read), `{}` or `followup_message` (stop; advisory). Submit, shell, and read are `failClosed:true`. `stop.loop_limit` is 1.

Event hooks ≤80 LOC (readability). Policy: `secret_paths.ere`, `secret_tokens.ere`, `lib/shell_gate.sh`, `lib/diff_gate.sh`. LOC 300 is `ponytail.mdc`, not a hook. Boundary SSOT: `SECURITY.md`.

## Install / doctor safety

- Idempotent: `FORCE=1 install` twice → same 4 events, same script count, no duplicate basenames (tested in `tests/install_lifecycle.sh` with isolated `HOME`).
- Ownership: differing user rules/agents kept unless `FORCE=1` (backed up once to `.pre-kleos-bak`, restored on uninstall). Hook ownership is exact-basename only — a user hook whose name merely contains a pack name is never stripped (tested). Uninstall removes owned-by-hash/manifest only; user files kept; second run is a no-op.
- Atomic: `hooks.json` merge/strip via `mktemp` + `mv`. Rules/hooks via `cp -f` (small files; `.bak` recovery). Interrupted install: re-run `FORCE=1 install`.
- Concurrent: no lock (`flock` unavailable on stock Bash 3.2). Avoid concurrent installs; last writer wins, `hooks.json` merge may interleave.
- Spaces: install/hook paths are quoted; read-hook blocks paths with spaces (tested).
- Shell splitting: the gate splits on operators outside quotes (awk state machine); newlines fold to `;`. `$()`/subshell internals are not fully parsed — stronger guarantees need OS sandboxing, not more regex.
- Symlinks: skills install as live symlinks (checkout edits affect the installed snapshot immediately on Unix).
- Activation: installer-path checks use the payload `cwd`, never the hook process cwd.
- Doctor modes (same script; fixture is **not** proof of live): default = pack + isolated fixture + optional live check. `DOCTOR_SKIP_LIVE=1` = pack + fixture; success is checkout-only (`CHECKOUT CHECKS PASSED`) and does **not** claim the active `~/.cursor` was verified.
- Dry-run: `DRY_RUN=1 bash shared/hooks/fleet_sync.sh install` prints planned writes and exits without touching `$HOME`.

Uninstall: `bash scripts/uninstall.sh` (owned by hash/manifest; user files kept; `.pre-kleos-bak` restored). `manifest.json` also lists legacy cleanup targets that are removed but never installed.

Install is machine-wide; review + restart sessions. Differing files backed up once.
