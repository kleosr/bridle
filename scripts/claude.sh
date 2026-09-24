#!/usr/bin/env bash
# Port the pack's law, skills, and agents into Claude Code (~/.claude).
# Rules: charter + core + testing always load; stack companions carry `paths`
# so Claude Code loads them only when a matching file is read. Skills load by
# description until invoked. Cursor hooks are not ported (different contract).
set -euo pipefail
PACK="$(cd "$(dirname "$0")/.." && pwd)"
HOME_CL="${HOME}/.claude"
OWNED="$HOME_CL/kleosrules-owned.txt"
FORCE="${FORCE:-0}"
CMD="${1:-install}"

load_lines() { grep -vE '^[[:space:]]*(#|$)' "$1" | tr -d '\r'; }

# Claude Code reads `.md` rules; references to `name.mdc` follow the rename.
port_refs() { sed -E 's/([A-Za-z0-9_-]+)\.mdc/\1.md/g'; }

strip_frontmatter() {
  awk 'NR==1 && /^---$/ {f=1; next} f && /^---$/ {f=0; skip=1; next} f {next} skip && /^$/ {skip=0; next} {skip=0; print}' "$1"
}

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

# Cursor `readonly: true` → Claude Code denies the write tools.
port_agent() {
  sed -E 's/^readonly: true$/disallowedTools: Write, Edit, NotebookEdit/; /^readonly: false$/d' "$1" | port_refs
}

is_owned() { [[ -f "$OWNED" ]] && grep -qxF "$1" "$OWNED"; }

# place REL TMP: write TMP to ~/.claude/REL unless it would overwrite a file
# this pack does not own (FORCE=1 overwrites, keeping one backup).
place() {
  local rel="$1" tmp="$2" dst="$HOME_CL/$1"
  if [[ -f "$dst" ]] && ! is_owned "$rel" && ! cmp -s "$tmp" "$dst"; then
    if [[ "$FORCE" != "1" ]]; then
      echo "[warn] skip differing ~/.claude/$rel (FORCE=1 to replace; backup kept)"
      rm -f "$tmp"
      return 0
    fi
    [[ -f "$dst.pre-kleos-bak" ]] || cp -f "$dst" "$dst.pre-kleos-bak"
  fi
  mkdir -p "$(dirname "$dst")"
  mv -f "$tmp" "$dst"
  printf '%s\n' "$rel" >>"$OWNED.new"
  echo "[ok] ~/.claude/$rel"
}

stage() { mktemp "${TMPDIR:-/tmp}/kleos-claude.XXXXXX"; }

install() {
  local t name skill a
  mkdir -p "$HOME_CL"
  : >"$OWNED.new"
  t="$(stage)"; port_refs <"$PACK/shared/rules/charter.txt" >"$t"; place rules/kleosr.md "$t"
  for name in core testing; do
    t="$(stage)"; strip_frontmatter "$PACK/shared/rules/$name.mdc" | port_refs >"$t"; place "rules/$name.md" "$t"
  done
  while IFS= read -r name; do
    [[ "$name" == core || "$name" == testing ]] && continue
    t="$(stage)"; companion_rule "$PACK/shared/rules/$name.mdc" >"$t"; place "rules/$name.md" "$t"
  done < <(load_lines "$PACK/shared/config/rules.global.txt")
  while IFS= read -r skill; do
    install_skill_files "$skill" "skills/$skill"
  done < <(load_lines "$PACK/shared/config/skills.txt")
  for a in "$PACK"/shared/agents/*.md; do
    t="$(stage)"; port_agent "$a" >"$t"; place "agents/$(basename "$a")" "$t"
  done
  prune_stale
  mv -f "$OWNED.new" "$OWNED"
}

# Files owned by an earlier install that this one no longer writes.
prune_stale() {
  local rel
  [[ -f "$OWNED" ]] || return 0
  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    grep -qxF "$rel" "$OWNED.new" && continue
    rm -f "$HOME_CL/$rel"
    rmdir "$(dirname "$HOME_CL/$rel")" "$(dirname "$(dirname "$HOME_CL/$rel")")" 2>/dev/null || true
    echo "[rm] ~/.claude/$rel"
  done <"$OWNED"
}

uninstall() {
  local rel dst
  [[ -f "$OWNED" ]] || { echo "[ok] nothing installed"; return 0; }
  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    dst="$HOME_CL/$rel"
    rm -f "$dst"
    if [[ -f "$dst.pre-kleos-bak" ]]; then
      mv -f "$dst.pre-kleos-bak" "$dst"
      echo "[restore] ~/.claude/$rel"
    else
      rmdir "$(dirname "$dst")" "$(dirname "$(dirname "$dst")")" 2>/dev/null || true
      echo "[rm] ~/.claude/$rel"
    fi
  done <"$OWNED"
  rm -f "$OWNED"
}

case "$CMD" in
  install) install ;;
  uninstall) uninstall ;;
  *) echo "usage: [FORCE=1] bash scripts/claude.sh {install|uninstall}" >&2; exit 2 ;;
esac
