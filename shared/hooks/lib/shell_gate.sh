#!/usr/bin/env bash
# Shell gate. Verdict order: deny > ask > allow.
# The command is split into segments on shell operators OUTSIDE quotes, and
# every segment is gated independently. A git/gh message only suppresses
# matches inside its own message argument — never the rest of the command.
#
# gate_shell_command: emits a verdict and returns 0, or returns 1 (clean).

SEG_SEP="$(printf '\034')"

SEG='[^;&|]*'
Q='["'\'']'
TERM="(['\"]|[[:space:];|&)]|$)"
WORD='(^|[[:space:];|&])'
SRC_EXT='(ts|tsx|js|jsx|mjs|cjs|py|go|rs|sh|bash|zsh|rb|java|kt|swift|c|cc|cpp|h|hpp|php|lua|ex|exs)'
SRC_PATH="(['\"][^'\"]*\\.${SRC_EXT}['\"]|(\\\\ |[^|&;[:space:]'\"])+\\.${SRC_EXT}${TERM})"

split_segments() {
  printf '%s' "$1" | tr '\n\r' ';;' | awk '
    {
      sq = sprintf("%c", 39); dq = "\""; bt = sprintf("%c", 96)
      sep = sprintf("%c", 28)
      s = $0; n = length(s); out = ""; state = 0; i = 1
      while (i <= n) {
        c = substr(s, i, 1)
        if (state == 0) {
          if (c == "\\") { out = out c substr(s, i + 1, 1); i += 2; continue }
          if (c == sq) { state = 1; out = out c; i++; continue }
          if (c == dq) { state = 2; out = out c; i++; continue }
          if (c == bt) { state = 3; out = out c; i++; continue }
          if (c == ";" || c == "|") {
            if (substr(s, i + 1, 1) == c) { out = out sep; i += 2; continue }
            out = out sep; i++; continue
          }
          if (c == "&") {
            if (substr(s, i + 1, 1) == "&") { out = out sep; i += 2; continue }
            out = out sep; i++; continue
          }
          out = out c; i++; continue
        }
        if (state == 1) { out = out c; if (c == sq) state = 0; i++; continue }
        out = out c
        if (c == "\\") { out = out substr(s, i + 1, 1); i += 2; continue }
        if (state == 2 && c == dq) state = 0
        if (state == 3 && c == bt) state = 0
        i++
      }
      print out
    }'
}

shell_is_git_gh_body() {
  echo "$1" | grep -qiE '^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+[[:space:]]+)*(git[[:space:]]+commit|gh[[:space:]]+(pr|issue)[[:space:]])'
}

# Blank the message argument of a git-commit / gh-pr-issue segment so that
# prose mentioning a gate pattern is not treated as an action. File-taking
# flags (-F, --body-file, ...) are intentionally left visible.
mask_git_message() {
  printf '%s' "$1" | sed -E \
    -e 's/(-m|--message|--title|--body|--notes)(=|[[:space:]]+)"[^"]*"/\1 /g' \
    -e "s/(-m|--message|--title|--body|--notes)(=|[[:space:]]+)'[^']*'/\1 /g" \
    -e 's/(-m|--message|--title|--body|--notes)=[^[:space:]]+/\1 /g' \
    -e 's/(-m|--message|--title|--body|--notes)[[:space:]]+[^[:space:]]+/\1 /g'
}

shell_is_fleet_sync() {
  case "$1" in
    *$'\n'*|*$'\r'*|*';'*|*'|'*|*'&'*|*'$'*|*'`'*|*'#'*|*'('*|*')'*) return 1 ;;
  esac
  printf '%s' "$1" | grep -qE '^[[:space:]]*(FORCE=1[[:space:]]+)?bash[[:space:]]+scripts/install\.sh[[:space:]]*$' && return 0
  printf '%s\n' "$1" | grep -qE '^[[:space:]]*(FORCE=1[[:space:]]+)?bash[[:space:]]+shared/hooks/fleet_sync\.sh([[:space:]]+(install|verify|all|project-hooks))?[[:space:]]*$'
}

