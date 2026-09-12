# kleosrules

Agent engineering pack: charter, `core.mdc` + `testing.mdc`, glob companions, skills, and four Bash hooks (local install). Design UI skills live in `optional/design/` and are not installed.

## Install

```bash
FORCE=1 bash scripts/install.sh
```

Then paste `shared/rules/USER-RULES.paste.txt` into Cursor Settings → User Rules and start a new chat.

Cloud agents (project hooks only, opt-in):

```bash
CLOUD=1 TARGET_REPO=<other-repo> bash shared/hooks/fleet_sync.sh project-hooks
```

Never install project hooks into this pack.

## Verify

```bash
bash tests/run.sh                 # isolated fixtures, no live install
bash scripts/doctor.sh            # pack + fixture + live checksums
DOCTOR_SKIP_LIVE=1 bash scripts/doctor.sh  # checkout only
```

Run from Git Bash on Windows.

## Layout

| Path | Job |
|---|---|
| `shared/rules/` | Charter paste + always-on / glob `.mdc` |
| `shared/skills/` | On-demand skill bodies |
| `shared/hosts/` | Portable `CLAUDE.md` |
| `optional/design/` | UI skills, not installed |
| `shared/agents/` | `hunter` / `cut` / `prove` specialists |
| `shared/hooks/` | Four event scripts + `lib/` + `policy/` |
| `shared/config/` | `rules.global.txt`, `skills.txt`, absence lists, `manifest.json` |
| `scripts/` | `install.sh`, `uninstall.sh`, `doctor.sh` |
| `tests/` | Fixture + edge + lifecycle suites |
| `docs/` | Architecture, toolchain, decisions, host evidence |

## Docs

- `SECURITY.md` — the boundary (read before security-sensitive changes).
- `docs/ARCHITECTURE.md` — layers and channels.
- `docs/TOOLCHAIN.md` — commands and install safety.
- `docs/DECISIONS/hooks.md` — why four hooks.
- `docs/DECISIONS/engineering-os.md` — layer map and verify sensor.
- `docs/host-capability.md` — live host evidence (not law).
