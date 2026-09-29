import { hello } from "./routes/hello.js";

const routes = new Map([["/hello", hello]]);

export function handle(path) {
  const route = routes.get(path);
  return route ? route() : { status: 404 };
}
