const FREE_SHIPPING_MIN = 100;
const BASE_SHIPPING = 7.5;
const US_TAX_RATE = 0.08;
const COUPONS = { SAVE10: 0.1, SAVE20: 0.2 };

function lineTotal(item) {
  if (!Number.isFinite(item.price) || !Number.isInteger(item.qty) || item.qty < 0) {
    throw new TypeError("invalid line item");
  }
  return item.price * item.qty;
}

export function invoiceTotal(order) {
  if (!order || !Array.isArray(order.items)) {
    throw new TypeError("order.items must be an array");
  }
  const subtotal = order.items.reduce((sum, item) => sum + lineTotal(item), 0);
  const discount = subtotal * (COUPONS[order.coupon] ?? 0);
  const isUS = order.country === "US";
  let shipping = subtotal >= FREE_SHIPPING_MIN ? 0 : BASE_SHIPPING;
  if (!isUS) shipping *= 2;
  const taxable = subtotal - discount;
  const tax = isUS ? taxable * US_TAX_RATE : 0;
  return Math.round((taxable + tax + shipping) * 100) / 100;
}
