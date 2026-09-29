import test from "node:test";
import assert from "node:assert/strict";
import { invoiceTotal } from "../src/invoice.js";

const us = (items, coupon) => ({ items, coupon, country: "US" });

test("small US order pays shipping and tax", () => {
  assert.equal(invoiceTotal(us([{ price: 25, qty: 2 }])), 61.5);
});

test("order of exactly 100 in items ships free", () => {
  assert.equal(invoiceTotal(us([{ price: 50, qty: 2 }])), 108);
});

test("coupon discount applies before tax", () => {
  assert.equal(invoiceTotal(us([{ price: 100, qty: 2 }], "SAVE10")), 194.4);
});

test("international orders pay double shipping and no tax", () => {
  const order = { items: [{ price: 20, qty: 2 }], country: "CA" };
  assert.equal(invoiceTotal(order), 55);
});