gate_destructive() {
  local seg="$1"
  local wipe_tgt="${Q}?(/(/*|\./*|\.\./*)*|/[^/]+/\.\.(/*|\./*|\.\./*)*|~|\\\$HOME|\\\$\{HOME\}|\.\.?|\*)${Q}?/?${Q}?(\.|\*)?${Q}?"
  local rm_root="rm[[:space:]]+(-[[:alpha:]-]+[[:space:]]+)+${wipe_tgt}([[:space:];&]|$)"
  local force_push="git[[:space:]]+push([[:space:]]+[^;&|[:space:]]+)*[[:space:]]+(-f[[:alpha:]]*|--force)([[:space:]]|$)"
  local wipe="mkfs|dd[[:space:]]+if=|git[[:space:]]+reset[[:space:]]${SEG}--hard|git[[:space:]]+clean[[:space:]]${SEG}(-[[:alpha:]]*f|--force)|>[[:space:]]*/dev/sd|shred[[:space:]]"
  echo "$seg" | grep -qiE "${rm_root}|${force_push}|${wipe}"
}

gate_complexity_bypass() {
  echo "$1" | grep -qiE 'eslint-disable[^[:space:]]*[[:space:]]+([^[:space:],]+,)*complexity|complexity[[:space:]]*:[[:space:]]*['\''"]?off|complexity[[:space:]]*:[[:space:]]*0([^0-9]|$)|(--ignore|--extend-ignore)[=[:space:]][^;&]*C901|noqa:[[:space:]]*C901|clippy::(cyclo|cognitive)[[:alnum:]_]*complexity'
}

shell_writes_source() {
  local seg="$1" pat flat
  local pats="(>|>{2})[[:space:]]*${SRC_PATH}
${WORD}tee([[:space:]]+-a)?[[:space:]]+${SRC_PATH}
${WORD}dd[[:space:]]+${SEG}of=${SRC_PATH}
${WORD}(cp|mv|install)[[:space:]]+([^[:space:];&|]+[[:space:]]+)+${SRC_PATH}
${WORD}(sed|perl)[[:space:]]+(-[a-zA-Z]*i[a-zA-Z]*|[[:space:]]-i)[[:space:]]${SEG}\\.${SRC_EXT}${TERM}
${WORD}(curl|wget)[[:space:]]${SEG}-[oO][[:space:]]+${SRC_PATH}
${WORD}git[[:space:]]+(checkout|restore)[[:space:]]${SEG}\\.${SRC_EXT}${TERM}"
  while IFS= read -r pat; do
    [[ -n "$pat" ]] || continue
    printf '%s' "$seg" | grep -qE "$pat" && return 0
  done <<EOF
$pats
EOF
  flat="$(printf '%s' "$seg" | tr '\n' ' ')"
  echo "$flat" | grep -qiE "${WORD}(python([0-9.]+)?|node|nodejs|ruby)[[:space:]]+(-[ce]|--[[:alnum:]-]+|-[[:space:]]|-<<).{0,250}(open\(|write_text\(|write_bytes\(|Path\([^)]*\)\.write|writeFile(Sync)?\(|createWriteStream\(|File\.(write|open)|FileUtils\.|FS\.write)" \
    && echo "$flat" | grep -qE "\\.${SRC_EXT}${Q}"
}

gate_secrets() {
  local seg="$1" pol="${HERE}/policy/secret_paths.ere"
  local secret_name='(\.env|id_rsa|id_ed25519|id_ecdsa|\.pem|\.key|credentials\.json)'
  if shell_is_git_gh_body "$seg"; then
    if echo "$seg" | grep -qE '\$\(|`'; then
      if echo "$seg" | grep -qiE "$secret_name" || { [[ -f "$pol" ]] && printf '%s' "$seg" | grep -qiE -f "$pol"; }; then
        return 0
      fi
      return 2
    fi
    if echo "$seg" | grep -qiE '(^|[[:space:]])(-F|--file|--body-file|--notes-file)[[:space:]=]'; then
      if echo "$seg" | grep -qiE "$secret_name" || { [[ -f "$pol" ]] && printf '%s' "$seg" | grep -qiE -f "$pol"; }; then
        return 0
      fi
    fi
    return 1
  fi
  local env_seed='^[[:space:]]*cp[[:space:]]+\.env\.(example|sample|template)[[:space:]]+\.env[[:space:]]*$'
  local env_tok="(^|[[:space:]=(<@]|${Q})(\./)?\.env(rc|\.(local|development|dev|production|prod|staging|stage|test|ci|secret|secrets)(\.[^[:space:]\"';|&)]*)?)?${TERM}"
  local readers='(cat|head|tail|less|more|bat|source|\.|grep|rg|awk|sed|cut|xxd|od|base64|openssl|strings|scp|cp)'
  local key_mat="${WORD}${readers}[[:space:]]+${SEG}([^[:space:]\"']+\.(pem|key|p12|pfx)|[^[:space:]\"']*id_(rsa|ed25519|ecdsa))(${Q}|[[:space:];|&]|$)"
  local git_leak="${WORD}git[[:space:]]+(show|cat-file|checkout|restore|archive)[[:space:]]${SEG}(\.env|\.pem|\.key|id_rsa|id_ed25519|credentials)"
  if [[ -f "$pol" ]] && printf '%s' "$seg" | grep -qiE -f "$pol"; then return 0; fi
  if echo "$seg" | grep -qiE "$env_tok" && ! echo "$seg" | grep -qE "$env_seed"; then return 0; fi
  if echo "$seg" | grep -qiE "$key_mat"; then return 0; fi
  if echo "$seg" | grep -qiE "$git_leak"; then return 0; fi
  return 1
}

