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
  'git push origin main -f; echo' \
  'git push --force; true' \
  'rm -rf /|true' \
  'git clean --force' \
  'git commit -m "ok" && printf x > a.ts' \
  'gh pr create --title t --body b && echo x > a.ts' \
  'export $(cat .env | xargs)' \
  'grep API_KEY .env' \
  'awk 1 .env' \
  'cp .env.example .env && cat .env' \
  'cat .env.dev' \
  'source .env.prod' \
  'cat .env.backup' \
  'cat .env.qa' \
  'cat .env*' \
  'cat .env.local*' \
  'cat .ENV' \
  'source .Env' \
  'cat id_rsa' \
  'cat server.pem | head -1' \
  'cat certs/server.key; echo' \
  'printf "x" > a.ts' \
  'echo x > "my file.ts"' \
  'ruff check --ignore=E501,C901 .'; do
  run_test "regression: gate denies: $c" "deny" "$(gate_verdict "$c")"
done

run_test "regression: gate denies python stdin heredoc writing .py" "deny" "$(gate_verdict $'python3 - <<EOF\nopen("a.py","w").write("x")\nEOF')"
run_test "regression: gate denies python heredoc writing .py (no dash)" "deny" "$(gate_verdict $'python3 <<EOF\nopen("a.py","w").write("x")\nEOF')"
run_test "regression: gate denies node heredoc writing .js" "deny" "$(gate_verdict $'node <<EOF\nrequire("fs").writeFileSync("a.js","x")\nEOF')"
run_test "regression: gate asks env-prefixed psql" "ask" "$(gate_verdict 'PGPASSWORD=x psql -h db -c "select 1"')"

run_test "regression: read allows .env.example" "quiet" "$(read_verdict /repo/.env.example)"
run_test "regression: read allows .env.sample" "quiet" "$(read_verdict /repo/.env.sample)"
run_test "regression: read denies .env.local" "deny" "$(read_verdict /repo/.env.local)"
run_test "regression: read denies .env.backup" "deny" "$(read_verdict /repo/.env.backup)"
run_test "regression: read denies .env.qa" "deny" "$(read_verdict /repo/.env.qa)"
run_test "regression: read denies .p12" "deny" "$(read_verdict /repo/client.p12)"

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
run_test "regression: before_shell non-JSON asks" "ask" "$RESULT"
