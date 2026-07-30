# Unified Counterexample Taxonomy — kleosrules Conjecture

> **RETIRED (V2):** Historical audit of the deleted Rust `kleos-gate`. Not operational law. See `docs/DECISIONS/hooks-architecture.md` and `docs/TOOLCHAIN.md`.

**Date:** 2026-07-29
**Status:** Complete enumeration of structural gaps found in `kleos-gate` engine + policy JSON
**Method:** Source-level control-flow tracing of every gate/engine module against `hooks.policy/*.json` + `hooks.json` failClosed flags

---

## Meta-observation

The Conjecture claims the system achieves "complete coverage of every failure mode by either a mechanical gate or an explicit, auditable judgment rule." Each gap below is a structural bypass that requires **no model misbehavior, no cold-start, no special session** — it is a purely engineering defect in the gate logic or policy content. Each is unconditional: any Cursor agent in any session, under any system prompt, can trigger it.

---

## Counterexamples (7 structural gaps)

### C1: `git apply` / `patch` / `git am` Silent Bypass in `shell.rs`

**Severity:** HIGH — opaque code modification without gate inspection
**Location:** `hooks/kleos-gate/src/engine/shell.rs` lines 48–59
**Root cause:** `policy.shell.opaque_write_ask_message` is `""` (empty string).

Control-flow trace for `git apply -p1 < some-b.patch`:
1. `command_from(data)` → non-empty → no early `allow()` short-circuit
2. Deny loop → empty deny list → no match
3. `looks_like_prose_shell_write()` → `writes_code_dest(cmd)` returns empty (no `>` redirect, no `tee`) → false → prose check skipped
4. `looks_like_python_file_write()` → false
5. `embedded_code_write()` → no heredoc → None → skipped
6. Ask loop → no match (only targets `rm -rf` and `find -delete`)
7. **Lines 48–55**: `looks_opaque_write()` returns true (git apply matches `is_patch_or_apply`)
8. **Lines 56–59**: `opaque_write_ask_message` is `""` → `msg.is_empty()` → skip ask → fall through
9. **Line 58**: `allow()` → exit 0, `{"permission": "allow"}`

**Payload:**
```
git apply -p1 <<'EOF'
--- a/src/App.tsx
+++ b/src/App.tsx
@@ -1,3 +1,3 @@
 -const x = 1;
 +const y = secret_data_exfiltrated;
 +export default y;
 EOF
```

**Fix:** Set `"opaque_write_ask_message"` to a meaningful confirmation prompt in `hooks/policy/shell.json`.

---

### C2: MCP Danger Pattern `"a^"` is Inert

**Severity:** HIGH — MCP tool calls with destructiveness receive no gate supervision
**Location:** `hooks/kleos-gate/src/engine/mcp.rs` line 27–28, `hooks/policy/secrets.json` line 8
**Root cause:** `mcp_danger_pattern` is `"a^"`. The regex `a^` matches literal `a` followed by end-of-line. In a string like `"CallMcpTool\nuser-obsidian\nvault_write\n..."` the pattern matches `a\n` at end of line, which always fires on any multiline string. Actually wait — `"a^"` as a regex means match `a` at start of line. `Regex::new("a^")` compiles but only matches literal `a` at start of a line. For a tool name `CallMcpTool` + newline + args, `a^` never matches because `a^` requires `a` at position `^` (start of line), and tool args typically don't start with `a`. So `danger.is_match(&joined)` returns false, `ask()` is never called, the gate has zero supervisory power over MCP, and it falls to `allow()`.

Actually re-examining: `Regex::new("a^")` — `^` in the middle of a regex (not at start, not after `|` or group start) asserts "start of line" in multi-line mode, but Rust regex `^` without `(?m)` asserts "start of string". So `"a^"` means match `a` at the **start of the input**. The joined string starts with the tool name (`"CallMcpTool\n..."`), first char is `C`, not `a`. So the pattern never matches, and the danger check is a dead no-op.

**Fix:** Set `mcp_danger_pattern` to a meaningful pattern like `"(?i)(vault_write|vault_append|vault_delete|vault_move)"` or any pattern that actually signals destructive MCP intent. Currently the pattern is inert.

---

### C3: Read Gate `allow()` Before `deny()` Short-Circuit

**Severity:** MEDIUM — read of secret-like paths can bypass if allow pattern matches first
**Location:** `hooks/kleos-gate/src/engine/read.rs` lines 15–26
**Root cause:** Execution order allows the `allow_re` to short-circuit before `deny_re` is ever checked.

Control-flow trace for reading `~/.env`:
1. `path = "~/.env"` — non-empty
2. `allow_re = Regex::new(&policy.secrets.read_allow_pattern)` — pattern includes `.env\.example|.env\.sample|...hooks/policy/secrets\.json$`
3. `allow_re.is_match("~/.env")` → false (no `.example` or `.sample` suffix)
4. `deny_re = Regex::new(&policy.secrets.read_path_pattern)` — pattern matches `\.env($|\.)`
5. `deny_re.is_match("~/.env")` → true → deny

