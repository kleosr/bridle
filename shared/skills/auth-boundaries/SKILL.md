---
name: auth-boundaries
description: >-
  Autenticación y autorización correctas: sesiones vs JWT, access/refresh
  tokens, OAuth2 + PKCE, OIDC, SSO, API keys, contraseñas y permisos
  deny-by-default con tests negativos. Úsala cuando la tarea toque login,
  logout, registro, sesiones, cookies, tokens, JWT, OAuth, "Sign in with…",
  SSO/SAML, API keys, roles, permisos, middleware de auth, RLS o "solo el dueño
  puede…", aunque el usuario no diga "auth". También al revisar IDOR o fugas
  entre usuarios o tenants.
---

# Auth boundaries

**Authn** responde quién eres. **Authz** responde qué puedes tocar. Casi todas
las fugas reales son authz faltante en un endpoint que sí tenía login.

**Alcance:** asegura la authn/authz de lo que el pedido crea o cambia. Huecos
que veas en otras rutas van al reporte como riesgo, no al diff.

## Primero, lo que ya existe

Lee cómo autentica el repo (proveedor, librería, middleware, RLS) y úsalo. No
introduzcas un segundo mecanismo ni una librería de auth nueva si ya hay una.
Si es Supabase, aplica además `supabase.mdc`. Nunca escribas tu propia crypto,
formato de token ni hashing.

## Elegir mecanismo (solo si el repo no tiene uno)

| Caso | Usa |
| --- | --- |
| App web propia (mismo sitio) | **Sesión en cookie** `HttpOnly; Secure; SameSite=Lax`, id opaco, estado en servidor. Revocable al instante. |
| API consumida por móvil/terceros | **Access token corto** (5–15 min) + **refresh token** rotado. |
| "Entrar con Google/GitHub" | **OIDC** sobre OAuth2 Authorization Code **+ PKCE**. Nunca el flujo implícito. |
| Empresa con IdP (Okta, Entra) | **SSO** por OIDC; SAML solo si el cliente lo exige. |
| Máquina a máquina | API key o client credentials, con scopes, rotables. |

Detalle de tokens, cookies, JWT y OIDC en `references/tokens-and-sessions.md`.

## Reglas duras

- **Authz en el servidor, en cada command y query**, después de autenticar y
  antes de tocar datos (`cqrs-data-flow`: parsear → autorizar → ejecutar).
  Ocultar un botón no es authz. Middleware de ruta solo no alcanza.
- **Deny-by-default**: sin regla explícita que permita, se niega. El recurso se
  carga filtrando por dueño/tenant (`WHERE id = $1 AND tenant_id = $2`) o por
  RLS; nunca por id solo (IDOR).
- **Roles y permisos en un solo módulo** (`features/access/…` o lo que use el
  repo): `can(actor, action, resource)`. Nada de `if (user.role === 'admin')`
  disperso.
- **Tokens y secretos**: nunca en `localStorage`, logs, URLs ni mensajes de
  error. JWT se verifica (firma, `alg` fijo, `iss`, `aud`, `exp`) en cada uso;
  decodificar no es verificar.
- **Contraseñas**: argon2id (o bcrypt si el repo ya lo usa), nunca hash rápido
  ni reversible. Mensaje de error de login idéntico para usuario inexistente y
  contraseña mala. Rate limit por cuenta e IP.
- **Cambios de privilegio** (cambio de contraseña, email, rol, logout) invalidan
  sesiones y refresh tokens previos.
- **Cookies con estado + formularios**: protección CSRF (SameSite + token o
  verificación de `Origin`) en toda mutación.
- **Service keys / roles de servicio** solo en servidor; nunca en el bundle del cliente.

## Verificación (tests negativos obligatorios)

Por cada endpoint, command o policy tocada, al menos:

1. Sin sesión/token → `UNAUTHENTICATED` (401).
2. Otro usuario/tenant lee el recurso → `FORBIDDEN` o `NOT_FOUND`.
3. Otro usuario/tenant escribe o borra → rechazado y la fila no cambia.
4. Rol insuficiente → `FORBIDDEN`.
5. Token expirado, firma inválida o `aud` equivocado → rechazado.
6. Caso feliz del dueño → pasa.

Sin estos tests, reporta la authz como riesgo no verificado. Antes de cerrar,
pide `hunter` sobre el diff: authz e IDOR son su terreno.
