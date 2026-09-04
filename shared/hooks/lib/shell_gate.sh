#!/usr/bin/env bash

SEG='[^;&|]*'
Q='["'\''"]'
TERM="(['\"]|[[:space:];|&)]|$)"
WORD='(^|[[:space:];|&])'
SRC_EXT='(ts|tsx|js|jsx|mjs|cjs|py|go|rs|sh|bash|zsh|rb|java|kt|swift|c|cc|cpp|h|hpp|php|lua|ex|exs)'
SRC_PATH="(['\"][^'\"]*\\.${SRC_EXT}['\"]|(\\\\ |[^|&;[:space:]'\"])+\\.${SRC_EXT}${TERM})"

shell_is_git_gh() {
  echo "$1" | grep -qiE '^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+[[:space:]]+)*(git|gh)[[:space:]]'
}

shell_is_git_gh_body() {
  echo "$1" | grep -qiE '^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+[[:space:]]+)*(git[[:space:]]+commit|gh[[:space:]]+(pr|issue)[[:space:]])'
}

gate_shell_command() {
  local cmd="$1"
  [[ -z "$cmd" ]] && return 0
  local wipe_tgt="${Q}?(/(/*|\./*|\.\./*)*|/[^/]+/\.\.(/*|\./*|\.\./*)*|~|\\\$HOME|\\\$\{HOME\}|\.\.?|\*)${Q}?/?${Q}?(\.|\*)?${Q}?"
  local rm_root="rm[[:space:]]+(-[[:alpha:]-]+[[:space:]]+)+${wipe_tgt}([[:space:];|&]|$)"
  local force_push="git[[:space:]]+push([[:space:]]+[^;&|[:space:]]+)*[[:space:]]+(-f[[:alpha:]]*|--force)([[:space:];|&]|$)"
  local wipe="mkfs|dd[[:space:]]+if=|git[[:space:]]+reset[[:space:]]${SEG}--hard|git[[:space:]]+clean[[:space:]]${SEG}(-[[:alpha:]]*f|--force)|drop[[:space:]]+(database|table|schema)|truncate[[:space:]]+table|>[[:space:]]*/dev/sd|shred[[:space:]]"
  if echo "$cmd" | grep -qiE "${rm_root}|${force_push}|${wipe}"; then
    emit_deny "AUTONOMY BLOCK: destructive command denied. CMD: ${cmd:0:120}"
    return 1
  fi
  local db="(^|[;&|(][[:space:]]*)([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*(sudo[[:space:]]+|env[[:space:]]+)?(psql|mysql|mongosh)([[:space:]]|$)"
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
  local cmd="$1" pol="${HERE}/policy/secret_paths.ere" hit=0 scanned
  shell_is_git_gh_body "$cmd" && return 1
  local env_seed='^[[:space:]]*cp[[:space:]]+\.env\.(example|sample|template)[[:space:]]+\.env[[:space:]]*$'
  echo "$cmd" | grep -qE "$env_seed" && return 1
  scanned="${cmd//.env.example/}"
  scanned="${scanned//.env.sample/}"
  scanned="${scanned//.env.template/}"
  local env_tok="(^|[[:space:]=(<@]|${Q})(\./)?\.env(rc)?([^[:alnum:]_]|$)"
  local readers='(cat|head|tail|less|more|bat|source|\.|grep|rg|awk|sed|cut|xxd|od|base64|openssl|strings|scp|cp)'
  local key_mat="${WORD}${readers}[[:space:]]+${SEG}([^[:space:]\"']+\.(pem|key|p12|pfx)|[^[:space:]\"']*id_(rsa|ed25519|ecdsa))(${Q}|[[:space:];|&]|$)"
  local git_leak="${WORD}git[[:space:]]+(show|cat-file|checkout|restore|archive)[[:space:]]${SEG}(\.env|\.pem|\.key|id_rsa|id_ed25519|credentials)"
  if [[ -f "$pol" ]] && printf '%s' "$scanned" | grep -qE -f "$pol"; then hit=1
  elif echo "$scanned" | grep -qiE "$env_tok"; then hit=1
  elif echo "$cmd" | grep -qiE "$key_mat"; then hit=1
  elif echo "$cmd" | grep -qiE "$git_leak"; then hit=1
  fi
  [[ "$hit" -eq 0 ]] && return 1
  emit_deny "AUTONOMY BLOCK: shell must not read secret paths. CMD: ${cmd:0:120}"
  return 0
}

shell_writes_source() {
  local cmd="$1" pat flat
  local pats="(>|>{2})[[:space:]]*${SRC_PATH}
${WORD}tee([[:space:]]+-a)?[[:space:]]+${SRC_PATH}
${WORD}dd[[:space:]]+${SEG}of=${SRC_PATH}
${WORD}(cp|mv|install)[[:space:]]+([^[:space:];&|]+[[:space:]]+)+${SRC_PATH}
${WORD}(sed|perl)[[:space:]]+(-[a-zA-Z]*i[a-zA-Z]*|[[:space:]]-i)[[:space:]]${SEG}\\.${SRC_EXT}${TERM}
${WORD}(curl|wget)[[:space:]]${SEG}-[oO][[:space:]]+${SRC_PATH}
${WORD}git[[:space:]]+(checkout|restore)[[:space:]]${SEG}\\.${SRC_EXT}${TERM}"
  while IFS= read -r pat; do
    [[ -n "$pat" ]] || continue
    printf '%s' "$cmd" | grep -qE "$pat" && return 0
  done <<EOF
$pats
EOF
  flat="$(printf '%s' "$cmd" | tr '\n' ' ')"
  echo "$flat" | grep -qiE "${WORD}(python([0-9.]+)?|node|nodejs|ruby)[[:space:]]+(-[ce]|--[[:alnum:]-]+|-[[:space:]]|-?<<).{0,250}(open\(|write_text\(|write_bytes\(|Path\([^)]*\)\.write|writeFile(Sync)?\(|createWriteStream\(|File\.(write|open)|FileUtils\.|FS\.write)" \
    && echo "$flat" | grep -qE "\\.${SRC_EXT}${Q}"
}

gate_shell_source_write() {
  local cmd="$1"
  if shell_is_git_gh_body "$cmd"; then
    [[ "$cmd" == *[\;\&\|]* ]] || return 1
    cmd="${cmd#*[;&|]}"
  fi
  shell_writes_source "$cmd" || return 1
  emit_deny "LEAN BYPASS BLOCK: Shell must not create/overwrite source (.ts/.tsx/.js/.jsx/.py/.go/.rs/.sh …). Use Write or StrReplace. Never Shell to write code. CMD: ${cmd:0:120}"
  return 0
}
