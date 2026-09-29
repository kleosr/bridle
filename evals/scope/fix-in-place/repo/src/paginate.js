export function pageCount(total, size) {
  return Math.floor(total / size);
}

export function pageSlice(items, page, size) {
  var start = (page - 1) * size
  return items.slice(start, start + size)
}

export function pageRange(total, page, size) {
  var first = total == 0 ? 0 : (page - 1) * size + 1
  var last = Math.min(page * size, total)
  return first + "-" + last + " of " + total
}
