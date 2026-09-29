function assertPositiveInteger(value, name) {
  if (!Number.isInteger(value) || value < 1) {
    throw new RangeError(`${name} must be a positive integer`);
  }
}

export function pageCount(total, size) {
  assertPositiveInteger(size, "size");
  return Math.ceil(total / size);
}

export function pageSlice(items, page, size) {
  assertPositiveInteger(page, "page");
  assertPositiveInteger(size, "size");
  const start = (page - 1) * size;
  return items.slice(start, start + size);
}

export function pageRange(total, page, size) {
  const first = total === 0 ? 0 : (page - 1) * size + 1;
  const last = Math.min(page * size, total);
  return `${first}-${last} of ${total}`;
}
