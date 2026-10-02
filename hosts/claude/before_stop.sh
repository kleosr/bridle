#!/usr/bin/env bash
# Claude Code Stop: reconcile the turn's edits with the ask before "done".
# Exit 2 sends stderr back to the model; stop_hook_active ends the loop, so a
# turn is blocked at most once. Any sensor failure exits 0: a crashed check
# must not trap the session. Every turn with edits appends one line to
# ~/.claude/state/bridle-turns.jsonl, with its files and production lines.
set -uo pipefail
VERIFY='(^|[ ;&|(])(bash tests/run\.sh|(npm|pnpm|yarn|bun)( run)? (test|build|lint|check|typecheck)|npx? (vitest|jest|tsc|eslint|playwright)|(next|vite|astro) build|vitest|jest|pytest|unittest|tsc|eslint|biome|ruff|mypy|go (test|vet|build)|cargo (test|check|build|clippy)|deno (test|check|lint)|make (test|check)|just (test|check)|node --(test|check)|bash -n|shellcheck)([ :]|$)'
UNWIRED_SKIP='(^|/)(tests?|__tests__|scripts|bin|migrations)/|\.(test|spec|config)\.|(^|/)(index|main|page|layout|route|loading|error|not-found|template|middleware|app|server|cli|setup|conftest|__init__|__main__|lib|mod|build)\.[a-z]+$'

command -v jq >/dev/null 2>&1 || exit 0
INPUT="$(cat)"
[[ -n "$(printf '%s' "$INPUT" | jq -r '.cursor_version // ""' 2>/dev/null)" ]] && exit 0
FIELDS="$(printf '%s' "$INPUT" | jq -r '(.stop_hook_active // false), (.cwd // ""), (.transcript_path // ""), (.session_id // "")' 2>/dev/null)" || exit 0
{ read -r ACTIVE; read -r CWD; read -r TRANSCRIPT; read -r SESSION; } <<<"$FIELDS"
[[ "$ACTIVE" == false && -n "$CWD" && -f "$TRANSCRIPT" ]] || exit 0

TURN="$(jq -cn --arg v "$VERIFY" --arg cwd "$CWD" --argjson pending null -f "${BASH_SOURCE%/*}/bridle_turn.jq" "$TRANSCRIPT" 2>/dev/null)" || exit 0
NFILES="$(jq '.files | length' <<<"$TURN")"
(( NFILES > 0 )) || exit 0
STATE="$(jq -r 'if .docsOnly then "docs" elif .verify == null then "none" elif .verify.ok == false then "red" else "ok" end' <<<"$TURN")"

unwired() {
  local rel stem re="$UNWIRED_SKIP"
  git -C "$CWD" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  while IFS= read -r rel; do
    [[ "$rel" =~ \.(tsx?|jsx?|mjs|cjs|py|vue|svelte|rs|java|cs|rb|php|lua|h|hpp|dart)$ && ! "$rel" =~ $re ]] || continue
    stem="${rel##*/}"; stem="${stem%.*}"
    git -C "$CWD" grep -qIF --untracked -e "$stem" -- . ":(exclude,literal)$rel" || printf '%s\n' "$rel"
  done < <(jq -r '.writes[]' <<<"$TURN")
}

todo=()
[[ "$STATE" == none ]] && todo+=("no verification ran after the last edit: run the repo's verify command and cite command + exit")
[[ "$STATE" == red ]] && todo+=("the last verification failed: fix it, or report the failure instead of calling this done")
UNWIRED="$(unwired | paste -sd ' ' -)"
[[ -z "$UNWIRED" ]] || todo+=("nothing references the new file(s) $UNWIRED: import or register them, or delete them")

QG="$HOME/.claude/skills/code-architecture/scripts/quality-gate.mjs"
QG_STATE="skip"
if command -v node >/dev/null 2>&1 && [[ -f "$QG" ]] \
  && git -C "$CWD" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  QG_OUT=""; QG_EC=0
  QG_OUT="$(cd "$CWD" && node "$QG" 2>&1)" || QG_EC=$?
  if (( QG_EC == 0 )); then
    QG_STATE="ok"
  else
    QG_STATE="fail"
    todo+=("quality-gate failed on this diff: fix every finding and re-run the gate")
    while IFS= read -r qgline; do
      [[ -n "$qgline" ]] && todo+=("$qgline")
    done < <(printf '%s\n' "$QG_OUT" | head -n 10)
  fi
fi

LOG="$HOME/.claude/state/bridle-turns.jsonl"
if mkdir -p "${LOG%/*}" 2>/dev/null; then
  jq -c --arg ts "$(date -u +%FT%TZ)" --arg s "$SESSION" --arg c "$CWD" --arg st "$STATE" --arg qg "$QG_STATE" \
    '. + {ts: $ts, session: $s, cwd: $c, verified: $st, quality_gate: $qg, blocked: ($ARGS.positional | length > 0), findings: $ARGS.positional}' \
    --args ${todo[@]+"${todo[@]}"} <<<"$TURN" >>"$LOG" 2>/dev/null || true
fi

(( ${#todo[@]} > 0 )) || exit 0
{
  echo "bridle: turn-check: not done yet."
  printf ' - %s\n' "${todo[@]}"
  git -C "$CWD" diff --stat 2>/dev/null | head -n 12
} >&2
exit 2
