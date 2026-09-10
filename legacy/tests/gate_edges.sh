#!/usr/bin/env bash

gate_verdict() {
  jq -n --arg c "$1" '{command:$c}' | bash "$PACK/shared/hooks/before_shell.sh" | jq -r '.permission // "none"'
}
read_verdict() {
  jq -n --arg p "$1" '{file_path:$p}' | bash "$PACK/shared/hooks/before_read_file.sh" | jq -r '.permission // "none"'
}
prompt_verdict() {
  jq -n --arg p "$1" '{prompt:$p}' | bash "$PACK/shared/hooks/before_submit_prompt.sh" | jq -r '.continue'
}

for c in \
  'pnpm install && node scripts/build.js' \
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
  run_test "regression: gate allows: $c" "allow" "$(gate_verdict "$c")"
done

for c in \
  'rm -fr /' \
  'rm -rf "$HOME"' \
  'rm -rf ./*' \
  'rm -rf /.' \
  'rm -rf /..' \
  'rm -rf //' \
  'rm -rf /tmp/..' \
  'rm -rf "$HOME"/*' \
  'git push origin main -f' \
  'git push origin main --force' \
  'git push -fu origin' \
  'git clean --force' \
  'export $(cat .env | xargs)' \
  'grep API_KEY .env' \
  'awk 1 .env' \
  'cp .env.example .env && cat .env' \
  'cat .env.dev' \
  'source .env.prod' \
  'cat id_rsa' \
  'cat server.pem | head -1' \
  'cat certs/server.key; echo' \
  'printf "x" > a.ts' \
  'echo x > "my file.ts"' \
  'ruff check --ignore=E501,C901 .'; do
  run_test "regression: gate denies: $c" "deny" "$(gate_verdict "$c")"
done

run_test "regression: gate denies python stdin heredoc writing .py" "deny" "$(gate_verdict $'python3 - <<EOF\nopen("a.py","w").write("x")\nEOF')"
run_test "regression: gate asks env-prefixed psql" "ask" "$(gate_verdict 'PGPASSWORD=x psql -h db -c "select 1"')"

run_test "regression: read allows .env.example" "allow" "$(read_verdict /repo/.env.example)"
run_test "regression: read denies .env.local" "deny" "$(read_verdict /repo/.env.local)"
run_test "regression: read denies .p12" "deny" "$(read_verdict /repo/client.p12)"
run_test "regression: read denies Windows backslash .env" "deny" "$(read_verdict 'C:\Users\x\.env')"
run_test "regression: read denies Windows drive .env" "deny" "$(read_verdict 'C:/Users/x/.env')"
run_test "regression: read denies uppercase .ENV" "deny" "$(read_verdict /repo/.ENV)"
run_test "regression: read denies ID_RSA" "deny" "$(read_verdict /repo/ID_RSA)"
run_test "regression: gate denies cat .ENV" "deny" "$(gate_verdict 'cat .ENV')"
run_test "regression: gate denies git commit -m \$(cat .env)" "deny" "$(gate_verdict $'git commit -m "$(cat .env)"')"
run_test "regression: gate denies git commit -F .env" "deny" "$(gate_verdict 'git commit -F .env')"
run_test "regression: gate denies gh pr --body-file .env" "deny" "$(gate_verdict 'gh pr create --body-file .env')"

run_test "regression: prompt passes sk- inside a word" "true" "$(prompt_verdict 'tomsk-Novosibirskregionalservicecenter opened today')"
run_test "regression: prompt blocks bare sk- key" "false" "$(prompt_verdict 'key sk-abcdefghijklmnopqrstuvwxyz0123')"

run_test "regression: grounding.sh has no BSD sed -i" "0" "$(grep -c "sed -i ''" "$PACK/tests/grounding.sh" | tr -d ' ')"

NOPOL="$(mktemp -d "${TMPDIR:-/tmp}/kleos-nopol.XXXXXX")"
mkdir -p "$NOPOL/lib"
cp "$PACK/shared/hooks/before_read_file.sh" "$NOPOL/"
cp "$PACK/shared/hooks/lib/common.sh" "$NOPOL/lib/"
RESULT="$(printf '%s' '{"file_path":"/x/.env"}' | bash "$NOPOL/before_read_file.sh" | jq -r '.permission // "none"')"
rm -rf "$NOPOL"
run_test "regression: before_read_file missing secret_paths.ere denies" "deny" "$RESULT"

RESULT="$(printf '%s' 'not json' | bash "$PACK/shared/hooks/before_read_file.sh" | jq -r '.permission // "none"')"
run_test "regression: before_read_file non-JSON denies" "deny" "$RESULT"

RESULT="$(printf '%s' 'not json' | bash "$PACK/shared/hooks/before_shell.sh" | jq -r '.permission // "none"')"
run_test "regression: before_shell non-JSON denies" "deny" "$RESULT"

run_test "regression: read denies bare .env" "deny" "$(read_verdict '.env')"
run_test "regression: read denies bare id_rsa" "deny" "$(read_verdict 'id_rsa')"
run_test "regression: read denies traversal to .env" "deny" "$(read_verdict '/repo/a/../.env')"
run_test "regression: read denies dot-slash .env" "deny" "$(read_verdict './.env')"
run_test "regression: deny wins over infra ask" "deny" "$(gate_verdict 'psql -c "select 1" && cat .env')"
run_test "regression: deny wins over infra ask (source-write)" "deny" "$(gate_verdict 'psql -c "select 1"; echo x > a.ts')"
run_test "regression: installer with shell metachars denied" "deny" "$(gate_verdict 'bash scripts/install.sh; rm -rf /')"
run_test "regression: installer with pipe denied" "deny" "$(gate_verdict 'bash shared/hooks/fleet_sync.sh install | cat .env')"
run_test "regression: fleet_sync unknown arg is not privileged" "allow" "$(gate_verdict 'bash shared/hooks/fleet_sync.sh --evil')"
