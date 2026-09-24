// bridle adapter for opencode: runs the pack's Bash hooks on opencode's plugin
// events. The hooks own the policy; this file only maps payloads and verdicts.
//   beforeSubmitPrompt   -> chat.message        (fail closed)
//   beforeShellExecution -> tool.execute.before bash (fail closed)
//   beforeReadFile       -> tool.execute.before read (fail closed)
//   stop                 -> event session.idle   (advisory, one follow-up)
import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const HOOKS = process.env.BRIDLE_HOOKS_DIR || join(dirname(fileURLToPath(import.meta.url)), "..", "bridle", "hooks");
const TIMEOUT_MS = { "before_submit_prompt.sh": 30000, "before_shell.sh": 60000, "before_read_file.sh": 30000, "stop.sh": 30000 };

// Windows `bash` on PATH is often WSL's System32 shim, which cannot see the
// hooks' Windows paths. Git Bash is the supported runtime (README: Install).
function resolveBash() {
  if (process.env.BRIDLE_BASH) return process.env.BRIDLE_BASH;
  if (process.platform !== "win32") return "bash";
  const candidates = [
    join(process.env.ProgramFiles || "C:\\Program Files", "Git", "bin", "bash.exe"),
    join(process.env.LOCALAPPDATA || "", "Programs", "Git", "bin", "bash.exe"),
  ];
  return candidates.find((p) => existsSync(p)) || null;
}

const BASH = resolveBash();

// The hooks run under Git Bash, which reads drive paths as /c/...
function unixPath(p) {
  if (typeof p !== "string") return p;
  const m = /^([A-Za-z]):[\\/](.*)$/.exec(p);
  return m ? `/${m[1].toLowerCase()}/${m[2].replace(/\\/g, "/")}` : p;
}

// Resolves to the hook's JSON verdict, or null when the hook crashed, timed
// out, or printed something that is not JSON. Callers fail closed on null.
function runHook(script, payload) {
  return new Promise((resolve) => {
    if (!BASH) return resolve(null);
    let out = "";
    let child;
    try {
      child = spawn(BASH, ["--noprofile", "--norc", join(HOOKS, script)], {
        stdio: ["pipe", "pipe", "ignore"],
        windowsHide: true,
      });
    } catch {
      return resolve(null);
    }
    const timer = setTimeout(() => child.kill(), TIMEOUT_MS[script]);
    child.stdout.on("data", (d) => (out += d));
    child.on("error", () => { clearTimeout(timer); resolve(null); });
    child.on("close", (code) => {
      clearTimeout(timer);
      if (code !== 0) return resolve(null);
      try { resolve(JSON.parse(out)); } catch { resolve(null); }
    });
    child.stdin.on("error", () => {});
    child.stdin.end(JSON.stringify(payload));
  });
}

function blocked(event, v) {
  const reason = v?.reason || (v ? "deny" : "hook-failed");
  const msg = v?.user_message || `bridle: ${event} hook failed or returned no verdict (failClosed).`;
  return new Error(`[bridle ${reason}] ${msg}`);
}

// opencode has no host "ask" dialog for a plugin verdict, so ask blocks and
// hands the decision to the person, who can run the command with `!`.
async function gateTool(tool, args, directory) {
  if (tool === "bash") {
    const v = await runHook("before_shell.sh", { command: args?.command ?? "", cwd: unixPath(args?.workdir || directory) });
    if (v?.permission === "allow") return;
    // The hook's ask text names Cursor's approval card, so it is not relayed.
    if (v?.permission === "ask") {
      throw new Error(`[bridle ${v.reason || "ask"}] Command needs the user's approval. Ask them to approve the concrete action, target, and scope; they can run it themselves with \`!\`. Command not echoed to avoid secret leakage.`);
    }
    throw blocked("beforeShellExecution", v);
  }
  if (tool === "read") {
    const v = await runHook("before_read_file.sh", { file_path: unixPath(args?.filePath ?? "") });
    if (v?.permission !== "allow") throw blocked("beforeReadFile", v);
  }
}

function promptText(parts) {
  return (parts || []).filter((p) => p.type === "text" && !p.synthetic).map((p) => p.text).join("\n");
}

export const BridlePlugin = async ({ client, directory, worktree }) => {
  const followedUp = new Set();

  return {
    "chat.message": async (_input, output) => {
      const text = promptText(output.parts);
      if (!text) return;
      const v = await runHook("before_submit_prompt.sh", { prompt: text });
      if (v?.continue === true) return;
      // Redact before refusing so the text never reaches the model even if
      // the host keeps the message after the hook throws.
      for (const p of output.parts) if (p.type === "text") p.text = "[bridle: prompt withheld]";
      const err = blocked("beforeSubmitPrompt", v);
      // The host reports a thrown chat.message as a generic server error; the
      // toast is how the person sees why (TUI only, best effort).
      await client.tui?.showToast({ body: { title: "bridle", message: err.message, variant: "error" } }).catch(() => {});
      throw err;
    },

    "tool.execute.before": async (input, output) => {
      await gateTool(input.tool, output.args, directory);
    },

    event: async ({ event }) => {
      if (event.type !== "session.idle") return;
      const id = event.properties?.sessionID;
      if (!id) return;
      const loop = followedUp.delete(id) ? 1 : 0;
      try {
        const session = await client.session.get({ path: { id } });
        if (session.data?.parentID) return;
        const v = await runHook("stop.sh", { status: "completed", loop_count: loop, workspace_roots: [unixPath(worktree || directory)] });
        if (!v?.followup_message) return;
        followedUp.add(id);
        await client.session.promptAsync({ path: { id }, body: { parts: [{ type: "text", text: v.followup_message }] } });
      } catch {
        // stop is advisory: a failed advisory never blocks the session.
      }
    },
  };
};
