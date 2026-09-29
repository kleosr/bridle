#!/usr/bin/env bash
# Shared by the host installers: manifest lists, owned-file placement with
# backups, the gate tree copy, stale pruning, and uninstall. Port callers set
# PACK, DEST (install root), LABEL (log prefix), FORCE, and define port_refs.

HOSTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

manifest_json() { printf '%s\n' "${MANIFEST_JSON:-$HOSTS_DIR/manifest.json}"; }

# manifest_list FILTER: one item per line from hosts/manifest.json.
manifest_list() { jq -r "$1" "$(manifest_json)" 2>/dev/null | tr -d '\r'; }

strip_frontmatter() {
  awk 'NR==1 && /^---$/ {f=1; next} f && /^---$/ {f=0; skip=1; next} f {next} skip && /^$/ {skip=0; next} {skip=0; print}' "$1"
}

# Cursor-only skill keys (custom-mode flags) are dropped.
port_skill() { grep -vE '^(mode|icon|color):' "$1" | port_refs; }

stage() { mktemp "${TMPDIR:-/tmp}/kleos-port.XXXXXX"; }

is_owned() { [[ -f "$DEST/kleosrules-owned.txt" ]] && grep -qxF "$1" "$DEST/kleosrules-owned.txt"; }

# place REL TMP: write TMP to $DEST/REL unless it would overwrite a file this
# pack does not own (FORCE=1 overwrites, keeping one backup).
place() {
  local rel="$1" tmp="$2" dst="$DEST/$1"
  if [[ -f "$dst" ]] && ! is_owned "$rel" && ! cmp -s "$tmp" "$dst"; then
    if [[ "$FORCE" != "1" ]]; then
      echo "[warn] skip differing $LABEL/$rel (FORCE=1 to replace; backup kept)"
      rm -f "$tmp"
      return 0
    fi
    [[ -f "$dst.pre-kleos-bak" ]] || cp -f "$dst" "$dst.pre-kleos-bak"
  fi
  mkdir -p "$(dirname "$dst")"
  mv -f "$tmp" "$dst"
  printf '%s\n' "$rel" >>"$DEST/kleosrules-owned.txt.new"
  echo "[ok] $LABEL/$rel"
}

# copy_into SRC REL [x]: place a verbatim copy; x marks it executable.
copy_into() {
  local t
  t="$(stage)"
  cp -f "$1" "$t"
  [[ "${3:-}" == x ]] && chmod +x "$t"
  place "$2" "$t"
}

# SKILL.md plus the references/ and scripts/ the body points at.
install_skill_files() {
  local skill="$1" rel_root="$2" src f t
  src="$PACK/skills/$skill"
  t="$(stage)"; port_skill "$src/SKILL.md" >"$t"; place "$rel_root/SKILL.md" "$t"
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    t="$(stage)"
    case "$f" in
      *.md|*.txt) port_refs <"$f" >"$t" ;;
      *) cp -f "$f" "$t" ;;
    esac
    place "$rel_root/${f#"$src"/}" "$t"
  done < <(find "$src" -type f ! -name 'SKILL.md' | sort)
}

# install_gate REL HOST: the three gate scripts, their libs and policy, and
# the host's verdict as lib/verdict_HOST.sh, under $DEST/REL.
install_gate() {
  local rel="$1" host="$2" f
  while IFS= read -r f; do copy_into "$PACK/hooks/$f" "$rel/$f" x; done < <(manifest_list '.hookEvents[]')
  while IFS= read -r f; do copy_into "$PACK/hooks/lib/$f" "$rel/lib/$f"; done < <(manifest_list '.runtimeLibs[]')
  while IFS= read -r f; do copy_into "$PACK/hooks/policy/$f" "$rel/policy/$f"; done < <(manifest_list '.policy[]')
  copy_into "$HOSTS_DIR/$host/verdict.sh" "$rel/lib/verdict_$host.sh"
}

begin_install() {
  command -v jq >/dev/null 2>&1 || { echo "[fail] jq is required" >&2; exit 1; }
  mkdir -p "$DEST"
  : >"$DEST/kleosrules-owned.txt.new"
}

rm_owned() {
  rm -f "$DEST/$1"
  rmdir "$(dirname "$DEST/$1")" "$(dirname "$(dirname "$DEST/$1")")" 2>/dev/null || true
  echo "[rm] $LABEL/$1"
}

# Removes files an earlier install owned that this one no longer writes.
finish_install() {
  local owned="$DEST/kleosrules-owned.txt" rel
  if [[ -f "$owned" ]]; then
    while IFS= read -r rel; do
      [[ -n "$rel" ]] || continue
      grep -qxF "$rel" "$owned.new" || rm_owned "$rel"
    done <"$owned"
  fi
  mv -f "$owned.new" "$owned"
}

uninstall_owned() {
  local owned="$DEST/kleosrules-owned.txt" rel
  [[ -f "$owned" ]] || { echo "[ok] nothing installed"; return 0; }
  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    if [[ -f "$DEST/$rel.pre-kleos-bak" ]]; then
      mv -f "$DEST/$rel.pre-kleos-bak" "$DEST/$rel"
      echo "[restore] $LABEL/$rel"
    else
      rm_owned "$rel"
    fi
  done <"$owned"
  rm -f "$owned"
}
