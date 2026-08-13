user-rules map. Parent ../AGENTS.md

Layers (no double alwaysApply)
- Paste USER-RULES.paste.txt = identity + four-hook session protocol (Cursor Settings → User Rules). Re-paste after pack changes.
- User `~/.cursor/rules` (GLOBAL, once): agent.mdc, ponytail.mdc (alwaysApply); vernacular.mdc, testing.mdc (globs).
- Project `.cursor/rules` (SHARED): types.mdc (glob). Debugging is the debugging skill, not a .mdc.
- Cloud `project-hooks`: copies GLOBAL + SHARED into TARGET_REPO (cloud cannot see ~/.cursor).

Steel vs steering
- Steering: .mdc + skills (model follows). Skills = Read SKILL.md or /name; hooks never invoke them.
- Steel: four registered hooks + policy/secret_paths.ere. Shell deny list is inline in shell_gate.sh.

Done: paste USER-RULES then new chat; FORCE=1 bash scripts/install.sh
Hard stops: no secrets in paste; no Rust claims; Cursor-native field names (additional_context, permission, continue)
