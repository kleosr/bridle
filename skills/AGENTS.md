# AGENTS.md — map (nested)

**Parent map:** [`../AGENTS.md`](../AGENTS.md)

## Scope

On-demand Cursor skills installed to `~/.cursor/skills`. Catalog = `config/skills.txt` (not every folder on disk if retired).

## Where to look

| Group | Skills (dir = `skills/<name>/`) |
|-------|----------------------------------|
| Native Lean | `ponytail`, `lean-code` (alias), `vernacular`, `testing`, `unconditional-counterexample`, `breakthrough-deepen` |
| Architecture | `architecture-fitness`, `improve-codebase-architecture`, `domain-architecture`, `agents-map`, `workspace-scope`, `system-wiring`, `codebase-memory`, `obsidian-memory` |
| Frontend / design | `design-taste-frontend`, `ui-ux-audit`, `frontend-design`, `design-tokens`, `ui-structure`, `no-hardcode` |
| Ship / harness | `git-commit`, `create-pr`, `bug-hunt`, `formulary`, `ship-loop`, `session-handoff`, `eval-pass`, `harness-retro`, `grill-me`, `humanizer` |
| Product / voice | `cursor-research`, `benln-write` |

| Task | Location | Notes |
|------|----------|-------|
| Skill entry | `<name>/SKILL.md` | Required |
| Vernacular template | `vernacular/TEMPLATE.md` | Copy → `.cursor/rules/vernacular.mdc` |
| Agents-map templates | `agents-map/references/` | root / nested / TOOLCHAIN |
| Formulary refs | `formulary/references/` | Grok harness discipline |
| Humanizer refs | `humanizer/references/`, `humanizer/wispr-flow/` | Tone + samples |
| Retired list | `../config/retired-skills.txt` | Do not reinstall |

## Done (local)

After skill text edits that install syncs: `FORCE=1 bash hooks/fleet_sync.sh all` (or `install` / `verify`). No separate unit suite for skills.

## Ask first

- Adding a skill without listing it in `config/skills.txt`
- Retiring a skill still referenced by User Rules / companions

## Manual notes

<!-- Preserved on refresh -->
