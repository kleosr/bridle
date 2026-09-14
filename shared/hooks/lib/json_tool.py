#!/usr/bin/env python3
"""Hook JSON codec. CPython stdlib only. Invoked by lib/json.sh."""
import json
import os
import sys


def walk(data, path):
    cur = data
    for part in path.split("."):
        if cur is None:
            return None
        if isinstance(cur, list) and part.isdigit():
            i = int(part)
            if i < 0 or i >= len(cur):
                return None
            cur = cur[i]
        elif isinstance(cur, dict):
            cur = cur.get(part)
        else:
            return None
    return cur


def first(data, paths):
    for path in paths:
        value = walk(data, path)
        if value is not None:
            return value
    return None


def jtype(value):
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "boolean"
    if isinstance(value, (int, float)):
        return "number"
    if isinstance(value, str):
        return "string"
    if isinstance(value, list):
        return "array"
    if isinstance(value, dict):
        return "object"
    return "string"


def as_text(value):
    if value is None:
        return ""
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, str):
        return value
    if isinstance(value, (int, float)):
        return json.dumps(value)
    return json.dumps(value, ensure_ascii=False)


def posix_sq(value):
    text = as_text(value)
    return "'" + text.replace("'", "'\\''") + "'"


def load_stdin():
    raw = sys.stdin.read()
    if raw.startswith("\ufeff"):
        raw = raw[1:]
    raw = raw.replace("\r\n", "\n").replace("\r", "")
    if not raw.strip():
        raise ValueError("empty")
    return json.loads(raw)


def emit_obj(obj):
    sys.stdout.write(json.dumps(obj, separators=(",", ":"), ensure_ascii=False))
    sys.stdout.write("\n")


def env(name):
    return os.environ.get(name, "")


def cmd_emit(kind):
    msg = env("KLEOS_JSON_MSG")
    reason = env("KLEOS_JSON_REASON") or "deny"
    agent = env("KLEOS_JSON_AGENT")
    if kind == "allow":
        emit_obj({"permission": "allow", "agent_message": msg} if msg else {"permission": "allow"})
        return 0
    if kind == "deny":
        obj = {"permission": "deny", "user_message": msg, "reason": reason}
        if agent:
            obj["agent_message"] = agent
        emit_obj(obj)
        return 0
    if kind == "ask":
        obj = {"permission": "ask", "user_message": msg, "reason": reason}
        if agent:
            obj["agent_message"] = agent
        emit_obj(obj)
        return 0
    if kind == "continue":
        cont = env("KLEOS_JSON_CONTINUE") != "false"
        if not cont:
            obj = {"continue": False, "reason": reason or "block"}
            if msg:
                obj["user_message"] = msg
            emit_obj(obj)
            return 0
        emit_obj({"continue": True, "user_message": msg} if msg else {"continue": True})
        return 0
    if kind == "followup":
        emit_obj({"followup_message": msg})
        return 0
    if kind == "claude":
        perm = env("KLEOS_JSON_PERM") or "deny"
        emit_obj(
            {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": perm,
                    "permissionDecisionReason": msg,
                },
                "reason": reason,
            }
        )
        return 0
    return 1


def cmd_decode_submit():
    data = load_stdin()
    prompt = first(data, ("prompt", "user_prompt", "message", "text"))
    sys.stdout.write("PROMPT=%s\n" % posix_sq(prompt if isinstance(prompt, str) else as_text(prompt)))
    return 0


def cmd_decode_shell():
    data = load_stdin()
    cmd = first(data, ("command", "tool_input.command", "tool_input.cmd"))
    cwd = first(data, ("cwd", "tool_input.cwd", "workspace_roots.0"))
    sys.stdout.write("TYPE=%s\n" % posix_sq(jtype(cmd)))
    sys.stdout.write("CMD=%s\n" % posix_sq(cmd if isinstance(cmd, str) else as_text(cmd) if cmd is not None else ""))
    sys.stdout.write("CWD=%s\n" % posix_sq(cwd if isinstance(cwd, str) else as_text(cwd)))
    return 0


def cmd_decode_read():
    data = load_stdin()
    path = first(data, ("file_path", "tool_input.file_path", "tool_input.path"))
    sys.stdout.write("FILE_PATH=%s\n" % posix_sq(path if isinstance(path, str) else as_text(path)))
    return 0


def cmd_decode_stop():
    data = load_stdin()
    status = data.get("status")
    loop = data.get("loop_count", 0)
    wr = first(data, ("workspace_roots.0", "cwd"))
    sys.stdout.write("STATUS=%s\n" % posix_sq(status if isinstance(status, str) else as_text(status)))
    sys.stdout.write("LOOP=%s\n" % posix_sq(loop if isinstance(loop, str) else as_text(loop)))
    sys.stdout.write("WR=%s\n" % posix_sq(wr if isinstance(wr, str) else as_text(wr)))
    return 0


def cmd_file_valid(path):
    with open(path, "r") as handle:
        json.load(handle)
    return 0


def cmd_has_scripts_test(path):
    with open(path, "r") as handle:
        data = json.load(handle)
    scripts = data.get("scripts") if isinstance(data, dict) else None
    if isinstance(scripts, dict) and scripts.get("test"):
        return 0
    return 1


def cmd_features_advise(path):
    with open(path, "r") as handle:
        data = json.load(handle)
    features = data.get("features") if isinstance(data, dict) else None
    if not isinstance(features, list):
        sys.stdout.write(
            "FEATURE (advisory): feature list is not valid JSON (%s).\n"
            "Fix the file or restore it before claiming done.\n" % path
        )
        return 0
    active = [
        item
        for item in features
        if isinstance(item, dict)
        and (item.get("status") or item.get("state")) in ("in_progress", "active")
    ]
    if len(active) > 1:
        sys.stdout.write(
            "FEATURE (advisory): %s features are in_progress (limit 1). "
            "Finish or block extras before claiming done.\n" % len(active)
        )
    ids = []
    for item in features:
        if not isinstance(item, dict):
            continue
        status = item.get("status") or item.get("state")
        if status not in ("passing", "pass"):
            continue
        evidence = item.get("evidence")
        empty_obj = (
            isinstance(evidence, dict)
            and not evidence.get("proves")
            and not evidence.get("command")
        )
        if evidence is None or evidence == "" or empty_obj:
            ids.append(item.get("id") or "unknown")
    if ids:
        sys.stdout.write(
            "FEATURE (advisory): passing without evidence: %s.\n"
            "Run `bash scripts/feature.sh pass <id>` (or the listed verification) "
            "before claiming done. Editing JSON to passing is not done.\n" % " ".join(ids)
        )
    return 0


def main(argv):
    if len(argv) < 2:
        return 1
    cmd = argv[1]
    try:
        if cmd == "ping":
            sys.stdout.write("ok\n")
            return 0
        if cmd == "valid":
            load_stdin()
            return 0
        if cmd == "emit":
            if len(argv) < 3:
                return 1
            return cmd_emit(argv[2])
        if cmd == "decode-submit":
            return cmd_decode_submit()
        if cmd == "decode-shell":
            return cmd_decode_shell()
        if cmd == "decode-read":
            return cmd_decode_read()
        if cmd == "decode-stop":
            return cmd_decode_stop()
        if cmd == "file-valid":
            return cmd_file_valid(argv[2])
        if cmd == "has-scripts-test":
            return cmd_has_scripts_test(argv[2])
        if cmd == "features-advise":
            return cmd_features_advise(argv[2])
        return 1
    except (ValueError, TypeError, json.JSONDecodeError, OSError, IndexError):
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
