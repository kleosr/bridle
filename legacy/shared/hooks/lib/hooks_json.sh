#!/usr/bin/env bash

hooks_json_jq() {
  printf '%s\n' "${HOOKS_JSON_JQ:-$HOOKS_DIR/lib/hooks_json.jq}"
}

manifest_json() {
  printf '%s\n' "${MANIFEST_JSON:-$PACK/shared/config/manifest.json}"
}

merge_hooks_json() {
  local dest="$1" incoming="$2" tmp jqfile
  jqfile="$(hooks_json_jq)"
  if [[ ! -f "$incoming" ]]; then
    echo "[fail] pack hooks.json missing: $incoming" >&2
    return 1
  fi
  if [[ ! -f "$dest" ]]; then
    cp -f "$incoming" "$dest"
    return 0
  fi
  if ! jq empty "$dest" >/dev/null 2>&1; then
    echo "[fail] $dest is not JSON; refuse to overwrite" >&2
    return 1
  fi
  tmp="$(mktemp "${TMPDIR:-/tmp}/kleos-hooks.XXXXXX")"
  if ! jq --arg mode merge --slurpfile dest "$dest" -f "$jqfile" "$incoming" >"$tmp"; then
    rm -f "$tmp"
    echo "[fail] hooks.json merge failed" >&2
    return 1
  fi
  mv "$tmp" "$dest"
}

strip_owned_hooks_json() {
  local dest="$1" tmp empty extra jqfile
  jqfile="$(hooks_json_jq)"
  [[ -f "$dest" ]] || return 0
  if ! jq empty "$dest" >/dev/null 2>&1; then
    echo "[fail] $dest is not JSON; refuse to strip" >&2
    return 1
  fi
  tmp="$(mktemp "${TMPDIR:-/tmp}/kleos-hooks.XXXXXX")"
  if ! jq --arg mode strip --slurpfile dest "$dest" -f "$jqfile" "$dest" >"$tmp"; then
    rm -f "$tmp"
    echo "[fail] hooks.json strip failed" >&2
    return 1
  fi
  empty="$(jq -r '(.hooks == {} or .hooks == null)' "$tmp")"
  extra="$(jq -r '[keys[] | select(. != "version" and . != "hooks")] | length' "$tmp")"
  if [[ "$empty" == true && "$extra" == 0 ]]; then
    rm -f "$dest" "$tmp"
    echo "[rm] kleosrules hook entries (hooks.json had no remaining events)"
  else
    mv "$tmp" "$dest"
    echo "[ok] removed kleosrules hook entries; preserved other hooks.json data"
  fi
}

remove_owned_hook_files() {
  local dest="${1:-$HOME_C/hooks}" s man
  man="$(manifest_json)"
  [[ -d "$dest" ]] || return 0
  while IFS= read -r s; do
    s="${s%$'\r'}"
    [[ -z "$s" ]] && continue
    rm -f "$dest/$s"
  done < <(jq -r '.hookScripts[]' "$man")
  while IFS= read -r s; do
    s="${s%$'\r'}"
    [[ -z "$s" ]] && continue
    rm -f "$dest/lib/$s"
  done < <(jq -r '.hookLibs[]' "$man")
  while IFS= read -r s; do
    s="${s%$'\r'}"
    [[ -z "$s" ]] && continue
    rm -f "$dest/policy/$s"
  done < <(jq -r '.hookPolicy[]' "$man")
  if [[ ! -f "$HOME_C/hooks.json" ]] || ! grep -qE 'bash-shim\.ps1|wsl-shim\.ps1' "$HOME_C/hooks.json" 2>/dev/null; then
    while IFS= read -r s; do
      s="${s%$'\r'}"
      [[ -z "$s" ]] && continue
      rm -f "$dest/$s"
    done < <(jq -r '.windowsShims[]' "$man")
  fi
  rmdir "$dest/lib" "$dest/policy" "$dest" 2>/dev/null || true
}
