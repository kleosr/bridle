# Isolated unit tests for lib/sql_scope.sh. No live install, no fixtures dir needed.
set -u
cd "$(dirname "$0")/.." || exit 1
. shared/hooks/lib/sql_scope.sh

pass=0; fail=0
check() { # check DESCRIPTION SEGMENT EXPECTED(0=match 1=no-match)
  local desc="$1" seg="$2" want="$3" got
  if sql_destructive_segment "$seg"; then got=0; else got=1; fi
  if [ "$got" = "$want" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1)); printf 'FAIL: %s (want %s, got %s)\n' "$desc" "$want" "$got"
  fi
}

check "grep on a dump is not destructive"      'grep drop dump.sql'                          1
check "cat of truncate notes is not destructive" 'cat truncate_notes.txt'                   1
check "rm -rf is gated elsewhere, not here"    'rm -rf /tmp/x'                               1
check "psql drop table denies"                 'psql -c "DROP TABLE users"'                  0
check "mysql truncate denies"                  'mysql -e "TRUNCATE TABLE sessions"'          0
check "sudo-wrapped psql drop database denies" 'sudo -u postgres psql -c "drop database prod"' 0
check "select with drop-ish column allows"     'sqlite3 app.db "select dropped_count from t"' 1

if [ "$fail" -eq 0 ]; then printf 'sql_scope: %s checks passed\n' "$pass"; else exit 1; fi
