# kleosrules

Agent engineering pack: charter, `core.mdc` + `testing.mdc`, glob companions, skills, four Bash hooks, and machine-readable feature/handoff contracts. Design UI skills live in `optional/design/` and are not installed.

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
bash scripts/ready.sh           # L06 bootstrap contract (does not run the suite)
bash scripts/eval.sh check      # eval dimension coverage
bash scripts/doctor.sh            # pack + fixture + live checksums
DOCTOR_SKIP_LIVE=1 bash scripts/doctor.sh  # checkout only
bash scripts/feature.sh check     # pass-state invariants
```

Run from Git Bash on Windows.

## Layout

| Path | Job |
|---|---|
| `AGENTS.md` | Directory page (not an encyclopedia) |
| `shared/config/harness.json` | Machine-readable runtime contract |
| `shared/config/features.json` | Capability state (pass via `scripts/feature.sh`) |
| `shared/schema/` | Feature, handoff, eval, and hook I/O contracts |
| `state/handoff.json` | Optional session snapshot (gitignored) |
| `evals/tasks.json` | Deterministic harness eval index |
| `shared/rules/` | Charter paste + always-on / glob `.mdc` |
| `shared/skills/` | On-demand skill bodies |
| `shared/hosts/` | Portable `CLAUDE.md` |
| `optional/design/` | UI skills, not installed |
| `shared/agents/` | `hunter` / `cut` / `prove` specialists |
| `shared/hooks/` | Four event scripts + `git-bash-shim.ps1` + `lib/` + `policy/` |
| `shared/config/` | Installed names, absence lists, `manifest.json` |
| `scripts/` | `install.sh`, `uninstall.sh`, `doctor.sh`, `ready.sh`, `eval.sh`, `feature.sh`, `handoff.sh` |
| `tests/` | Fixture + edge + lifecycle + harness suites |
| `docs/` | Architecture, toolchain, decisions, host evidence |

## Docs

- `SECURITY.md` — the boundary (read before security-sensitive changes).
- `docs/ARCHITECTURE.md` — layers and channels.
- `docs/TOOLCHAIN.md` — commands and install safety.
- `docs/DECISIONS/hooks.md` — why four hooks.
- `docs/DECISIONS/engineering-os.md` — principles, source boundary, and runtime contract.
- `docs/host-capability.md` — live host evidence (not law).
