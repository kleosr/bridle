# Frontend / backend layout

Apply when the project has separate `frontend/` and `backend/` and the task touches them.

```
frontend/src/features/<feature>/{components,hooks,api}
  + shared/ for generic UI only
backend/src/{domains,api,infra,lib}
```

## Frontend

- Functional components; custom hooks for reusable logic.
- Feature folders mirror backend bounded contexts when possible.
- UI talks to the backend only through its API layer.
- Server state lives in query hooks, not copied into component state.
- Validate and type API responses at the boundary.
- Accessibility is not optional.

## Backend

- HTTP handlers are thin: validate payload against a schema, delegate to the domain, map the result to a response.
- Domain code never imports from `api/` or `infra/` directly.
- Validate every input at a system boundary (HTTP, message handler, CLI entrypoint).
