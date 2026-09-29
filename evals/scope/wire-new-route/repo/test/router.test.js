import test from "node:test";
import assert from "node:assert/strict";
import { handle } from "../src/router.js";

test("hello route answers", () => {
  assert.equal(handle("/hello").status, 200);
});

test("health route reports ok", () => {
  assert.deepEqual(handle("/health"), { status: 200, body: { ok: true } });
});
