#!/usr/bin/env bash
# Port the pack into opencode (~/.config/opencode): charter + core + testing as
# global `instructions`, skills, stack companions as load-on-match skills, the
# specialists as subagents, the `bridle` primary agent (the Cursor custom
# mode), and the four hooks behind plugin/bridle.js.
set -euo pipefail
PACK="$(cd "$(dirname "$0")/.." && pwd)"
OC="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
OWNED="$OC/kleosrules-owned.txt"
FORCE="${FORCE:-0}"
CMD="${1:-install}"
RULES_DIR="bridle/rules"

load_lines() { grep -vE '^[[:space:]]*(#|$)' "$1" | tr -d '\r'; }

COMPANIONS="$(load_lines "$PACK/shared/config/rules.global.txt" | grep -vxE 'core|testing' | paste -sd'|' -)"

# Companions become skills here (opencode has no path-scoped rules); every
# other `name.mdc` reference follows the rename to `.md`.
port_refs() {
  sed -E "s/\`($COMPANIONS)\\.mdc\`/the \`\\1\` skill/g; s/([A-Za-z0-9_-]+)\\.mdc/\\1.md/g; s/Host-attached companions/Companion skills/g"
}

strip_frontmatter() {
  awk 'NR==1 && /^---$/ {f=1; next} f && /^---$/ {f=0; skip=1; next} f {next} skip && /^$/ {skip=0; next} {skip=0; print}' "$1"
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

# Cursor-only skill keys (custom-mode flags) are dropped.
port_skill() { grep -vE '^(mode|icon|color):' "$1" | port_refs; }

# SKILL.md plus the references/ and scripts/ the body points at.
install_skill_files() {
  local skill="$1" rel_root="$2" src f rel t
  src="$PACK/shared/skills/$skill"
  t="$(stage)"; port_skill "$src/SKILL.md" >"$t"; place "$rel_root/SKILL.md" "$t"
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    rel="${f#"$src"/}"
    t="$(stage)"
    case "$f" in
      *.md|*.txt) port_refs <"$f" >"$t" ;;
      *) cp -f "$f" "$t" ;;
    esac
    place "$rel_root/$rel" "$t"
  done < <(find "$src" -type f ! -name 'SKILL.md' | sort)
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

# The Cursor custom mode (skill `kleosr`) is the opencode primary agent `bridle`.
mode_agent() {
  printf -- '---\ndescription: >-\n  bridle session router. Coordinates the installed charter, always-on rules,\n  skills, and hooks. Does not copy the law.\nmode: primary\n---\n\n'
  strip_frontmatter "$PACK/shared/skills/kleosr/SKILL.md" | sed -E 's/^# Kleosr$/# Bridle/' | port_refs
}

is_owned() { [[ -f "$OWNED" ]] && grep -qxF "$1" "$OWNED"; }

# place REL TMP: write TMP to $OC/REL unless it would overwrite a file this
# pack does not own (FORCE=1 overwrites, keeping one backup).
place() {
  local rel="$1" tmp="$2" dst="$OC/$1"
  if [[ -f "$dst" ]] && ! is_owned "$rel" && ! cmp -s "$tmp" "$dst"; then
    if [[ "$FORCE" != "1" ]]; then
      echo "[warn] skip differing opencode/$rel (FORCE=1 to replace; backup kept)"
      rm -f "$tmp"
      return 0
    fi
    [[ -f "$dst.pre-kleos-bak" ]] || cp -f "$dst" "$dst.pre-kleos-bak"
  fi
  mkdir -p "$(dirname "$dst")"
  mv -f "$tmp" "$dst"
  printf '%s\n' "$rel" >>"$OWNED.new"
  echo "[ok] opencode/$rel"
}

stage() { mktemp "${TMPDIR:-/tmp}/kleos-oc.XXXXXX"; }

copy_into() { local t; t="$(stage)"; cp -f "$1" "$t"; place "$2" "$t"; }

install_hooks() {
  local m="$PACK/shared/config/manifest.json" f
  while IFS= read -r f; do copy_into "$PACK/shared/hooks/$f" "bridle/hooks/$f"; done < <(jq -r '.hookEvents[]' "$m" | tr -d '\r')
  while IFS= read -r f; do copy_into "$PACK/shared/hooks/lib/$f" "bridle/hooks/lib/$f"; done < <(jq -r '.runtimeLibs[]' "$m" | tr -d '\r')
  while IFS= read -r f; do copy_into "$PACK/shared/hooks/policy/$f" "bridle/hooks/policy/$f"; done < <(jq -r '.policy[]' "$m" | tr -d '\r')
  copy_into "$PACK/shared/opencode/bridle.js" "plugin/bridle.js"
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
  command -v jq >/dev/null 2>&1 || { echo "[fail] jq is required" >&2; exit 1; }
  mkdir -p "$OC"
  : >"$OWNED.new"
  t="$(stage)"; port_refs <"$PACK/shared/rules/charter.txt" >"$t"; place "$RULES_DIR/kleosr.md" "$t"
  for name in core testing; do
    t="$(stage)"; strip_frontmatter "$PACK/shared/rules/$name.mdc" | port_refs >"$t"; place "$RULES_DIR/$name.md" "$t"
  done
  while IFS= read -r name; do
    [[ "$name" == core || "$name" == testing ]] && continue
    t="$(stage)"; companion_skill "$PACK/shared/rules/$name.mdc" "$name" >"$t"; place "skills/$name/SKILL.md" "$t"
  done < <(load_lines "$PACK/shared/config/rules.global.txt")
  while IFS= read -r skill; do
    [[ "$skill" == kleosr ]] && continue
    install_skill_files "$skill" "skills/$skill"
  done < <(load_lines "$PACK/shared/config/skills.txt")
  for a in "$PACK"/shared/agents/*.md; do
    t="$(stage)"; port_agent "$a" >"$t"; place "agent/$(basename "$a")" "$t"
  done
  t="$(stage)"; mode_agent >"$t"; place agent/bridle.md "$t"
  install_hooks
  prune_stale
  mv -f "$OWNED.new" "$OWNED"
  edit_config 1
}

# Files owned by an earlier install that this one no longer writes.
prune_stale() {
  local rel
  [[ -f "$OWNED" ]] || return 0
  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    grep -qxF "$rel" "$OWNED.new" && continue
    rm -f "$OC/$rel"
    rmdir "$(dirname "$OC/$rel")" 2>/dev/null || true
    echo "[rm] opencode/$rel"
  done <"$OWNED"
}

uninstall() {
  local rel dst
  [[ -f "$OWNED" ]] || { echo "[ok] nothing installed"; return 0; }
  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    dst="$OC/$rel"
    rm -f "$dst"
    if [[ -f "$dst.pre-kleos-bak" ]]; then
      mv -f "$dst.pre-kleos-bak" "$dst"
      echo "[restore] opencode/$rel"
    else
      rmdir "$(dirname "$dst")" "$(dirname "$(dirname "$dst")")" 2>/dev/null || true
      echo "[rm] opencode/$rel"
    fi
  done <"$OWNED"
  rm -f "$OWNED"
  edit_config 0
}

case "$CMD" in
  install) install ;;
  uninstall) uninstall ;;
  *) echo "usage: [FORCE=1] bash scripts/opencode.sh {install|uninstall}" >&2; exit 2 ;;
esac
