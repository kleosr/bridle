def owned:
  (.command | type == "string")
  and (.command | test("session_start\\.sh|before_submit_prompt\\.sh|before_shell\\.sh|before_read_file\\.sh|stop\\.sh"));

def strip_hooks:
  .hooks |= (
    ((. // {})
    | to_entries
    | map(
        .value |= map(select(owned | not))
        | select(.value | length > 0)
      )
    | from_entries)
  );

if $mode == "strip" then
  strip_hooks
else
  ($dest[0] // {version: 1, hooks: {}}) as $raw
  | . as $incoming
  | ($raw | strip_hooks) as $base
  | $base
  | .version = ($incoming.version // $base.version // 1)
  | .hooks = (
      ($base.hooks // {}) as $keep
      | ($incoming.hooks // {}) as $add
      | reduce ($add | keys[]) as $k (
          $keep;
          .[$k] = (($keep[$k] // []) + $add[$k])
        )
    )
end
