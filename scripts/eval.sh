#!/usr/bin/env bash
# Structural harness eval. Does not execute the pack gauntlet (that would recurse).
# Coverage of required dimensions + closed layers. JSON on stdout.
set -euo pipefail

PACK="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=shared/hooks/lib/common.sh
source "$PACK/shared/hooks/lib/common.sh"
require_jq
FILE="${EVAL_FILE:-$PACK/evals/tasks.json}"
HARNESS="${HARNESS_FILE:-$PACK/shared/config/harness.json}"

usage() {
  echo "usage: bash scripts/eval.sh check" >&2
  echo "what: structural coverage of eval dimensions. why: an index is not a scorer." >&2
  echo "fix: add a tasks[] row for each requiredEvalDimensions entry; keep layer in harness.json layers." >&2
  exit 2
}

[[ "${1:-}" == "check" ]] || usage
[[ -f "$FILE" ]] || { echo "missing $FILE" >&2; echo "fix: restore evals/tasks.json" >&2; exit 1; }
[[ -f "$HARNESS" ]] || { echo "missing $HARNESS" >&2; echo "fix: restore shared/config/harness.json" >&2; exit 1; }
jq empty "$FILE" >/dev/null 2>&1 || { echo "evals/tasks.json is not JSON" >&2; exit 1; }
jq -e '
  .version == 1
  and (.dimensions | type == "array" and all(.[]; type == "string" and length > 0))
  and (.tasks | type == "array" and all(.[];
    (.id | type == "string" and length > 0)
    and (.dimension | type == "string" and length > 0)
    and (.layer | type == "string" and length > 0)
    and (.proves | type == "string" and length > 0)))
' "$FILE" >/dev/null || { echo "evals/tasks.json failed schema" >&2; exit 1; }
jq -e '.requiredEvalDimensions | type == "array" and length > 0' "$HARNESS" >/dev/null \
  || { echo "harness.json missing requiredEvalDimensions" >&2; exit 1; }
jq -e '.layers | type == "array" and length > 0' "$HARNESS" >/dev/null \
  || { echo "harness.json missing layers" >&2; exit 1; }

dup="$(jq -r '.tasks | group_by(.id) | map(select(length > 1)[0].id) | .[]?' "$FILE")"
[[ -z "$dup" ]] || { echo "eval duplicate task id: $dup" >&2; exit 1; }

unknown_dimension="$(jq -r --slurpfile e "$FILE" '[.tasks[]?.dimension | select(. as $d | $e[0].dimensions | index($d) | not)] | .[]?' "$HARNESS")"
[[ -z "$unknown_dimension" ]] || { echo "eval unknown dimension: $unknown_dimension" >&2; exit 1; }

missing=""
while IFS= read -r d; do
  [[ -z "$d" ]] && continue
  if ! jq -e --arg d "$d" '.tasks | any(.dimension == $d)' "$FILE" >/dev/null; then
    missing="${missing}${d} "
  fi
done < <(jq -r '.requiredEvalDimensions[]' "$HARNESS")
[[ -z "$missing" ]] || { echo "eval missing required dimension: $missing" >&2; echo "fix: add a tasks[] row with that dimension" >&2; exit 1; }

bad_layer=""
while IFS= read -r layer; do
  [[ -z "$layer" ]] && continue
  if ! jq -e --arg l "$layer" '.layers | index($l) != null' "$HARNESS" >/dev/null; then
    bad_layer="${bad_layer}${layer} "
  fi
done < <(jq -r '.tasks[].layer' "$FILE")
[[ -z "$bad_layer" ]] || { echo "eval unknown layer: $bad_layer" >&2; echo "fix: use a name from harness.json layers" >&2; exit 1; }

missing_file=""
while IFS= read -r proves; do
  [[ -z "$proves" ]] && continue
  [[ -f "$PACK/$proves" ]] || missing_file="${missing_file}${proves} "
done < <(jq -r '.tasks[].proves' "$FILE")
[[ -z "$missing_file" ]] || { echo "eval proves missing: $missing_file" >&2; echo "fix: point proves at a file that exists in this pack" >&2; exit 1; }

jq '{ok:true,dimensions:.dimensions,taskCount:(.tasks|length)}' "$FILE"
echo "evals ok"
