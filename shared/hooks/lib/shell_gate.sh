#!/usr/bin/env bash

SEG='[^;&|]*'
Q='["'\'']'
TERM='(["'\'']|[[:space:];|&)]|$)'
WORD='(^|[[:space:];|&(])'

shell_is_git_gh() {
  echo "$1" | grep -qiE '^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+[[:space:]]+)*(git|gh)[[:space:]]'
}

shell_is_git_gh_body() {
  echo "$1" | grep -qiE '^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+[[:space:]]+)*(git[[:space:]]+commit|gh[[:space:]]+(pr|issue)[[:space:]])'
}

gate_shell_command() {
  local cmd="$1"
  [[ -z "$cmd" ]] && return 0
  local rm_root="rm[[:space:]]+(-[[:alpha:]-]+[[:space:]]+)+${Q}?(/|~/?|\\\$HOME/?|\\\$\\{HOME\\}/?|\\.\\.?/?|\\*)\\*?${Q}?([[:space:];&|]|\$)"
  local force_push="git[[:space:]]+push([[:space:]]+[^;&|[:space:]]+)*[[:space:]]+(-f|--force[^[:space:]]*)([[:space:]]|\$)"
  local wipe="mkfs|dd[[:space:]]+if=|git[[:space:]]+reset[[:space:]]${SEG}--hard|git[[:space:]]+clean[[:space:]]${SEG}-[[:alpha:]]*f|drop[[:space:]]+(database|table|schema)|truncate[[:space:]]+table|>[[:space:]]*/dev/sd|shred[[:space:]]"
  if echo "$cmd" | grep -qiE "${rm_root}|${force_push}|${wipe}"; then
    emit_deny "AUTONOMY BLOCK: destructive command denied. CMD: ${cmd:0:120}"
    return 1
  fi
  local db="(^|[;&|(][[:space:]]*)([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*(sudo[[:space:]]+|env[[:space:]]+)?(psql|mysql|mongosh)([[:space:]]|\$)"
  if echo "$cmd" | grep -qiE "${db}|supabase[[:space:]]+db|terraform[[:space:]]+apply|kubectl[[:space:]]+delete|docker[[:space:]]+rm[[:space:]]+-f|systemctl[[:space:]]+(stop|disable)"; then
    emit_ask "Command mutates infra/DB. Approve in the Cursor card to proceed. CMD: ${cmd:0:120}"
    return 1
  fi
  gate_complexity_bypass "$cmd" && return 1
  gate_shell_source_write "$cmd" && return 1
  gate_shell_secrets "$cmd" && return 1
  return 0
}

gate_complexity_bypass() {
  local cmd="$1"
  shell_is_git_gh "$cmd" && return 1
  if echo "$cmd" | grep -qiE 'eslint-disable[^[:space:]]*[[:space:]]+([^[:space:],]+,)*complexity|complexity[[:space:]]*:[[:space:]]*['\''"]?off|complexity[[:space:]]*:[[:space:]]*0([^0-9]|$)|(--ignore|--extend-ignore)[=[:space:]][^;&]*C901|noqa:[[:space:]]*C901|clippy::(cyclo|cognitive)[[:alnum:]_]*complexity'; then
    emit_deny "Do not disable cyclomatic lint from the shell. Extract until the project lint is green. CMD: ${cmd:0:120}"
    return 0
  fi
  return 1
}

