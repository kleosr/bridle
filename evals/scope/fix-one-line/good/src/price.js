export function discount(price, percent) {
  return price - price * percent / 100;
}

export function label(price, currency) {
  var out = currency + " " + price.toFixed(2)
  if (price == 0) out = "free"
  return out
}
