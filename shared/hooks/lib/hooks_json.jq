def hook_basename:
  (.command // "" | split("/") | last | split("\\") | last);

def owned_names:
  ["session_start.sh", "before_submit_prompt.sh", "before_shell.sh",
   "before_read_file.sh", "stop.sh"];

def shim_owned:
  (.command // "")
  | test("bash-shim\\.ps1[[:space:]]+[^[:space:]]*(before_submit_prompt|before_shell|before_read_file|stop)\\.sh([[:space:]]|$)");

def owned:
  ((.command // "") | type) == "string"
  and ((hook_basename | IN(owned_names[])) or shim_owned);

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
