# AGENTS.md (hooks adapter)

@../../AGENTS.md

Thin adapter pointing to canonical repository agent handbook at [`../../AGENTS.md`](../../AGENTS.md).
Specific operational notes:
- Registered Bash hooks in this directory: `session_start.sh`, `before_submit_prompt.sh`, `before_shell.sh`, `before_read_file.sh`.
- Event hooks stay <= 80 LOC. Core logic in `lib/common.sh` and `lib/shell_gate.sh`.
