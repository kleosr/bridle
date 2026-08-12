#!/usr/bin/env bash

tier2_evidence() {
  local route; route="$(cat "$STATE/route" 2>/dev/null || echo code)"
  [[ "$route" == "code" ]] || return 0
  [[ -s "$STATE/writes" ]] || return 0
  [[ $(pe_dw_met) -eq 1 ]] || return 0
  [[ $(pe_has_verify_evidence) -eq 1 ]] && return 0
  if [[ ! -f "$STATE/session.log" ]] || ! grep -q 'SHELL' "$STATE/session.log" 2>/dev/null; then
    return 0
  fi
  [[ -f "$STATE/evidence_nudge" ]] && return 0
  printf '1\n' >"$STATE/evidence_nudge"
  rules_follow "EVIDENCE: Done-when: met claimed but no green TOOLCHAIN/test cite this turn. Run docs/TOOLCHAIN.md verify (e.g. bash tests/run.sh or package test), cite PASS/green in chat, then Done-when: met."
}

tier2_culture() {
  local route msg
  route="$(cat "$STATE/route" 2>/dev/null || echo code)"
  msg="$(culture_stop_nudge "$PROSE" "$route" || true)"
  [[ -n "$msg" ]] && rules_follow "$msg"
  return 0
}

tier2_legacy_split() {
  local route legacy p fp lines
  route="$(cat "$STATE/route" 2>/dev/null || echo code)"
  [[ "$route" == "code" ]] || return 0
  [[ -s "$STATE/writes" ]] || return 0
  legacy="$(jq -r '.file_loc_legacy_emergency // 700' "$HERE/policy/lean.json" 2>/dev/null || echo 700)"
  while IFS= read -r p; do
    [[ -z "$p" ]] && continue
    [[ "$p" = /* ]] && fp="$p" || fp="$(pwd)/$p"
    [[ -f "$fp" ]] || continue
    lines="$(wc -l < "$fp" 2>/dev/null || echo 0)"
    lines="${lines//[!0-9]}"; [[ -z "$lines" ]] && lines=0
    if [[ "$lines" -gt "$legacy" ]]; then
      rules_follow "EMERGENCY REWRITE: wrote ${p} still ${lines} LOC (legacy >${legacy}). Rewrite into modules ≤300 via Write; StrReplace original and callers to imports; prefer deletion. Then Done-when: met."
    fi
  done < "$STATE/writes"
  return 0
}
