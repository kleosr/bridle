# AGENTS.md — map (nested)

**Parent map:** [`../AGENTS.md`](../AGENTS.md)

## Scope

Install/sync inputs: which skills ship, which repos get scanned, retire lists.

## Where to look

| File | Role |
|------|------|
| `skills.txt` | Harness-owned personal skill directory names |
| `scan.roots` | Fleet roots for `fleet_sync.sh` discover |
| `scan.ignore` | Paths/repos skipped by scan |
| `retired-skills.txt` | Skills not to install |
| `retired.txt` | Retired pack items |

## Done (local)

After edits: `FORCE=1 bash shared/hooks/fleet_sync.sh all` (or `sync` / `verify`).

## Ask first

- Adding scan roots that write into many live app repos

## Manual notes

<!-- Preserved on refresh -->
