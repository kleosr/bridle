# AGENTS.md — map (nested)

**Parent map:** [`../AGENTS.md`](../AGENTS.md)

## Scope

Install/sync inputs: which skills ship, which repos get scanned, retire lists.

## Where to look

| File | Role |
|------|------|
| `skills.txt` | Harness-owned personal skill directory names |
| `scan.roots` | Opt-in roots for `fleet_sync.sh sync` (empty = no other repos) |
| `scan.ignore` | Paths/repos skipped by scan |
| `retired-skills.txt` | Skills not to install |
| `retired.txt` | Retired pack items |

## Done (local)

After edits: `FORCE=1 bash scripts/install.sh` then `bash shared/hooks/fleet_sync.sh verify`.

## Ask first

- Adding scan roots that write into live app repos (`sync` only)

## Manual notes

<!-- Preserved on refresh -->