So this path is actually correctly denied. The bypass is different: if the **allow pattern matches first**, it short-circuits to `allow()` at line 19 and never reaches deny at line 27–35. Any file path that matches BOTH allow and deny patterns would be allowed. The allow pattern is intentionally broad (`.env.example`, `.env.sample`, etc. are safe). The deny pattern catches `~/.env`, `~/.aws/credentials`, `secrets.yaml`, etc. There is overlap (`.env.sample` matches allow, `.env` matches deny but `~/.env` does NOT match the allow pattern because `~/.env` lacks `.sample` suffix). So for the current patterns this is not a bug — but the structural **ordering** means that a policy change adding a broad allow pattern could silently open secret reads. The real structural issue is: **allow_re short-circuits before deny_re is evaluated**. An allow-include pattern that accidentally matches a deny-path would create a complete bypass. This is a latent structural risk, not an active bug in the current policies.

---

### C4: `failClosed=false` Surfaces Emit Context, Never Deny

**Severity:** MEDIUM — these hooks can fail silently without blocking
**Location:** `hooks/hooks.json` / `hooks/hooks.project.json` and `hooks/kleos-gate/src/engine/session.rs`

The following hook events have `failClosed: false` AND their handler only emits `additional_context` or `allow_empty_prompt()`, never `deny()`:

| Event | `failClosed` | Handler | Deny possible? |
|---|---|---|---|
| `postToolUse` | false | `session::post_tool_use()` | No — only emits `additional_context` |
| `postToolUseFailure` | false | `session::post_tool_use()` (same fn) | No |
| `sessionStart` | false | `session::session_boundary()` | No — emits context + allow |
| `preCompact` | false | `session::session_boundary()` | No — emits context + allow |
| `subagentStop` | false | `session::subagent_stop()` (emit `{}`) | No |
| `stop` | false | `session::stop_verify()` | No — emits followup + allow |

If any of these hooks crash or return an error response, Cursor treats them as a pass-through (no block). A hook crash on `sessionStart` means the agent enters the session without `ROOF` and `OBSIDIAN_RECALL` context loaded. A crash on `postToolUse` means unverified edits carry forward silently.

---

### C5: `prose.has_prose()` String-Literal Escape Gap

