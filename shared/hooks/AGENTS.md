# AGENTS.md (hooks adapter)

@../../AGENTS.md

Thin adapter pointing to the repository agent navigator at [`../../AGENTS.md`](../../AGENTS.md). Law is paste + `.mdc` + hooks.
Specific operational notes:
- Registered Bash hooks in this directory: `session_start.sh`, `before_submit_prompt.sh`, `before_shell.sh`, `before_read_file.sh`, `stop.sh`.
- Event hooks stay <= 80 LOC. Core logic in `lib/common.sh`, `lib/shell_gate.sh`, `lib/diff_gate.sh`.
