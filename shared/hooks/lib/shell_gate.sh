#!/usr/bin/env bash

shell_is_git_gh() {
  echo "$1" | grep -qiE '^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+[[:space:]]+)*(git|gh)[[:space:]]'
}

shell_is_git_gh_body() {
  echo "$1" | grep -qiE '^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+[[:space:]]+)*(git[[:space:]]+commit|gh[[:space:]]+(pr|issue)[[:space:]])'
}

RM_FLAGS='(-[a-z]+[[:space:]]+)*-[a-z]*r[a-z]*[[:space:]]+(-[a-z]+[[:space:]]+)*'
RM_HOME='(~|\$\{?HOME\}?)(/[^[:space:]]*)?'
RM_SYSTEM='/(usr|etc|var|home|bin|sbin|lib|lib64|boot|opt|root|srv|dev|proc|sys|private|Users|System|Library|Applications|Volumes)(/\*?)?'
RM_DESTRUCTIVE="(^|[[:space:];|&(])rm[[:space:]]+${RM_FLAGS}['\"]?(/|/\\*|\\.\\.?|${RM_HOME}|${RM_SYSTEM})['\"]?([[:space:]]|$)"

gate_shell_command() {
  local cmd="$1"
  [[ -z "$cmd" ]] && return 0
  if printf '%s' "$cmd" | grep -qiE "${RM_DESTRUCTIVE}|mkfs|dd if=|git push --force|git push -f|git[[:space:]]+reset[[:space:]].*--hard|git[[:space:]]+clean[[:space:]].*-f|drop[[:space:]]+(database|table|schema)|truncate table|>:.*/dev/sd|shred "; then
    emit_deny "AUTONOMY BLOCK: destructive command denied. CMD: ${cmd:0:120}"
    return 1
  fi
  if echo "$cmd" | grep -qiE '((^|[;&|(][[:space:]]*)(sudo[[:space:]]+|env[[:space:]]+)?(psql|mysql|mongosh)([[:space:]]|$))|supabase[[:space:]]+db|terraform[[:space:]]+apply|kubectl[[:space:]]+delete|docker[[:space:]]+rm[[:space:]]+-f|systemctl[[:space:]]+(stop|disable)'; then
    emit_ask "Command mutates infra/DB. Approve in the Cursor card to proceed. CMD: ${cmd:0:120}"
    return 1
  fi
  if gate_complexity_bypass "$cmd"; then
    return 1
  fi
  if gate_shell_source_write "$cmd"; then
    return 1
  fi
  if gate_shell_secrets "$cmd"; then
    return 1
  fi
  return 0
}

gate_complexity_bypass() {
  local cmd="$1"
  if shell_is_git_gh "$cmd"; then
    return 1
  fi
  if echo "$cmd" | grep -qiE 'eslint-disable[^[:space:]]*[[:space:]]+([^[:space:],]+,)*complexity|complexity[[:space:]]*:[[:space:]]*['\''"]?off|complexity[[:space:]]*:[[:space:]]*0([^0-9]|$)|(--ignore|--extend-ignore)[=[:space:]][^;&]*C901|noqa:[[:space:]]*C901|clippy::(cyclo|cognitive)[[:alnum:]_]*complexity'; then
    emit_deny "Do not disable cyclomatic lint from the shell. Extract until the project lint is green. CMD: ${cmd:0:120}"
    return 0
  fi
  return 1
}

gate_shell_secrets() {
  local cmd="$1" pol="${HERE}/policy/secret_paths.ere"
  if shell_is_git_gh_body "$cmd"; then
    return 1
  fi
  if [[ -f "$pol" ]] && printf '%s' "$cmd" | grep -qE -f "$pol"; then
    emit_deny "AUTONOMY BLOCK: shell must not read secret paths. CMD: ${cmd:0:120}"
    return 0
  fi
  if echo "$cmd" | grep -qiE '@\.env|(^|[[:space:];|&])(cat|head|tail|less|more|bat|source|\.)[[:space:]]+(['\''"]|\./)*\.env'; then
    emit_deny "AUTONOMY BLOCK: shell must not read secret paths. CMD: ${cmd:0:120}"
    return 0
  fi
  if echo "$cmd" | grep -qiE '(^|[[:space:];|&])git[[:space:]]+(show|cat-file|checkout|restore|archive)[[:space:]].*(\.env|\.pem|\.key|id_rsa|id_ed25519|credentials)'; then
    emit_deny "AUTONOMY BLOCK: shell must not read secret paths. CMD: ${cmd:0:120}"
    return 0
  fi
  return 1
}

SRC_EXT='(ts|tsx|js|jsx|mjs|cjs|py|go|rs|sh|bash|zsh|rb|java|kt|swift|c|cc|cpp|h|hpp|php|lua|ex|exs)'
SRC_END="(['\"]|[[:space:]\"';|&]|$)"
SRC_PATH="(['\"][^'\"]*\\.${SRC_EXT}['\"]|(\\\\ |[^|&;[:space:]'\"])+\\.${SRC_EXT}${SRC_END})"
SRC_TAIL="\\.${SRC_EXT}${SRC_END}"
SRC_WRITE_PATTERNS=(
  "(>|>{2})[[:space:]]*${SRC_PATH}"
  "(^|[[:space:];|&])tee([[:space:]]+-a)?[[:space:]]+${SRC_PATH}"
  "(^|[[:space:];|&])dd[[:space:]]+[^;&|]*of=${SRC_PATH}"
  "(^|[[:space:];|&])(cp|mv|install)[[:space:]]+([^[:space:]]+[[:space:]]+)+${SRC_PATH}"
  "(^|[[:space:];|&])(sed|perl)[[:space:]]+(-[a-zA-Z]*i[a-zA-Z]*|[[:space:]]-i)[[:space:]].*${SRC_TAIL}"
  "(^|[[:space:];|&])(curl|wget)[[:space:]].*-[oO][[:space:]]+${SRC_PATH}"
  "(^|[[:space:];|&])git[[:space:]]+(checkout|restore)[[:space:]].*${SRC_TAIL}"
)
SRC_INLINE_WRITE="(^|[[:space:];|&])(python([0-9.]+)?|node|nodejs|ruby)[[:space:]]+(-[ce]|--[[:alnum:]-]+)[[:space:]].{0,200}(open\(|write_text\(|write_bytes\(|Path\([^)]*\)\.write|writeFile(Sync)?\(|createWriteStream\(|File\.(write|open)|FileUtils\.|FS\.write)"

shell_writes_source() {
  local cmd="$1" pat
  for pat in "${SRC_WRITE_PATTERNS[@]}"; do
    printf '%s' "$cmd" | grep -qE "$pat" && return 0
  done
  printf '%s' "$cmd" | grep -qiE "$SRC_INLINE_WRITE"
}

gate_shell_source_write() {
  local cmd="$1"
  shell_writes_source "$cmd" || return 1
  emit_deny "LEAN BYPASS BLOCK: Shell must not create/overwrite source (.ts/.tsx/.js/.jsx/.py/.go/.rs/.sh …). Use Write or StrReplace. Never Shell to write code. CMD: ${cmd:0:120}"
  return 0
}
