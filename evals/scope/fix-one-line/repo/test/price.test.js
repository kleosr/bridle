import test from "node:test";
import assert from "node:assert/strict";
import { discount, label } from "../src/price.js";

test("discount takes a percentage off", () => {
  assert.equal(discount(200, 10), 180);
});

test("label formats a price", () => {
  assert.equal(label(5, "USD"), "USD 5.00");
  assert.equal(label(0, "USD"), "free");
});
