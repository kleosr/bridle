def lines: (. // "") | rtrimstr("\n") | split("\n");
def bag: reduce .[] as $l ({}; .[$l] += 1);
def gap: if . < 0 then -. else . end;
def churn($o; $n): ($o | bag) as $a | ($n | bag) as $b
  | reduce (([$a, $b] | map(keys) | add | unique)[]) as $k (0; . + ((($a[$k] // 0) - ($b[$k] // 0)) | gap));
def size($t): if $t.name == "Edit" then churn($t.input.old_string | lines; $t.input.new_string | lines)
  elif $t.name == "Write" then ($t.input.content | lines | length)
  else ($t.input.new_source | lines | length) end;
def entry($t): {path: ($t.input.file_path // $t.input.notebook_path), write: ($t.name == "Write"), lines: size($t)};
def lead: if type == "string" then . else ([.[]? | select(.type == "text") | .text][0] // "") end;
def human: .type == "user" and (.isSidechain | not) and (.isMeta | not)
  and (.message.content | (type == "string" or all(.[]?; .type != "tool_result"))
    and (lead | (startswith("<") | not) or startswith("<command-")));
def doc: test("\\.(md|mdx|txt|rst)$");
def inert: test("(^|/)(tests?|__tests__|spec|node_modules|dist|build|generated|migrations)/|\\.(test|spec)\\.[a-z]+$|(^|/)test_[^/]*\\.py$|_test\\.(go|py)$|\\.lock$|(package-lock\\.json|pnpm-lock\\.yaml)$");
reduce inputs as $r ({edits: {}, verify: null, skills: []};
  if ($r | human) then {edits: {}, verify: null, skills: []}
  elif $r.isSidechain == true then .
  elif $r.type == "assistant" then
    reduce ($r.message.content[]? | select(.type == "tool_use")) as $t (.;
      if ($t.name | IN("Edit", "Write", "NotebookEdit")) then .edits[$t.id] = entry($t) | .verify = null
      elif $t.name == "Skill" then .skills += [($t.input.skill // "") | sub("^.*:"; "")]
      elif $t.name == "Bash" and (($t.input.command // "") | test($v)) then .verify = {id: $t.id, ok: null}
      else . end)
  elif $r.type == "user" then
    reduce ($r.message.content[]? | select(type == "object" and .type == "tool_result")) as $x (.;
      (if $x.is_error == true then del(.edits[$x.tool_use_id]) else . end)
      | (if .verify.id == $x.tool_use_id then .verify.ok = ($x.is_error != true) else . end))
  else . end)
| if $pending == null then . else .edits[$pending.id // "pending"] = entry($pending) end
| . as $s
| [$s.edits[] | select((.path | type) == "string" and (.path | startswith($cwd + "/"))) | .path |= .[($cwd | length + 1):]] as $e
| {files: ($e | map(.path) | unique),
   writes: ($e | map(select(.write and (.path | (doc or inert) | not)) | .path) | unique),
   prod: ($e | map(select(.path | (doc or inert) | not) | .lines) | add // 0),
   docsOnly: ($e | all(.path | doc)),
   verify: $s.verify,
   skills: ($s.skills | unique)}
