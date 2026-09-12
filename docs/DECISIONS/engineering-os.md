# Engineering OS (ADR)

Status: Accepted. Not injected. Not installed.

The pack is an engineering operating system for autonomous coding agents: a small always-on roof, glob companions, on-match skills, and four hooks. It is not a prompt encyclopedia.

## Layers

| Layer | Job | Loaded |
|---|---|---|
| Charter | Identity, approval, evidence | User Rules paste, every host |
| Core | Craft, ladder, types, complexity, stack, harness | `core.mdc` + `testing.mdc` always-on |
| Companion | Stack facts | glob `.mdc` |
| Skill | Procedures | `ponytail`, `debugging`, `testing` on match |
| Steel | Deterministic gates | four hooks + `lib/host.sh` |

## Architecture

Own one job per module. Do not widen a public interface to land a local fix. Do not mix ownership (package, layer, or framework) inside one change unless that is the task.

Design UI skills live in `optional/design/` and are not installed.

## Verify sensor

`stop.sh` calls `verify_gate.sh`: `bash -n` / `jq empty` on changed shell/JSON. It does **not** execute `package.json` scripts or `make test` from a global hook (untrusted, side-effecting). Citation of a real run remains law in `testing.mdc`.

## Host adapter

`lib/host.sh` + `KLEOS_HOST=claude` maps deny/ask onto Claude Code `permissionDecision`. Default JSON stays Cursor `{permission}`. Portable law: `shared/hosts/CLAUDE.md`.