gate_shell_secrets() {
  local cmd="$1" pol="${HERE}/policy/secret_paths.ere" hit=0
  shell_is_git_gh_body "$cmd" && return 1
  local env_seed='cp[[:space:]]+\.env\.(example|sample|template)[[:space:]]+\.env([[:space:]]|$)'
  local env_tok="(^|[[:space:]=(<@]|${Q})(\\./)?\\.env(\\.local|\\.development|\\.production|\\.staging|\\.test|rc)?${TERM}"
  local readers='(cat|head|tail|less|more|bat|source|\.|grep|rg|awk|sed|cut|xxd|od|base64|openssl|strings|scp|cp)'
  local key_mat="${WORD}${readers}[[:space:]]+${SEG}([^[:space:]\"']+\\.(pem|key|p12|pfx)|[^[:space:]\"']*id_(rsa|ed25519|ecdsa))(${Q}|[[:space:];|&]|\$)"
  local git_leak="${WORD}git[[:space:]]+(show|cat-file|checkout|restore|archive)[[:space:]]${SEG}(\\.env|\\.pem|\\.key|id_rsa|id_ed25519|credentials)"
  if [[ -f "$pol" ]] && printf '%s' "$cmd" | grep -qE -f "$pol"; then hit=1
  elif ! echo "$cmd" | grep -qE "$env_seed" && echo "$cmd" | grep -qE "$env_tok"; then hit=1
  elif echo "$cmd" | grep -qiE "$key_mat"; then hit=1
  elif echo "$cmd" | grep -qiE "$git_leak"; then hit=1
  fi
  [[ "$hit" -eq 0 ]] && return 1
  emit_deny "AUTONOMY BLOCK: shell must not read secret paths. CMD: ${cmd:0:120}"
  return 0
}

gate_shell_source_write() {
  local cmd="$1" flat
  shell_is_git_gh_body "$cmd" && return 1
  local ext='(ts|tsx|js|jsx|mjs|cjs|py|go|rs|sh|bash|zsh|rb|java|kt|swift|c|cc|cpp|h|hpp|php|lua|ex|exs)'
  local path="${Q}?[^|&;[:space:]'\"]+\\.${ext}"
  local hit=0
  flat="$(printf '%s' "$cmd" | tr '\n' ' ')"
  if echo "$cmd" | grep -qE "(>|>{2})[[:space:]]*${path}${TERM}"; then
    hit=1
  elif echo "$cmd" | grep -qE "<<[-]?[A-Za-z0-9_]+${SEG}(>|>{2})[[:space:]]*${path}"; then
    hit=1
  elif echo "$cmd" | grep -qE "(>|>{2})[[:space:]]*${path}${SEG}<<[-]?[A-Za-z0-9_]+"; then
    hit=1
  elif echo "$cmd" | grep -qE "${WORD}tee([[:space:]]+-a)?[[:space:]]+${path}${TERM}"; then
    hit=1
  elif echo "$cmd" | grep -qE "${WORD}dd[[:space:]]+${SEG}of=${path}${TERM}"; then
    hit=1
  elif echo "$cmd" | grep -qE "${WORD}(cp|mv|install)[[:space:]]+([^[:space:];&|]+[[:space:]]+)+${path}${TERM}"; then
    hit=1
  elif echo "$cmd" | grep -qE "${WORD}(sed|perl)[[:space:]]+(-[a-zA-Z]*i[a-zA-Z]*|[[:space:]]-i)[[:space:]]${SEG}\\.${ext}${TERM}"; then
    hit=1
  elif echo "$flat" | grep -qiE "${WORD}(python([0-9.]+)?|node|nodejs|ruby)[[:space:]]+(-[ce]|--[[:alnum:]-]+|-[[:space:]]|-<<).{0,250}(open\(|write_text\(|write_bytes\(|Path\([^)]*\)\.write|writeFile(Sync)?\(|createWriteStream\(|File\.(write|open)|FileUtils\.|FS\.write)" \
    && echo "$flat" | grep -qE "\\.${ext}${Q}"; then
    hit=1
  elif echo "$cmd" | grep -qE "${WORD}(curl|wget)[[:space:]]${SEG}-[oO][[:space:]]+${path}${TERM}"; then
    hit=1
  elif echo "$cmd" | grep -qE "${WORD}git[[:space:]]+(checkout|restore)[[:space:]]${SEG}\\.${ext}${TERM}"; then
    hit=1
  fi
  [[ "$hit" -eq 0 ]] && return 1
  emit_deny "LEAN BYPASS BLOCK: Shell must not create/overwrite source (.ts/.tsx/.js/.jsx/.py/.go/.rs/.sh …). Use Write or StrReplace. Never Shell to write code. CMD: ${cmd:0:120}"
  return 0
}
