# Tokens, sesiones y protocolos

## Sesión en cookie (default para web propia)

- Id aleatorio ≥ 128 bits, opaco; el estado vive en DB/Redis con expiración.
- `Set-Cookie: sid=…; HttpOnly; Secure; SameSite=Lax; Path=/`. `SameSite=Strict`
  si no hay navegación entrante desde otros sitios que deba mantener sesión.
- Regenera el id al iniciar sesión y al elevar privilegio (evita fijación de sesión).
- Expiración por inactividad y absoluta. Logout borra el registro en servidor,
  no solo la cookie.

## Access + refresh tokens (APIs, móvil)

- **Access token**: corto (5–15 min), enviado como `Authorization: Bearer …`.
  Stateless, así que no se revoca: por eso dura poco.
- **Refresh token**: largo, opaco, guardado hasheado en servidor, un solo uso.
  Cada refresh emite uno nuevo y marca el anterior como usado (**rotación**).
  Si llega uno ya usado → reuso detectado: revoca toda la familia de tokens de esa sesión.
- En web, el refresh token va en cookie `HttpOnly` con `Path` limitado al
  endpoint de refresh; nunca accesible desde JS.

## JWT

- Verifica firma con la clave esperada y un `alg` fijo en la configuración
  (rechaza `none` y cambios de algoritmo). Valida `iss`, `aud`, `exp`, `nbf`.
- Claves asimétricas (RS256/ES256) cuando otro servicio verifica; publica JWKS
  y soporta rotación por `kid`.
- El payload es legible por cualquiera: no pongas datos sensibles.
- No metas permisos que cambian seguido en el JWT; quedan viejos hasta que expira.

## OAuth2 / OIDC

- Authorization Code + **PKCE** (`S256`) siempre, también en apps de servidor.
- `state` aleatorio atado a la sesión (CSRF del callback) y `nonce` en OIDC.
- `redirect_uri` exacto registrado; nunca redirecciones abiertas construidas desde parámetros.
- Valida el `id_token`: firma, `iss`, `aud` = tu client id, `exp`, `nonce`.
- OAuth2 da **autorización** (access token para una API); OIDC agrega
  **identidad** (`id_token`, `sub`). Identifica al usuario por `iss` + `sub`, no por email.
- Vincular cuentas por email solo si el proveedor marca `email_verified`.

## SSO

- OIDC por defecto; SAML si el cliente empresarial lo exige (usa una librería
  mantenida, valida firma de la aserción y audiencia, rechaza aserciones repetidas).
- Aprovisionamiento/desaprovisionamiento (SCIM o webhook) para que un empleado
  dado de baja pierda acceso.

## API keys

- Genera con prefijo identificable (`app_live_…`) para detección de fugas;
  guarda solo el hash; muestra el valor una sola vez.
- Scopes mínimos, expiración o rotación, última fecha de uso visible, revocación inmediata.

## Autorización

- RBAC (roles → permisos) para la mayoría; ABAC/ReBAC (atributos, relaciones
  como "miembro del proyecto") cuando el permiso depende del recurso.
- Multi-tenant: el `tenant_id` sale de la sesión, nunca del body o query del request.
