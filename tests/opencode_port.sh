#!/usr/bin/env bash
# Sourced by run.sh. opencode port: installer shape in an isolated HOME, and
# the plugin's mapping of hook verdicts onto opencode events.

OC_H="$(mktemp -d "${TMPDIR:-/tmp}/kleos-oc.XXXXXX")"
OC="$OC_H/.config/opencode"
OC_EC=0
HOME="$OC_H" XDG_CONFIG_HOME="" bash "$PACK/scripts/opencode.sh" install >/dev/null 2>&1 || OC_EC=$?
run_test "opencode port install exits 0" "0" "$OC_EC"
RESULT="$(grep -q 'You are kleosr'"'"'s engineering partner' "$OC/bridle/rules/kleosr.md" 2>/dev/null && echo yes || echo no)"
run_test "opencode port writes the charter" "yes" "$RESULT"
RESULT="$(jq -r '.default_agent' "$OC/opencode.json" 2>/dev/null)"
run_test "opencode port makes bridle the default agent" "bridle" "$RESULT"
RESULT="$(jq -r '[.instructions[] | select(test("bridle/rules/(kleosr|core|testing)\\.md$"))] | length' "$OC/opencode.json" 2>/dev/null)"
run_test "opencode port loads charter, core, testing as instructions" "3" "$RESULT"
RESULT="$(grep -c '^mode: primary$' "$OC/agent/bridle.md" 2>/dev/null || true)"
run_test "opencode port writes the bridle custom mode as a primary agent" "1" "$RESULT"
RESULT="$(test -e "$OC/agent/kleosr.md" -o -e "$OC/skills/kleosr" && echo present || echo absent)"
run_test "opencode port installs no kleosr agent or skill" "absent" "$RESULT"
RESULT="$(grep -c '^  edit: deny$' "$OC/agent/hunter.md" 2>/dev/null || true)"
run_test "opencode port maps readonly agents to edit: deny" "1" "$RESULT"
if grep -qE '^(model|name|readonly):' "$OC/agent/hunter.md" "$OC/agent/prove.md"; then RESULT=kept; else RESULT=dropped; fi
run_test "opencode port drops Cursor-only agent keys" "dropped" "$RESULT"
RESULT="$(grep -c '^name: next$' "$OC/skills/next/SKILL.md" 2>/dev/null || true)"
run_test "opencode port ships stack companions as skills" "1" "$RESULT"
RESULT="$(test -f "$OC/skills/code-architecture/scripts/quality-gate.mjs" && test -f "$OC/skills/cqrs-data-flow/references/sql-repository.md" && echo yes || echo no)"
run_test "opencode port ships skill references and the quality gate" "yes" "$RESULT"
if grep -rq '\.mdc' "$OC/bridle/rules" "$OC/skills" "$OC/agent" 2>/dev/null; then RESULT=stale; else RESULT=ok; fi
run_test "opencode port rewrites .mdc references" "ok" "$RESULT"
RESULT="$(test -f "$OC/plugin/bridle.js" -a -f "$OC/bridle/hooks/lib/shell_gate.sh" -a -f "$OC/bridle/hooks/policy/secret_paths.ere" && echo yes || echo no)"
run_test "opencode port installs the plugin and its hooks" "yes" "$RESULT"
HOME="$OC_H" XDG_CONFIG_HOME="" bash "$PACK/scripts/opencode.sh" install >/dev/null 2>&1 || true
RESULT="$(jq -r '.instructions | length' "$OC/opencode.json" 2>/dev/null)"
run_test "regression: opencode port reinstall does not duplicate instructions" "3" "$RESULT"

if command -v node >/dev/null 2>&1; then
  PLUGIN_URL="file://$(cd "$OC/plugin" && pwd -W 2>/dev/null || pwd)/bridle.js"
  [[ "$PLUGIN_URL" == file://[A-Za-z]:* ]] && PLUGIN_URL="file:///${PLUGIN_URL#file://}"
  # probe TOOL ARGS_JSON: prints allow, or block:<reason>.
  oc_probe() {
    node --input-type=module -e '
      const { BridlePlugin } = await import(process.argv[1]);
      const h = await BridlePlugin({ client: {}, directory: process.cwd(), worktree: process.cwd() });
      try { await h["tool.execute.before"]({ tool: process.argv[2] }, { args: JSON.parse(process.argv[3]) }); console.log("allow"); }
      catch (e) { console.log("block:" + (/^\[bridle ([^\]]+)\]/.exec(e.message) || [, "?"])[1]); }
    ' "$PLUGIN_URL" "$1" "$2" 2>/dev/null
  }
  run_test "opencode plugin: read of a source file is allowed" "allow" "$(oc_probe read '{"filePath":"C:/proj/src/a.ts"}')"
  run_test "opencode plugin: read of .env is denied" "block:secret-path" "$(oc_probe read '{"filePath":"C:\\proj\\.env"}')"
  run_test "opencode plugin: git status is allowed" "allow" "$(oc_probe bash '{"command":"git status"}')"
  run_test "opencode plugin: force push is denied" "block:destructive" "$(oc_probe bash '{"command":"echo a && git push --force origin main"}')"
  run_test "opencode plugin: infra change needs approval" "block:ask-infra" "$(oc_probe bash '{"command":"terraform apply"}')"
  run_test "opencode plugin: untouched tools pass" "allow" "$(oc_probe edit '{"filePath":"a.ts"}')"
  RESULT="$(BRIDLE_HOOKS_DIR="$OC_H/missing" oc_probe read '{"filePath":"a.ts"}')"
  run_test "opencode plugin: a missing hook fails closed" "block:hook-failed" "$RESULT"
  RESULT="$(node --input-type=module -e '
    const { BridlePlugin } = await import(process.argv[1]);
    const h = await BridlePlugin({ client: {}, directory: process.cwd(), worktree: process.cwd() });
    const parts = [{ type: "text", text: "token ghp_" + "Z".repeat(36) }];
    try { await h["chat.message"]({ sessionID: "s" }, { message: {}, parts }); console.log("sent"); }
    catch { console.log(parts[0].text.includes("ghp_") ? "leaked" : "withheld"); }
  ' "$PLUGIN_URL" 2>/dev/null)"
  run_test "opencode plugin: a secret in the prompt is withheld" "withheld" "$RESULT"
else
  echo "[skip] opencode plugin probes: node not on PATH"
fi

HOME="$OC_H" XDG_CONFIG_HOME="" bash "$PACK/scripts/opencode.sh" uninstall >/dev/null 2>&1 || true
RESULT="$(test -e "$OC/agent/bridle.md" -o -e "$OC/plugin/bridle.js" && echo present || echo gone)"
run_test "opencode port uninstall removes owned files" "gone" "$RESULT"
RESULT="$(test -e "$OC/skills/code-architecture/scripts/quality-gate.mjs" && echo present || echo gone)"
run_test "opencode port uninstall removes skill sidecars" "gone" "$RESULT"
RESULT="$(jq -r 'has("default_agent") or has("instructions")' "$OC/opencode.json" 2>/dev/null)"
run_test "opencode port uninstall removes its config keys" "false" "$RESULT"
rm -rf "$OC_H"
