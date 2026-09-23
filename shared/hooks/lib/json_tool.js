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
  if (kind === "followup") {
    emitObj({ followup_message: msg });
    return 0;
  }
  return 1;
}

// tree: the workspace tree now (see feature_gate.sh ledger_tree); dirty: "1"
// when the working tree has uncommitted changes outside the ledger.
function featuresAdvise(path, tree, dirty) {
  const data = JSON.parse(fs.readFileSync(path, "utf8"));
  const features = data && data.features;
  if (!Array.isArray(features)) {
    process.stdout.write(
      "FEATURE (advisory): feature list is not valid JSON (" +
        path +
        ").\nFix the file or restore it before claiming done.\n"
    );
    return 0;
  }
  const active = features.filter(
    (item) =>
      item &&
      typeof item === "object" &&
      ["in_progress", "active"].indexOf(item.status || item.state) !== -1
  );
  if (active.length > 1) {
    process.stdout.write(
      "FEATURE (advisory): " +
        active.length +
        " features are in_progress (limit 1). Finish or block extras before claiming done.\n"
    );
  }
  const ids = [];
  for (const item of features) {
    if (!item || typeof item !== "object") continue;
    const status = item.status || item.state;
    if (status !== "passing" && status !== "pass") continue;
    const evidence = item.evidence;
    const emptyObj =
      evidence &&
      typeof evidence === "object" &&
      !evidence.proves &&
      !evidence.command;
    if (evidence == null || evidence === "" || emptyObj) ids.push(item.id || "unknown");
  }
  if (ids.length) {
    process.stdout.write(
      "FEATURE (advisory): passing without evidence: " +
        ids.join(" ") +
        ".\nRun `bash scripts/feature.sh pass <id>` (or the listed verification) before claiming done. Editing JSON to passing is not done.\n"
    );
  }
  if (tree) {
    const stale = [];
    for (const item of features) {
      if (!item || typeof item !== "object") continue;
      const status = item.status || item.state;
      if (status !== "passing" && status !== "pass") continue;
      const evidence = item.evidence;
      if (!evidence || typeof evidence !== "object" || (!evidence.proves && !evidence.command)) continue;
      // Missing tree predates the check. feature.sh check accepts those rows;
      // only a recorded tree that no longer matches is stale.
      if (!Object.prototype.hasOwnProperty.call(evidence, "tree") || evidence.tree === tree) continue;
      stale.push(item.id || "unknown");
    }
    if (stale.length) {
      process.stdout.write(
        "FEATURE (advisory): passing with stale evidence (workspace changed since pass): " +
          stale.join(" ") +
          ".\nRe-run `bash scripts/feature.sh pass <id>` before claiming done.\n"
      );
    }
  }
  if (dirty === "1" && active.length) {
    process.stdout.write(
      "FEATURE (advisory): " +
        active.map((item) => item.id || "unknown").join(" ") +
        " is in_progress and the working tree has uncommitted changes.\nRun `bash scripts/feature.sh pass <id>`, or commit and write the handoff, before claiming done.\n"
    );
  }
  return 0;
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
  if (cmd === "decode-stop") {
    const data = loadStdin();
    const wr = first(data, ["workspace_roots.0", "cwd"]);
    process.stdout.write("STATUS=" + posixSq(typeof data.status === "string" ? data.status : asText(data.status)) + "\n");
    const loop = data.loop_count === undefined ? 0 : data.loop_count;
    process.stdout.write("LOOP=" + posixSq(typeof loop === "string" ? loop : asText(loop)) + "\n");
    process.stdout.write("WR=" + posixSq(typeof wr === "string" ? wr : asText(wr)) + "\n");
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
  if (cmd === "features-advise") return featuresAdvise(argv[3], argv[4] || "", argv[5] || "");
  return 1;
}

try {
  process.exit(main(process.argv));
} catch (err) {
  process.exit(2);
}
