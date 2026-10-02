#!/usr/bin/env bash
# Port the pack into opencode (~/.config/opencode): charter + core + testing as
# global `instructions`, skills, stack companions as load-on-match skills, the
# specialists as subagents, the `bridle` primary agent (the Cursor custom
# mode), and the three hooks behind plugin/bridle.js.
set -euo pipefail
PACK="$(cd "$(dirname "$0")/../.." && pwd)"
OC="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
DEST="$OC"
LABEL="opencode"
FORCE="${FORCE:-0}"
CMD="${1:-install}"
RULES_DIR="bridle/rules"
# shellcheck source=hosts/lib.sh
source "$PACK/hosts/lib.sh"

COMPANIONS="$(manifest_list '.rules[]' | grep -vxE 'core|testing' | paste -sd'|' -)"

# Companions become skills here (opencode has no path-scoped rules); every
# other `name.mdc` reference follows the rename to `.md`.
port_refs() {
  sed -E "s/\`($COMPANIONS)\\.mdc\`/the \`\\1\` skill/g; s/([A-Za-z0-9_-]+)\\.mdc/\\1.md/g; s/Host-attached companions/Companion skills/g"
}

frontmatter_value() { grep -m1 "^$2:" "$1" | sed -E "s/^$2:[[:space:]]*//; s/^\"(.*)\"$/\\1/" | tr -d '\r'; }

companion_skill() {
  local src="$1" name="$2" desc globs
  desc="$(frontmatter_value "$src" description)"
  globs="$(frontmatter_value "$src" globs)"
  [[ -n "$globs" ]] || { echo "[fail] $src has no globs" >&2; return 1; }
  printf -- '---\nname: %s\ndescription: >-\n  %s Load before editing files matching: %s. Inert unless the owning package matches.\n---\n\n' "$name" "$desc" "$globs"
  strip_frontmatter "$src" | port_refs
}

# Cursor agent keys → opencode: the file name is the agent name, `inherit` is
# the default model, and `readonly: true` denies the edit tools.
port_agent() {
  awk 'NR==1 && /^---$/ {fm=1; print; next}
       fm && /^---$/ {fm=0; print "mode: subagent"; if (ro) print "permission:\n  edit: deny"; print; next}
       fm && /^(name|model):/ {next}
       fm && /^readonly: true/ {ro=1; next}
       fm && /^readonly:/ {next}
       {print}' "$1" | tr -d '\r' | port_refs
}

# The `bridle-harness` router is the opencode primary agent `bridle`.
mode_agent() {
  printf -- '---\ndescription: >-\n  bridle session router. Coordinates the installed charter, always-on rules,\n  skills, and hooks. Does not copy the law.\nmode: primary\n---\n\n'
  strip_frontmatter "$PACK/skills/bridle-harness/SKILL.md" | sed -E 's/^# Bridle harness .*$/# Bridle/' | port_refs
}

config_file() {
  if [[ -f "$OC/opencode.jsonc" ]]; then echo "$OC/opencode.jsonc"; else echo "$OC/opencode.json"; fi
}

# Absolute rule paths as opencode (a native Windows process) resolves them.
rule_paths_json() {
  local dir="$OC/$RULES_DIR"
  command -v cygpath >/dev/null 2>&1 && dir="$(cygpath -m "$dir")"
  jq -nc --arg d "$dir" '[$d + "/kleosr.md", $d + "/core.md", $d + "/testing.md"]'
}

# edit_config ADD: ADD=1 sets `default_agent: bridle` and our instructions;
# ADD=0 removes exactly those. JSONC with comments is left to the person.
edit_config() {
  local add="$1" cfg ours t
  cfg="$(config_file)"
  ours="$(rule_paths_json)"
  if [[ ! -f "$cfg" ]]; then
    [[ "$add" == 1 ]] || return 0
    printf '{"$schema":"https://opencode.ai/config.json"}\n' >"$cfg"
  fi
  if ! jq -e . "$cfg" >/dev/null 2>&1; then
    echo "[warn] $cfg is not plain JSON; set \"default_agent\": \"bridle\" and \"instructions\": $ours by hand"
    return 0
  fi
  t="$(stage)"
  if [[ "$add" == 1 ]]; then
    [[ -f "$cfg.pre-kleos-bak" ]] || cp -f "$cfg" "$cfg.pre-kleos-bak"
    jq --argjson o "$ours" '.default_agent = "bridle" | .instructions = (((.instructions // []) - $o) + $o)' "$cfg" >"$t"
  else
    jq --argjson o "$ours" 'if .default_agent == "bridle" then del(.default_agent) else . end
      | if .instructions then .instructions -= $o else . end
      | if .instructions == [] then del(.instructions) else . end' "$cfg" >"$t"
  fi
  mv -f "$t" "$cfg"
  echo "[ok] $(basename "$cfg") $([[ "$add" == 1 ]] && echo 'default_agent=bridle, instructions' || echo 'bridle keys removed')"
}

install() {
  local t name skill a
  begin_install
  t="$(stage)"; port_refs <"$PACK/rules/charter.txt" >"$t"; place "$RULES_DIR/kleosr.md" "$t"
  while IFS= read -r name; do
    t="$(stage)"
    case "$name" in
      core|testing) strip_frontmatter "$PACK/rules/$name.mdc" | port_refs >"$t"; place "$RULES_DIR/$name.md" "$t" ;;
      *) companion_skill "$PACK/rules/$name.mdc" "$name" >"$t"; place "skills/$name/SKILL.md" "$t" ;;
    esac
  done < <(manifest_list '.rules[]')
  while IFS= read -r skill; do
    install_skill_files "$skill" "skills/$skill"
  done < <(manifest_list '.skills[]')
  while IFS= read -r a; do
    t="$(stage)"; port_agent "$PACK/agents/$a.md" >"$t"; place "agent/$a.md" "$t"
  done < <(manifest_list '.agents[]')
  t="$(stage)"; mode_agent >"$t"; place agent/bridle.md "$t"
  install_gate bridle/hooks opencode
  copy_into "$PACK/hosts/opencode/bridle.js" plugin/bridle.js
  finish_install
  edit_config 1
}

case "$CMD" in
  install) install ;;
  uninstall) uninstall_owned; edit_config 0 ;;
  *) echo "usage: [FORCE=1] bash hosts/opencode/install.sh {install|uninstall}" >&2; exit 2 ;;
esac
