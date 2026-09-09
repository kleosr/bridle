# NOW.md (optional handoff note)

Goal: Bounded cleanup on `simplify-optional-now-no-budget` — optional NOW, no budget bureaucracy, no sessionStart, no fleet discovery.

State: All edits applied. Syntax green. Doctor green except 2 expected live-checksum drifts (branch changed before_shell.sh + common.sh; live install untouched). Suite re-run in progress after fixing 3 jq-precedence assertions + 1 Windows ln -s test assumption.
Evidence: doctor 12s run; suite run 1: 3 fails (jq `has`), all diagnosed, fixes applied.
Next: Confirm suite run 2 is green; do NOT install to live ~/.cursor without approval.
