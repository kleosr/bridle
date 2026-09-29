export function invoiceTotal(order) {
  var subtotal = 0
  for (var i = 0; i < order.items.length; i++) {
    subtotal += order.items[i].price * order.items[i].qty
  }
  var discount = 0
  if (order.coupon == "SAVE10") discount = subtotal * 0.10
  else if (order.coupon == "SAVE20") discount = subtotal * 0.20
  var shipping = 7.5
  if (subtotal > 100) shipping = 0
  if (order.country != "US") shipping = shipping * 2
  var taxable = subtotal - discount
  var tax = taxable * (order.country == "US" ? 0.08 : 0)
  var total = taxable + tax + shipping
  return Math.round(total * 100) / 100
}
