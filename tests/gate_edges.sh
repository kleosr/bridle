#!/usr/bin/env bash
# Sourced by run.sh. Regression edges: false positives, bypasses, malformed.

gate_verdict() {
  jq -n --arg c "$1" '{command:$c,cwd:"/tmp"}' | bash "$PACK/shared/hooks/before_shell.sh" | jq -r '.permission // "none"'
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
run_test "regression: gate denies psql heredoc DROP TABLE" "deny" "$(gate_verdict $'psql <<EOF\nDROP TABLE t\nEOF')"
run_test "regression: gate denies piped DROP TABLE to sqlite3" "deny" "$(gate_verdict "echo 'DROP TABLE t' | sqlite3 db")"
run_test "regression: gate denies piped DROP TABLE to psql" "deny" "$(gate_verdict "echo 'DROP TABLE t' | psql")"
run_test "regression: gate allows grep drop table dump" "allow" "$(gate_verdict "grep 'drop table' dump.sql")"
run_test "regression: gate asks env-prefixed psql" "ask" "$(gate_verdict 'PGPASSWORD=x psql -h db -c "select 1"')"

run_test "regression: read allows .env.example" "allow" "$(read_verdict /repo/.env.example)"
run_test "regression: read allows .env.dist template" "allow" "$(read_verdict /repo/.env.dist)"
run_test "regression: read denies .env.local" "deny" "$(read_verdict /repo/.env.local)"
run_test "regression: read denies .env.bak" "deny" "$(read_verdict /repo/.env.bak)"
run_test "regression: read denies .p12" "deny" "$(read_verdict /repo/client.p12)"
run_test "regression: read denies Windows backslash .env" "deny" "$(read_verdict 'C:\Users\x\.env')"
run_test "regression: read denies uppercase .ENV" "deny" "$(read_verdict /repo/.ENV)"
run_test "regression: gate denies cat .ENV" "deny" "$(gate_verdict 'cat .ENV')"
run_test "regression: gate denies git commit -m \$(cat .env)" "deny" "$(gate_verdict $'git commit -m "$(cat .env)"')"
run_test "regression: gate denies git commit -F .env" "deny" "$(gate_verdict 'git commit -F .env')"
run_test "regression: gate denies gh pr --body-file .env" "deny" "$(gate_verdict 'gh pr create --body-file .env')"

# Per-segment gating: a git/gh message suppresses its own argument only.
run_test "regression: compound commit + cat .env denies" "deny" "$(gate_verdict 'git commit -m "x" && cat .env')"
run_test "regression: compound commit + complexity-off denies" "deny" "$(gate_verdict 'git commit -m "x" && eslint --rule complexity:off src/a.ts')"
run_test "regression: semicolon commit + ssh key denies" "deny" "$(gate_verdict 'git commit -m "x"; cat ~/.ssh/id_rsa')"
run_test "regression: plain git status + cat .env denies" "deny" "$(gate_verdict 'git status && cat .env')"
run_test "regression: gh pr + secret grep denies" "deny" "$(gate_verdict 'gh pr create --title x && grep KEY .env')"

run_test "regression: prompt passes sk- inside a word" "true" "$(prompt_verdict 'tomsk-Novosibirskregionalservicecenter opened today')"
run_test "regression: prompt blocks bare sk- key" "false" "$(prompt_verdict 'key sk-abcdefghijklmnopqrstuvwxyz0123')"

# Ownership is by exact basename: colliding user names must survive strip/merge.
OWN_DEST="$(mktemp "${TMPDIR:-/tmp}/kleos-own.XXXXXX")"
printf '{"version":1,"hooks":{"stop":[{"command":"/home/u/.cursor/hooks/my_stop.sh"},{"command":"./hooks/stop.sh"}],"beforeShellExecution":[{"command":"sh custom_before_shell.sh"}]}}' >"$OWN_DEST"
OWN_STRIP="$(jq --arg mode strip --slurpfile dest "$OWN_DEST" -f "$PACK/shared/hooks/lib/hooks_json.jq" "$OWN_DEST")"
OWN_KEEP_MY="$(printf '%s' "$OWN_STRIP" | jq -r '[.hooks.stop[]?.command] | map(select(test("my_stop"))) | length')"
OWN_KEEP_CUSTOM="$(printf '%s' "$OWN_STRIP" | jq -r '[.hooks.beforeShellExecution[]?.command] | map(select(test("custom_before_shell"))) | length')"
OWN_DROP_PACK="$(printf '%s' "$OWN_STRIP" | jq -r '[.hooks.stop[]?.command] | map(select(test("\\./hooks/stop"))) | length')"
rm -f "$OWN_DEST"
run_test "regression: strip keeps user my_stop.sh" "1" "$OWN_KEEP_MY"
run_test "regression: strip keeps user custom_before_shell.sh" "1" "$OWN_KEEP_CUSTOM"
run_test "regression: strip removes pack ./hooks/stop.sh" "0" "$OWN_DROP_PACK"

RESULT="$(printf '%s' 'not json' | bash "$PACK/shared/hooks/before_read_file.sh" | jq -r '.permission // "none"')"
run_test "regression: before_read_file non-JSON denies" "deny" "$RESULT"

RESULT="$(printf '%s' 'not json' | bash "$PACK/shared/hooks/before_shell.sh" | jq -r '.permission // "none"')"
run_test "regression: before_shell non-JSON denies" "deny" "$RESULT"

RESULT="$(echo '{"command":{"nested":"rm -rf /"}}' | bash "$PACK/shared/hooks/before_shell.sh" | jq -r '.permission // "none"')"
run_test "before_shell non-string command denies" "deny" "$RESULT"

RESULT="$(echo '{"tool_input":{"command":"rm -rf /"}}' | bash "$PACK/shared/hooks/before_shell.sh" | jq -r '.permission // "none"')"
run_test "before_shell nested tool_input.command still gates" "deny" "$RESULT"

RESULT="$(echo '{}' | bash "$PACK/shared/hooks/before_shell.sh" | jq -r '.permission // "allow"')"
run_test "before_shell empty command allows" "allow" "$RESULT"

RESULT="$(echo '{}' | bash "$PACK/shared/hooks/before_read_file.sh" | jq -r '.permission // "none"')"
run_test "before_read_file missing file_path allows" "allow" "$RESULT"

RESULT="$(printf '%s' 'not json at all' | bash "$PACK/shared/hooks/before_submit_prompt.sh" | jq -r 'if has("continue") then (.continue|tostring) else "missing" end')"
run_test "before_submit malformed JSON blocks (continue:false)" "false" "$RESULT"

RESULT="$(echo '{}' | bash "$PACK/shared/hooks/before_submit_prompt.sh" | jq -r '.continue')"
run_test "before_submit empty prompt continues" "true" "$RESULT"

# Fleet activation uses the payload cwd, never the hook process cwd.
RESULT="$(cd "$PACK" && jq -n '{command:"FORCE=1 bash shared/hooks/fleet_sync.sh install",cwd:$PACK}' --arg PACK "$PACK" | bash "$PACK/shared/hooks/before_shell.sh" | jq -r '.permission // "allow"')"
run_test "beforeShellExecution asks for fleet_sync install with pack cwd" "ask" "$RESULT"

NOPACK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kleos-nopack.XXXXXX")"
RESULT="$(jq -n --arg d "$NOPACK_DIR" '{command:"bash scripts/install.sh",cwd:$d}' | bash "$PACK/shared/hooks/before_shell.sh" | jq -r '.permission // "none"')"
rm -rf "$NOPACK_DIR"
run_test "regression: installer path without pack markers denied" "deny" "$RESULT"

RESULT="$(jq -n --arg cmd $'FORCE=1 bash shared/hooks/fleet_sync.sh install\nrm -rf /' --arg d "$PACK" '{command:$cmd,cwd:$d}' | bash "$PACK/shared/hooks/before_shell.sh" | jq -r '.permission // "none"')"
run_test "regression: multiline after fleet_sync does not skip destructive deny" "deny" "$RESULT"

RESULT="$(echo '{"command":"bash shared/hooks/fleet_sync.sh --evil","cwd":"/tmp"}' | bash "$PACK/shared/hooks/before_shell.sh" | jq -r '.permission // "none"')"
run_test "regression: fleet_sync unknown arg is not privileged" "allow" "$RESULT"

run_test "regression: deny wins over infra ask" "deny" "$(gate_verdict 'psql -c "select 1" && cat .env')"
run_test "regression: deny wins over infra ask (source-write)" "deny" "$(gate_verdict 'psql -c "select 1"; echo x > a.ts')"
run_test "regression: read denies bare .env" "deny" "$(read_verdict '.env')"
run_test "regression: read denies bare id_rsa" "deny" "$(read_verdict 'id_rsa')"
run_test "regression: read denies traversal to .env" "deny" "$(read_verdict '/repo/a/../.env')"
run_test "regression: read denies dot-slash .env" "deny" "$(read_verdict './.env')"
