# Program-scoped destructive-SQL matching. Replaces bare substring
# matching of drop/truncate against whole command segments.
# Interface: sql_destructive_segment SEGMENT -> exit 0 = match (deny), 1 = no match.
# Sourced by beforeShellExecution.sh. Unit-tested by tests/sql_scope_test.sh.

# rxi normally comes from common.sh; the unit test sources this file alone.
if ! declare -F rxi >/dev/null 2>&1; then
  rxi() {
    local rc=1
    shopt -s nocasematch
    if [[ $1 =~ $2 ]]; then rc=0; fi
    shopt -u nocasematch
    return "$rc"
  }
fi

_sql_client_in_segment() {
  # true if any whitespace token of the segment is a SQL client binary.
  # Scanning all tokens (not just the first) keeps sudo/env wrappers covered.
  local -a toks
  local tok base
  read -r -a toks <<<"$1"
  for tok in "${toks[@]}"; do
    base="${tok##*/}"
    case "$base" in
      psql|mysql|mariadb|sqlite3|sqlcmd|duckdb) return 0 ;;
    esac
  done
  return 1
}

sql_destructive_segment() {
  # Deny only SQL-destructive syntax inside an actual SQL invocation.
  # Keyword must be followed by an object class, so identifiers like
  # dropped_count or truncate_log do not match.
  _sql_client_in_segment "$1" || return 1
  rxi "$1" '(^|[^a-z_])(drop|truncate)[[:space:]]+(table|database|schema|index)|delete[[:space:]]+from'
}
