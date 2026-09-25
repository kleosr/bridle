#!/usr/bin/env node
"use strict";

const fs = require("fs");

function walk(data, path) {
  let cur = data;
  for (const part of String(path).split(".")) {
    if (cur == null) return undefined;
    if (Array.isArray(cur) && /^\d+$/.test(part)) {
      const i = Number(part);
      cur = i >= 0 && i < cur.length ? cur[i] : undefined;
    } else if (typeof cur === "object") {
      cur = cur[part];
    } else {
      return undefined;
    }
  }
  return cur;
}

function first(data, paths) {
  for (const path of paths) {
    const value = walk(data, path);
    if (value !== undefined && value !== null) return value;
  }
  return undefined;
}

function jtype(value) {
  if (value === null || value === undefined) return "null";
  if (typeof value === "boolean") return "boolean";
  if (typeof value === "number") return "number";
  if (typeof value === "string") return "string";
  if (Array.isArray(value)) return "array";
  if (typeof value === "object") return "object";
  return "string";
}

function asText(value) {
  if (value === undefined || value === null) return "";
  if (typeof value === "boolean") return value ? "true" : "false";
  if (typeof value === "string") return value;
  return JSON.stringify(value);
}

function posixSq(value) {
  return "'" + asText(value).replace(/'/g, "'\\''") + "'";
}

function loadStdin() {
  let raw = fs.readFileSync(0, "utf8");
  if (raw.charCodeAt(0) === 0xfeff) raw = raw.slice(1);
  raw = raw.replace(/\r\n/g, "\n").replace(/\r/g, "");
  if (!raw.trim()) throw new Error("empty");
  return JSON.parse(raw);
}

function emitObj(obj) {
  process.stdout.write(JSON.stringify(obj) + "\n");
}

function env(name) {
  return process.env[name] || "";
}

function cmdEmit(kind) {
  const msg = env("KLEOS_JSON_MSG");
  const reason = env("KLEOS_JSON_REASON") || "deny";
  const agent = env("KLEOS_JSON_AGENT");
  if (kind === "allow") {
    emitObj(msg ? { permission: "allow", agent_message: msg } : { permission: "allow" });
    return 0;
  }
  if (kind === "deny" || kind === "ask") {
    const obj = { permission: kind, user_message: msg, reason };
    if (agent) obj.agent_message = agent;
    emitObj(obj);
    return 0;
  }
  if (kind === "continue") {
    const cont = env("KLEOS_JSON_CONTINUE") !== "false";
    if (!cont) {
      const obj = { continue: false, reason: reason || "block" };
      if (msg) obj.user_message = msg;
      emitObj(obj);
      return 0;
    }
    emitObj(msg ? { continue: true, user_message: msg } : { continue: true });
    return 0;
  }
  return 1;
}

function main(argv) {
  const cmd = argv[2];
  if (!cmd) return 1;
  if (cmd === "ping") {
    process.stdout.write("ok\n");
    return 0;
  }
  if (cmd === "valid") {
    loadStdin();
    return 0;
  }
  if (cmd === "emit") return cmdEmit(argv[3]);
  if (cmd === "decode-submit") {
    const data = loadStdin();
    const prompt = first(data, ["prompt", "user_prompt", "message", "text"]);
    process.stdout.write("PROMPT=" + posixSq(typeof prompt === "string" ? prompt : asText(prompt)) + "\n");
    return 0;
  }
  if (cmd === "decode-shell") {
    const data = loadStdin();
    const c = first(data, ["command", "tool_input.command", "tool_input.cmd"]);
    const cwd = first(data, ["cwd", "tool_input.cwd", "workspace_roots.0"]);
    process.stdout.write("TYPE=" + posixSq(jtype(c === undefined ? null : c)) + "\n");
    process.stdout.write(
      "CMD=" + posixSq(typeof c === "string" ? c : c == null ? "" : asText(c)) + "\n"
    );
    process.stdout.write("CWD=" + posixSq(typeof cwd === "string" ? cwd : asText(cwd)) + "\n");
    return 0;
  }
  if (cmd === "decode-read") {
    const data = loadStdin();
    const p = first(data, ["file_path", "path", "tool_input.file_path", "tool_input.path"]);
    process.stdout.write("FILE_PATH=" + posixSq(typeof p === "string" ? p : asText(p)) + "\n");
    return 0;
  }
  if (cmd === "file-valid") {
    JSON.parse(fs.readFileSync(argv[3], "utf8"));
    return 0;
  }
  if (cmd === "has-scripts-test") {
    const data = JSON.parse(fs.readFileSync(argv[3], "utf8"));
    return data && data.scripts && data.scripts.test ? 0 : 1;
  }
  return 1;
}

try {
  process.exit(main(process.argv));
} catch (err) {
  process.exit(2);
}
