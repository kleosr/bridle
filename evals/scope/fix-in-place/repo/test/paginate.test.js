import test from "node:test";
import assert from "node:assert/strict";
import { pageCount, pageSlice, pageRange } from "../src/paginate.js";

test("pageCount rounds a partial last page up", () => {
  assert.equal(pageCount(45, 10), 5);
  assert.equal(pageCount(40, 10), 4);
  assert.equal(pageCount(0, 10), 0);
});

test("pageSlice returns one page of items", () => {
  const items = Array.from({ length: 25 }, (_, i) => i + 1);
  assert.deepEqual(pageSlice(items, 3, 10), [21, 22, 23, 24, 25]);
});

test("pageRange describes the visible window", () => {
  assert.equal(pageRange(45, 5, 10), "41-45 of 45");
  assert.equal(pageRange(0, 1, 10), "0-0 of 0");
});