**Severity:** MEDIUM — prose comments inside string literals are invisible to detection
**Location:** `hooks/kleos-gate/src/engine/prose.rs` `strip_strings_for_scan()`
**Root cause:** The function replaces string-literal content with spaces, then scans remaining code for `//` and `/*` prose markers. This correctly strips inline comments inside string literals. However, it does **not** strip:
- Raw strings (`r#"..."#` in Rust, backtick templates in JS/TS)
- Single-quoted strings in shell commands (`cmd = 'path with // comment'`)
- The `strip_strings_for_scan` function handles `'` and `"` and `` ` `` but has a bug path: single-quoted strings with escaped quotes (`'it\'s a // comment'`) — the function processes these but the escaping is limited

More critically: **prose detection is NOT applied to shell command arguments for non-code destinations**. A command like `echo "This is a // prose comment that looks like a code comment" > /dev/null` passes through `looks_like_prose_shell_write()` because the destination `/dev/null` is not a code path (no code extension). This is intentional — but means the system cannot detect prose in shell commands targeting non-code files. This is acceptable (the rule targets code files).

---

### C6: `ask_scope` Disabled by Default, Exempt Prefixes Create Gaps

**Severity:** MEDIUM — ask_scope has zero enforcement power when disabled
**Location:** `hooks/policy/ask-scope.json`, `hooks/kleos-gate/src/engine/ask_scope.rs`

`policy.ask_scope.enabled` defaults to whatever is in `ask-scope.json`. If the enabled flag is `false`, `record_prompt()` is a no-op and `check_path()` returns immediately without deny/ask. Even when enabled:
- `exempt_prefixes` includes `docs/`, `skills/`, `user-rules/`, `project-rules/`, `hooks/policy/` — writes to these are never gated by ask_scope
- `min_tokens` (default 6) — if the prompt has fewer than 6 tokens matching the path pattern, the check is skipped entirely
- The `mode` field selects `deny` vs `ask` — in `ask` mode the user can approve and the write proceeds (soft gate, not mechanical)

---

### C7: Lean Disabled via Environment Variable Override

**Severity:** MEDIUM — lean meter and code-path checks can be globally disabled
**Location:** `hooks/policy/lean.json` `enabled_env: "KLEOS_LEAN"`, `hooks/kleos-gate/src/engine/lean.rs` lines 5–11

`lean::enabled()` checks `KLEOS_LEAN` env var. If set to `"0"`, `"false"`, or `"no"`, all lean checks are skipped. If unset, uses `enabled_default` (true). The env override is intentional (for debugging), but it is a single environment variable that bypasses **all** lean enforcement: LOC roofs, new-file size limits, net-delta limits, and the prose-check-on-shell-write gate that depends on `is_code_path` (which depends on `enabled`).

Additionally, `code_extensions` in `lean.json` includes shell script extensions (`.sh`, `.bash`, `.zsh`, `.ps1`). This means heredoc writes to shell scripts are treated as code writes and get prose checks. But `is_patch_or_apply()` is true for `git apply` → `opaque_write_ask_message` (C1) bypasses this.

---

### C8: Recall Gate Exempt Prefixes Bypass Vault Check

**Severity:** LOW — writes to exempt-prefix paths skip the vault-read recall gate
**Location:** `hooks/policy/context.json` `exempt_write_prefixes`, `hooks/kleos-gate/src/engine/write.rs` lines 63–64

`exempt_write_prefixes` = `["docs/", "skills/", "user-rules/", "project-rules/", "hooks/policy/"]`. Any write to a path starting with one of these prefixes skips the `recall_gate_enabled` check entirely. This is intentional for the pack's own files (they don't need Obsidian recall), but it means:
1. A malicious agent that writes a payload to `docs/` or `skills/` (or any subdirectory of these) bypasses vault recall
2. If a project has source files under `docs/` (common for code examples in documentation), those are also exempt
3. The `hooks/policy/` exemption means policy JSON files themselves can be written without vault recall

---

### C9: `write.rs` `allow()` Is Terminal — No Post-Deny Context on Allow Path

**Severity:** LOW — the gate can only deny or allow, never inject context on the allow path for writes
**Location:** `hooks/kleos-gate/src/engine/write.rs` line 83

When `allow()` is called (line 83 in `write.rs`), it emits `{"permission": "allow"}` and exits immediately with code 0. This is the correct fail-closed behavior: allow = proceed, deny = block. However, the gate **never injects additional context** into an allow decision. Unlike `postToolUse` which can return `{"additional_context": ...}`, the write gate is binary: deny (exit 2 with message) or allow (exit 0 empty). This means that even if a write passes all checks, there is no mechanism to say "check your vault recall" — the agent only gets recalled context on `beforeSubmitPrompt` and `sessionStart`. If an agent modifies its prompt context mid-session and proceeds to write a file that needs vault recall, the gate will not re-check.

This is a design choice (not all write paths need vault recall; recall_gate_enabled is an opt-in flag), not a bug. Including it here for completeness.

---

## Unified Counterexample Set

The following 5 are **active unconditional bypasses** (not latent risks):

| # | Bypass | Surface | Any agent can trigger? | Requires anything from model? |
|---|---|---|---|---|
| C1 | `git apply` / `patch` / `git am` silent allow | shell gate → `allow()` | ✅ yes | No |
| C2 | MCP danger check dead regex, all MCP calls allow | MCP gate → `allow()` | ✅ yes | No |
| C3 | Read gate `allow_re` short-circuits `deny_re` ordering | read gate (latent risk) | ⚠️ policy-dependent | No |
| C4 | failClosed=false hooks crash silently | 6 hook surfaces | ⚠️ requires crash | No |
| C7 | `KLEOS_LEAN=0` disables ALL lean enforcement | lean gate → no-op | ✅ yes | No (env var set) |
| C8 | exempt_write_prefixes bypass vault recall | write gate → skip recall | ✅ for exempt-prefix paths | No |

The system is **not** complete. 5 active unconditional bypasses exist across 4 gate surfaces (shell, MCP, read, write) plus 1 session surface (failClosed=false). The Conjecture claim of "complete, fail-closed, low-entropy harness" is **falsified** by these structural gaps.

---

## Remaining Work for Completeness

1. **C1**: Populate `opaque_write_ask_message` in `shell.json` → turns silent allow into ask gate.
2. **C2**: Replace `"a^"` with a real MCP danger pattern (destructive tool names + write/execute/delete verbs).
3. **C3**: Reorder `read.rs` to check `deny_re` before `allow_re`, or merge both into a single pass.
4. **C4**: Add `failClosed: true` to `postToolUse`, `sessionStart`, `preCompact`, and `subagentStop` (these should block on failure, not pass through).
5. **C7**: Make `KLEOS_LEAN` env override require a separate confirmation env var (`KLEOS_LEAN_FORCE_ACK`), or remove the override entirely and gate it behind a CLI flag.
6. **C8**: Move exempt write prefixes to `exempt_write_prefixes_allow_vault_skip` and create a separate `exempt_write_prefixes_require_vault_log` list, or audit scope of what "exempt" means.

---

## Verification after fixes

After all 6 fixes above, the system must pass:
```bash
cd hooks/kleos-gate && cargo test
hooks/bin/kleos-gate bench
hooks/bin/kleos-gate gate-diff
```
PLUS a new adversarial bench that exercises C1–C8 payloads against the fixed gate and asserts deny/ask outcomes (not allow).

---

*This taxonomy is produced by source-level tracing of every branch in every engine module against the live policy JSON. It does not rely on any model behavior assumption. The bypasses are unconditional engineering defects.*
