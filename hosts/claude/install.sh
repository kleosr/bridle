#!/usr/bin/env bash
# Port the pack's law, skills, and agents into Claude Code (~/.claude).
# Rules: charter + core + testing always load; stack companions carry `paths`
# so Claude Code loads them only when a matching file is read. Skills load by
# description until invoked. The three gates run from hooks/ with the Claude
# verdict (UserPromptSubmit, PreToolUse Bash and Read); a PreToolUse(Write)
# hook enforces core.md's edit and size law and a Stop hook checks the turn's
# verification, footprint, and wiring.
set -euo pipefail
PACK="$(cd "$(dirname "$0")/../.." && pwd)"
HOME_CL="${HOME}/.claude"
DEST="$HOME_CL"
LABEL="~/.claude"
FORCE="${FORCE:-0}"
CMD="${1:-install}"
# shellcheck source=hosts/lib.sh
source "$PACK/hosts/lib.sh"

# Claude Code reads `.md` rules; references to `name.mdc` follow the rename.
port_refs() { sed -E 's/([A-Za-z0-9_-]+)\.mdc/\1.md/g'; }

# Cursor `globs: a, b` → Claude Code `paths:` list. Each glob is quoted: a
# bare leading `*` is a YAML alias, and a parse error would load the rule always.
companion_rule() {
  local src="$1" globs
  globs="$(grep -m1 '^globs:' "$src" | sed 's/^globs:[[:space:]]*//' | tr -d '\r')"
  [[ -n "$globs" ]] || { echo "[fail] $src has no globs" >&2; return 1; }
  printf -- '---\npaths:\n'
  printf '%s\n' "$globs" | tr ',' '\n' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' | awk 'NF {printf "  - \"%s\"\n", $0}'
  printf -- '---\n\n'
  strip_frontmatter "$src" | port_refs
}

# Cursor `readonly: true` → Claude Code denies the write tools.
port_agent() {
  sed -E 's/^readonly: true$/disallowedTools: Write, Edit, NotebookEdit/; /^readonly: false$/d' "$1" | port_refs
}

SETTINGS="$HOME_CL/settings.json"
HOOK_REL=hooks/bridle_before_write.sh
STOP_REL=hooks/bridle_before_stop.sh
GATE_REL=hooks/bridle

# settings.json is the user's file: edit only the bridle hook entries, refuse
# to touch a file that is not valid JSON.
drop_hook_entry() {
  jq --arg w "$HOOK_REL" --arg s "$STOP_REL" --arg g "$GATE_REL/" '
    reduce ([["PreToolUse", $w], ["Stop", $s], ["PreToolUse", $g], ["UserPromptSubmit", $g]][]) as [$e, $h] (.;
      if .hooks[$e] then
        .hooks[$e] |= map(select(any(.hooks[]?; .command | contains($h)) | not))
        | if .hooks[$e] == [] then del(.hooks[$e]) else . end
        | if .hooks == {} then del(.hooks) else . end
      else . end)'
}

register_hook() {
  local t cmd="bash \"$HOME_CL/$HOOK_REL\""
  [[ -f "$SETTINGS" ]] || echo '{}' >"$SETTINGS"
  jq empty "$SETTINGS" 2>/dev/null || { echo "[fail] ~/.claude/settings.json is not valid JSON; hook not registered" >&2; return 1; }
  t="$(stage)"
  drop_hook_entry <"$SETTINGS" | jq --arg c "$cmd" --arg s "bash \"$HOME_CL/$STOP_REL\"" \
    --arg g "BRIDLE_HOST=claude bash \"$HOME_CL/$GATE_REL" '
    def gate($f; $t): [{type: "command", command: ($g + "/" + $f + "\""), timeout: $t}];
    .hooks.PreToolUse += [{matcher: "Write", hooks: [{type: "command", command: $c}]},
                          {matcher: "Bash", hooks: gate("before_shell.sh"; 60)},
                          {matcher: "Read", hooks: gate("before_read_file.sh"; 30)}]
     | .hooks.UserPromptSubmit += [{hooks: gate("before_submit_prompt.sh"; 30)}]
     | .hooks.Stop += [{hooks: [{type: "command", command: $s}]}]' >"$t"
  mv -f "$t" "$SETTINGS"
  echo "[ok] ~/.claude/settings.json UserPromptSubmit, PreToolUse(Bash, Read, Write), and Stop hooks"
}

unregister_hook() {
  local t
  [[ -f "$SETTINGS" ]] && jq empty "$SETTINGS" 2>/dev/null || return 0
  t="$(stage)"
  drop_hook_entry <"$SETTINGS" >"$t"
  mv -f "$t" "$SETTINGS"
  echo "[rm] ~/.claude/settings.json bridle hooks"
}

install() {
  local t name skill a
  begin_install
  t="$(stage)"; port_refs <"$PACK/rules/charter.txt" >"$t"; place rules/kleosr.md "$t"
  while IFS= read -r name; do
    t="$(stage)"
    case "$name" in
      core|testing) strip_frontmatter "$PACK/rules/$name.mdc" | port_refs >"$t" ;;
      *) companion_rule "$PACK/rules/$name.mdc" >"$t" ;;
    esac
    place "rules/$name.md" "$t"
  done < <(manifest_list '.rules[]')
  while IFS= read -r skill; do
    install_skill_files "$skill" "skills/$skill"
  done < <(manifest_list '.skills[]')
  while IFS= read -r a; do
    t="$(stage)"; port_agent "$PACK/agents/$a.md" >"$t"; place "agents/$a.md" "$t"
  done < <(manifest_list '.agents[]')
  copy_into "$PACK/hosts/claude/before_write.sh" "$HOOK_REL" x
  copy_into "$PACK/hosts/claude/before_stop.sh" "$STOP_REL" x
  install_gate "$GATE_REL" claude
  register_hook
  finish_install
}

case "$CMD" in
  install) install ;;
  uninstall) unregister_hook; uninstall_owned ;;
  *) echo "usage: [FORCE=1] bash hosts/claude/install.sh {install|uninstall}" >&2; exit 2 ;;
esac
