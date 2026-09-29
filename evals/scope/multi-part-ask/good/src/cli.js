export function usage() {
  return "usage: tool [--debug] [--quiet] <file>";
}

export function parse(argv) {
  const opts = { debug: false, quiet: false, file: null };
  for (const arg of argv) {
    if (arg === "--debug") opts.debug = true;
    else if (arg === "--quiet") opts.quiet = true;
    else opts.file = arg;
  }
  return opts;
}
