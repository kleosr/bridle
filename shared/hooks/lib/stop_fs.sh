#!/usr/bin/env bash

rules_accept() {
  local date; date="$(date +%Y-%m-%d)"
  rm -rf "$STATE"; mkdir -p "$STATE"
  if [[ -f "$HANDOFF" ]] && ! grep -qF '(agent fills details)' "$HANDOFF"; then
    emit_quiet; exit 0
  fi
  local archived=""
  if [[ -f "$HANDOFF" ]]; then
    archived="$(sed -n '/^## Archived/,$p' "$HANDOFF" 2>/dev/null | tail -n +2 \
      | grep -vxF '(Older context compacted here when active sections exceed ~150 lines.)' || true)"
  fi
  {
    echo "# HANDOFF — Session State"; echo ""; echo "## Active Objective"; echo ""
    echo "Session complete ${date}"; echo ""; echo "## Current State"; echo ""
    echo "Done-when: met. (agent fills details)"; echo ""; echo "## Next Actions"; echo ""
    echo "Update HANDOFF with next session objective."
    echo ""; echo "## Archived"; echo ""
    if [[ -n "$archived" ]]; then echo "$archived"; echo ""; fi
    echo "(Older context compacted here when active sections exceed ~150 lines.)"
  } >"$HANDOFF"
  emit_quiet; exit 0
}

rules_topology() {
  local violations=""
  while IFS= read -r tag; do
    [[ -z "$tag" ]] && continue
    grep -qxF "$tag" "$STATE/allowed_files.md" || violations="$violations $tag"
  done < <(rules_tags)
  if [[ -n "$violations" ]]; then
    rules_follow "TOPOLOGY VIOLATION: Intentaste tocar un archivo fuera de tu FILE_MAP:$violations. Corrige tu INTENT — solo edita/crea paths que declaraste en tu FILE_MAP, o expande tu INTENT explícitamente."
  fi
  return 0
}

rules_untouched() {
  local session_ts; session_ts="$(cat "$STATE/session_ts" 2>/dev/null || echo 0)"
  session_ts="${session_ts//[!0-9]}"; [[ -z "$session_ts" ]] && session_ts=0
  local untouched=""
  while IFS= read -r p; do
    [[ -z "$p" ]] && continue
    [[ "$p" = /* ]] && fp="$p" || fp="$(pwd)/$p"
    [[ -f "$fp" ]] || { untouched="$untouched $p(missing)"; continue; }
    local m; m="$(file_mtime "$fp" || echo 0)"
    m="${m//[!0-9]}"; [[ -z "$m" ]] && m=0
    [[ "$session_ts" -eq 0 || "$m" -ge "$session_ts" ]] || untouched="$untouched $p"
  done < <(rules_tags)
  if [[ -n "$untouched" ]]; then
    rules_follow "FILES NOT TOUCHED:$untouched — every tagged edit:|NEW: path must be written this turn via Write|StrReplace, then Done-when: met."
  fi
  return 0
}

rules_writes_tagged() {
  local orphan="" w base
  [[ -s "$STATE/writes" ]] || return 0
  while IFS= read -r w; do
    [[ -z "$w" ]] && continue
    base="$(basename "$w")"
    if rules_tags | grep -qxF "$w"; then continue; fi
    if rules_tags | grep -qxF "$base"; then continue; fi
    orphan="${orphan} $w"
  done < "$STATE/writes"
  if [[ -n "$orphan" ]]; then
    rules_follow "WRITE/TAG MISMATCH: wrote paths without matching edit:|NEW: tags:$orphan. Declare every written path in INTENT, finish tags this turn, then Done-when: met."
  fi
  return 0
}

tier3_fs() {
  rules_untouched
  local hl; hl="$(wc -l < "$HANDOFF" 2>/dev/null || echo 0)"; hl="${hl//[!0-9]}"; [[ -z "$hl" ]] && hl=0
  if [[ "$hl" -gt 180 ]]; then
    rules_follow "HANDOFF.md is ${hl} lines (>180 roof). Compact: move older Recent Changes into Archived, compress Failed Attempts to one-liners. Keep active sections under 150 lines, then Done-when: met."
  fi
}
