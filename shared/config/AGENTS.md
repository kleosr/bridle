# AGENTS.md (config adapter)

@../../AGENTS.md

Thin adapter pointing to the repository agent navigator at [`../../AGENTS.md`](../../AGENTS.md). Law is paste + `.mdc` + hooks.
Specific operational notes:
- `skills.txt`: Active skills list installed to `~/.cursor/skills`.
- `scan.roots`: Opt-in repository roots for `fleet_sync.sh sync` (empty by default).
- `scan.ignore`, `retired.txt`, `retired-skills.txt`: Scan exclusions and retirement tombstones.
