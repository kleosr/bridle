export function usage() {
  return "usage: tool [--verbose] <file>";
}

export function parse(argv) {
  const opts = { verbose: false, file: null };
  for (const arg of argv) {
    if (arg === "--verbose") opts.verbose = true;
    else opts.file = arg;
  }
  return opts;
}
