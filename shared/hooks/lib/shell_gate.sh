#!/usr/bin/env bash
# Shared destructive-shell checks for preToolUse(Shell|Bash) and beforeShellExecution.

gate_shell_command() {
  local cmd="$1"
  [[ -z "$cmd" ]] && return 0
  if echo "$cmd" | grep -qiE '(rm -rf? /|rm -rf? ~|mkfs|dd if=|git push --force|git push -f|drop database|truncate table|>:.*\/dev\/sd|shred )'; then
    emit_deny "AUTONOMY BLOCK: command matches a destructive pattern. Human approval required. CMD: ${cmd:0:120}"
    return 1
  fi
  if echo "$cmd" | grep -qiE '(psql|mysql|mongosh|supabase db|terraform apply|kubectl delete|docker rm -f|systemctl stop)'; then
    emit_deny "AUTONOMY BLOCK: command mutates infra/DB. Human approval required. CMD: ${cmd:0:120}"
    return 1
  fi
  return 0
}
