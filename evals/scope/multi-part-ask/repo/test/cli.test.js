import test from "node:test";
import assert from "node:assert/strict";
import { parse } from "../src/cli.js";

test("parse reads the file", () => {
  assert.equal(parse(["a.txt"]).file, "a.txt");
});
