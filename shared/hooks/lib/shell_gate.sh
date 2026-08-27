#!/usr/bin/env bash

gate_shell_command() {
  local cmd="$1"
  [[ -z "$cmd" ]] && return 0
  if echo "$cmd" | grep -qiE '(rm -rf? /|rm -rf? ~|mkfs|dd if=|git push --force|git push -f|drop database|truncate table|>:.*\/dev\/sd|shred )'; then
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
  return 0
}

gate_complexity_bypass() {
  local cmd="$1"
  if echo "$cmd" | grep -qiE 'eslint-disable[^[:space:]]*[[:space:]]+([^[:space:],]+,)*complexity|complexity[[:space:]]*:[[:space:]]*['\''"]?off|complexity[[:space:]]*:[[:space:]]*0([^0-9]|$)|(--ignore|--extend-ignore)[=[:space:]][^;&]*C901|noqa:[[:space:]]*C901|clippy::(cyclo|cognitive)[[:alnum:]_]*complexity'; then
    emit_deny "COMPLEXITY BYPASS BLOCK: do not disable cyclomatic lint. Extract until the project lint is green. CMD: ${cmd:0:120}"
    return 0
  fi
  return 1
}

gate_shell_source_write() {
  local cmd="$1"
  local ext='(ts|tsx|js|jsx|mjs|cjs|py|go|rs|sh|bash|zsh|rb|java|kt|swift|c|cc|cpp|h|hpp|php|lua|ex|exs)'
  local hit=0
  if echo "$cmd" | grep -qE "(>|>{2})[[:space:]]*['\"]?[^|&;[:space:]'\"]+\.${ext}(['\"]|[[:space:]\"';|&]|$)"; then
    hit=1
  elif echo "$cmd" | grep -qE "<<[-]?[A-Za-z0-9_]+.*(>|>{2})[[:space:]]*['\"]?[^|&;[:space:]'\"]+\.${ext}"; then
    hit=1
  elif echo "$cmd" | grep -qE "(>|>{2})[[:space:]]*['\"]?[^|&;[:space:]'\"]+\.${ext}.*<<[-]?[A-Za-z0-9_]+"; then
    hit=1
  elif echo "$cmd" | grep -qE "(^|[[:space:];|&])tee([[:space:]]+-a)?[[:space:]]+['\"]?[^|&;[:space:]'\"]+\.${ext}(['\"]|[[:space:]\"';|&]|$)"; then
    hit=1
  elif echo "$cmd" | grep -qE "(^|[[:space:];|&])dd[[:space:]]+[^;&|]*of=['\"]?[^[:space:]'\"]+\.${ext}(['\"]|[[:space:]\"';|&]|$)"; then
    hit=1
  elif echo "$cmd" | grep -qE "(^|[[:space:];|&])(cp|mv|install)[[:space:]]+([^[:space:]]+[[:space:]]+)+['\"]?[^|&;[:space:]'\"]+\.${ext}(['\"]|[[:space:]\"';|&]|$)"; then
    hit=1
  elif echo "$cmd" | grep -qE "(^|[[:space:];|&])sed[[:space:]]+(-[a-zA-Z]*i[a-zA-Z]*|[[:space:]]-i)[[:space:]].*\.${ext}(['\"]|[[:space:]\"';|&]|$)"; then
    hit=1
  elif echo "$cmd" | grep -qE "(^|[[:space:];|&])perl[[:space:]]+(-[a-zA-Z]*i[a-zA-Z]*|[[:space:]]-i)[[:space:]].*\.${ext}(['\"]|[[:space:]\"';|&]|$)"; then
    hit=1
  elif echo "$cmd" | grep -qiE "(^|[[:space:];|&])(python([0-9.]+)?|node|nodejs|ruby)[[:space:]]+(-[ce]|--[[:alnum:]-]+)[[:space:]].{0,200}(open\(|write_text\(|write_bytes\(|Path\([^)]*\)\.write|writeFile(Sync)?\(|createWriteStream\(|File\.(write|open)|FileUtils\.|FS\.write)"; then
    hit=1
  elif echo "$cmd" | grep -qE "(^|[[:space:];|&])(curl|wget)[[:space:]].*-[oO][[:space:]]+['\"]?[^|&;[:space:]'\"]+\.${ext}"; then
    hit=1
  elif echo "$cmd" | grep -qE "(^|[[:space:];|&])git[[:space:]]+(checkout|restore)[[:space:]].*\.${ext}(['\"]|[[:space:]\"';|&]|$)"; then
    hit=1
  fi
  [[ "$hit" -eq 0 ]] && return 1
  emit_deny "LEAN BYPASS BLOCK: Shell must not create/overwrite source (.ts/.tsx/.js/.jsx/.py/.go/.rs/.sh …). Use Write or StrReplace. Never Shell to write code. CMD: ${cmd:0:120}"
  return 0
}
