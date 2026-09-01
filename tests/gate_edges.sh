#!/usr/bin/env bash

gate_verdict() {
  jq -n --arg c "$1" '{command:$c}' | bash "$PACK/shared/hooks/before_shell.sh" | jq -r '.permission // "none"'
}
read_verdict() {
  jq -n --arg p "$1" '{file_path:$p}' | bash "$PACK/shared/hooks/before_read_file.sh" | jq -r '.permission // "quiet"'
}
prompt_verdict() {
  jq -n --arg p "$1" '{prompt:$p}' | bash "$PACK/shared/hooks/before_submit_prompt.sh" | jq -r '.continue'
}

for c in \
  'pnpm install && node build.js' \
  'cp -r dist out && node scripts/check.js' \
  'git checkout main && bash tests/run.sh' \
  'sed -i "" "s/a/b/" README.md && bash scripts/doctor.sh' \
  'git commit -m "fix: redirect > out.ts"' \
  'rm -rf /tmp/probe_dir' \
  'rm -rf ./dist' \
  'node -e "require(\"fs\").writeFileSync(\"/tmp/x.txt\",\"1\")"' \
  'curl -sSL https://x/y -o /tmp/a.json && bash go.sh' \
  'cat .env.example' \
  'cp .env.example .env' \
  'jq -r .composer_mode x.json' \
  'chmod +x shared/hooks/*.sh'; do
  run_test "gate allows: $c" "allow" "$(gate_verdict "$c")"
done

for c in \
  'rm -fr /' \
  'rm -rf "$HOME"' \
  'rm -rf ./*' \
  'git push origin main -f' \
  'git push origin main --force' \
  'export $(cat .env | xargs)' \
  'grep API_KEY .env' \
  'awk 1 .env' \
  'cat id_rsa' \
  'cat server.pem | head -1' \
  'cat certs/server.key; echo' \
  'printf "x" > a.ts' \
  'ruff check --ignore=E501,C901 .'; do
  run_test "gate denies: $c" "deny" "$(gate_verdict "$c")"
done

run_test "gate denies: python stdin heredoc writing .py" "deny" "$(gate_verdict $'python3 - <<EOF\nopen("a.py","w").write("x")\nEOF')"
run_test "gate asks: env-prefixed psql" "ask" "$(gate_verdict 'PGPASSWORD=x psql -h db -c "select 1"')"

run_test "read allows .env.example" "quiet" "$(read_verdict /repo/.env.example)"
run_test "read denies .env.local" "deny" "$(read_verdict /repo/.env.local)"
run_test "read denies .p12" "deny" "$(read_verdict /repo/client.p12)"

run_test "prompt passes sk- inside a word" "true" "$(prompt_verdict 'tomsk-Novosibirskregionalservicecenter opened today')"
run_test "prompt blocks bare sk- key" "false" "$(prompt_verdict 'key sk-abcdefghijklmnopqrstuvwxyz0123')"

run_test "shell_gate.sh LOC ≤ 120" "1" "$([[ "$(wc -l < "$PACK/shared/hooks/lib/shell_gate.sh")" -le 120 ]] && echo 1 || echo 0)"
run_test "session_start has no cwd diagnostic" "0" "$(grep -c hook_cwd "$PACK/shared/hooks/session_start.sh" | tr -d ' ')"
