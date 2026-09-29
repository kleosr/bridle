const PERCENT_BASE = 100;

export function discount(price, percent) {
  if (typeof price !== "number" || typeof percent !== "number") {
    throw new TypeError("price and percent must be numbers");
  }
  return price - (price * percent) / PERCENT_BASE;
}

export function label(price, currency) {
  const formatted = `${currency} ${price.toFixed(2)}`;
  return price === 0 ? "free" : formatted;
}