gate_infra() {
  local seg="$1"
  local db="(^|[;&|(][[:space:]]*)([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*(sudo[[:space:]]+|env[[:space:]]+)?(psql|mysql|mongosh)([[:space:]]|$)"
  echo "$seg" | grep -qiE "${db}|supabase[[:space:]]+db|terraform[[:space:]]+apply|kubectl[[:space:]]+delete|docker[[:space:]]+rm[[:space:]]+-f|systemctl[[:space:]]+(stop|disable)"
}

gate_shell_command() {
  local cmd="$1" rest seg scan ask=0 rc
  [[ -z "$cmd" ]] && return 1
  rest="$(split_segments "$cmd")${SEG_SEP}"
  while [[ -n "$rest" ]]; do
    seg="${rest%%"$SEG_SEP"*}"
    rest="${rest#*"$SEG_SEP"}"
    seg="${seg#"${seg%%[![:space:]]*}"}"
    seg="${seg%"${seg##*[![:space:]]}"}"
    [[ -z "$seg" ]] && continue
    scan="$seg"
    if shell_is_git_gh_body "$seg"; then scan="$(mask_git_message "$seg")"; fi
    if gate_destructive "$scan"; then
      emit_deny "AUTONOMY BLOCK: destructive command denied. Command not echoed to avoid secret leakage; see host UI." "" destructive
      return 0
    fi
    if sql_destructive_segment "$scan"; then
      emit_deny "AUTONOMY BLOCK: destructive command denied. Command not echoed to avoid secret leakage; see host UI." "" destructive
      return 0
    fi
    if gate_complexity_bypass "$scan"; then
      emit_deny "Do not disable cyclomatic lint from the shell. Extract until the project lint is green." "" lint-disable
      return 0
    fi
    if shell_writes_source "$scan"; then
      emit_deny "LEAN BYPASS BLOCK: Shell must not create/overwrite source (.ts/.tsx/.js/.jsx/.py/.go/.rs/.sh …). Use Write or StrReplace. Never Shell to write code." "" source-write
      return 0
    fi
    # Secrets see the raw segment: substitution/file flags must stay visible.
    gate_secrets "$seg"; rc=$?
    if [[ "$rc" -eq 0 ]]; then
      emit_deny "AUTONOMY BLOCK: shell must not read secret paths." "" secret-path
      return 0
    elif [[ "$rc" -eq 2 ]]; then
      ask=1
    fi
    if gate_infra "$scan"; then ask=1; fi
  done
  # Backstop: multiline stdin scripts (heredocs) span segments; check once whole.
  if shell_writes_source "$(mask_git_message "$cmd")"; then
    emit_deny "LEAN BYPASS BLOCK: Shell must not create/overwrite source (.ts/.tsx/.js/.jsx/.py/.go/.rs/.sh …). Use Write or StrReplace. Never Shell to write code." "" source-write
    return 0
  fi
  if [[ "$ask" -eq 1 ]]; then
    emit_ask "Command mutates infra/DB. Approve the concrete action, target, and scope in the Cursor card. Command not echoed to avoid secret leakage." "" ask-infra
    return 0
  fi
  return 1
}
