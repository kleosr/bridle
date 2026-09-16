# Toolchain

I've seen too many agent setups collapse because they depend on heavy background daemons, native binaries, or complicated runtimes that work on Linux and completely disintegrate on Windows. 

`bridle` takes the opposite approach: zero bloat, zero native daemon magic, and standard POSIX utilities that have worked for decades. It runs on macOS, Linux, and Windows (via Git Bash) from the same codebase.

## What You Need to Run This

| Dependency | Purpose | Where Used |
|---|---|---|
| **Bash 3.2+** | Core runtime; in-process regex matching (`[[ =~ ]]`) | Hooks, scripts, test runner |
| **Python 3** or **Node.js** | Safe, reliable JSON codec (`json_tool.py` / `json_tool.js`) | Hook stdin/stdout payload parsing |
| **`jq` (1.6+)** | Fast JSON querying for tooling and test fixtures | Scripts, install merge, test gauntlet (hooks don't need it) |
| **PowerShell 5.1+ / pwsh** | Native Windows bridge (`git-bash-shim.ps1`) | Windows Cursor hook execution |

*Note for Windows users:* Always run harness scripts from **Git Bash**. Make sure `jq` is installed and on your user `PATH` (e.g. `winget install jqlang.jq`, and verify `%LOCALAPPDATA%\Microsoft\WinGet\Links` is in your environment variables).

## Daily Driver Commands

These are the exact commands I use daily to test, verify, and maintain the harness:

```bash
# 1. Quick environment readiness check
bash scripts/ready.sh

# 2. Pack inventory and fixture check (safe, doesn't touch your live ~/.cursor)
DOCTOR_SKIP_LIVE=1 bash scripts/doctor.sh

# 3. Full inventory + verifies your live ~/.cursor installation
bash scripts/doctor.sh

# 4. The full gauntlet (134 tests: fixtures, gate edges, lifecycle)
bash tests/run.sh

# 5. Scoped test run (fast, runs only the suite you care about)
TESTS=gate_edges bash tests/run.sh

# 6. Check eval dimension coverage
bash scripts/eval.sh check

# 7. Check feature state ledger (this pack: shared/config/features.json;
#    any other repo: <root>/.cursor/bridle/features.json — resolved from the cwd)
bash scripts/feature.sh check

# 8. Check session handoff schema
bash scripts/handoff.sh check

# 9. Install into ~/.cursor (backs up your existing files automatically)
FORCE=1 bash scripts/install.sh

# 10. Clean uninstall (removes bridle files and restores your backups)
bash scripts/uninstall.sh
```

## Hook Protocol & Fast Smoke Tests

Every hook reads JSON on `stdin` and writes JSON on `stdout`. There are no hidden sockets, no sidecars, and no network dependencies.

- **`beforeSubmitPrompt`**: Returns `{"continue": true}` or `{"continue": false, "reason": "...", "user_message": "..."}`.
- **`beforeShellExecution`**: Returns `{"permission": "allow"}`, `{"permission": "deny", ...}`, or `{"permission": "ask", ...}`.
- **`beforeReadFile`**: Returns `{"permission": "allow"}` or `{"permission": "deny", ...}`.
- **`stop`**: Returns `{}` or `{"followup_message": "..."}` (advisory only; never blocks).

### Fast Smoke Check from the Terminal
Want to test the hooks by hand right now? Run these directly:

```bash
echo '{"prompt":"test code"}' | bash shared/hooks/before_submit_prompt.sh
echo '{"command":"git status","cwd":"/tmp"}' | bash shared/hooks/before_shell.sh
echo '{"file_path":"/tmp/test.txt"}' | bash shared/hooks/before_read_file.sh
```

## Install & Lifecycle Guarantees

I spent a lot of time engineering the install/uninstall scripts so they never corrupt your environment:

1. **Idempotence:** Running `FORCE=1 bash scripts/install.sh` ten times in a row leaves your system in the exact same clean state as running it once.
2. **Safe Backups:** If you have custom user rules or hooks with the same name, the installer saves them as `.pre-kleos-bak` before overwriting.
3. **Exact Ownership:** Ownership in `~/.cursor/hooks.json` is determined by exact script basename (`before_submit_prompt.sh`, etc.). If you have your own hook called `my_custom_before_shell.sh`, the installer will never touch or strip it.
4. **Clean Uninstall:** `bash scripts/uninstall.sh` removes only files owned by the pack manifest, restores your `.pre-kleos-bak` backups, and cleans up compiled helper caches (`KleosPipeUtil.dll`).
5. **Atomic Updates:** `hooks.json` writes use atomic temp-file replacement (`mktemp` -> `mv`). If an install is interrupted mid-write, your `hooks.json` won't be left as a truncated, corrupt JSON file.
6. **Windows P/Invoke Caching:** On Windows, `git-bash-shim.ps1` compiles its Windows API helper once into `~/.cursor/hooks/KleosPipeUtil.dll`. Every run after that loads the compiled DLL directly, completely eliminating the 1-3 second `csc.exe` compile overhead.
