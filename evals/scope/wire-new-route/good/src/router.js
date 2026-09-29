import { hello } from "./routes/hello.js";
import { health } from "./routes/health.js";

const routes = new Map([["/hello", hello], ["/health", health]]);

export function handle(path) {
  const route = routes.get(path);
  return route ? route() : { status: 404 };
}
