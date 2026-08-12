#!/usr/bin/env bash

culture_ban_file() {
  printf '%s\n' "${HERE}/policy/vernacular_bans.txt"
}

culture_jargon_hit() {
  local text="$1" line f
  f="$(culture_ban_file)"
  [[ -f "$f" && -r "$f" ]] || return 1
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    if printf '%s' "$text" | grep -qiE "$line"; then
      printf '%s' "$line"
      return 0
    fi
  done < "$f"
  return 1
}

culture_leapfrog_hit() {
  local text="$1"
  local green=0 reuse=0
  printf '%s' "$text" | grep -qiE '(from scratch|greenfield|scaffold(ing)?|boilerplate|create (a |the )?(new )?(app|project|module|component|service|library)|NEW:[A-Za-z0-9_./+=-]+.*NEW:[A-Za-z0-9_./+=-]+)' && green=1
  printf '%s' "$text" | grep -qiE '\b(Grep|reuse|reusing|existing (code|module|component|util)|already (in|have)|look(ed|ing)? (in|at|through) (the )?codebase|search(ed|ing)? (the )?codebase)\b' && reuse=1
  [[ "$green" -eq 1 && "$reuse" -eq 0 ]]
}

culture_grounding_nudge() {
  local prompt="$1" hits unread="" p base
  hits="$(printf '%s' "$prompt" | grep -oE '\b(src|tests?|docs|shared|scripts|lib|app|hooks)/[A-Za-z0-9_./+=-]+\.[A-Za-z0-9]+|\b[A-Za-z0-9_.-]+\.(ts|tsx|js|jsx|sh|py|go|rs)\b' 2>/dev/null | head -n 6 || true)"
  [[ -z "$hits" ]] && return 0
  while IFS= read -r p; do
    [[ -z "$p" ]] && continue
    if [[ -f "${STATE}/reads" ]]; then
      grep -qF "$p" "${STATE}/reads" 2>/dev/null && continue
      base="$(basename "$p")"
      grep -qF "$base" "${STATE}/reads" 2>/dev/null && continue
    fi
    unread="${unread}${unread:+ }$p"
  done <<EOF
$hits
EOF
  [[ -z "$unread" ]] && return 0
  printf 'GROUNDING nudge: prompt names paths without prior Read this session (%s). Read them before Write/StrReplace — not a block, proceeding.' "$unread"
}

culture_submit_nudge() {
  local prompt="$1" route="$2" hit="" msg="" g=""
  [[ "$route" == "code" ]] || { printf ''; return 0; }
  if hit="$(culture_jargon_hit "$prompt")"; then
    msg="VERNACULAR nudge: prompt hits banned jargon (${hit}). Prefer plain engineering words — not a block, proceeding."
  fi
  if culture_leapfrog_hit "$prompt"; then
    if [[ -n "$msg" ]]; then
      msg="${msg} PONYTAIL nudge: greenfield/scaffold without Grep/reuse — climb the ladder before Write."
    else
      msg="PONYTAIL nudge: greenfield/scaffold without Grep/reuse signal — climb the ladder (reuse first) before Write. Not a block, proceeding."
    fi
  fi
  g="$(culture_grounding_nudge "$prompt" || true)"
  if [[ -n "$g" ]]; then
    if [[ -n "$msg" ]]; then msg="${msg} ${g}"; else msg="$g"; fi
  fi
  printf '%s' "$msg"
}

culture_stop_nudge() {
  local prose="$1" route="$2" hit=""
  [[ "$route" == "code" ]] || return 1
  [[ -f "${STATE}/culture_nudge" ]] && return 1
  if hit="$(culture_jargon_hit "$prose")"; then
    printf '1\n' >"${STATE}/culture_nudge"
    printf 'VERNACULAR: assistant prose hits banned jargon (%s). Rewrite in plain engineering language, then Done-when: met.' "$hit"
    return 0
  fi
  if culture_leapfrog_hit "$prose"; then
    if [[ -f "${STATE}/session.log" ]] && grep -qE '\bGrep\b|GREP' "${STATE}/session.log" 2>/dev/null; then
      return 1
    fi
    printf '1\n' >"${STATE}/culture_nudge"
    printf 'PONYTAIL: leapfrog detected (greenfield without Grep/reuse). Grep for reuse, extract subatomic modules if growing files, then Done-when: met.'
    return 0
  fi
  return 1
}
