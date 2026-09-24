# ProveedoresApiCore — versionado, imagen y deploy

API de portal de proveedores, extraída de `EscorialAPI`. Lee 5 vistas de solo lectura
del esquema `web` en PostgreSQL. El consumidor es `PortalProveedores.Web`.

## Versionado

Los **git tags son la única fuente de verdad**. No hay números de versión escritos a mano.
Al mergear una PR, el workflow calcula la versión y crea el tag:

| Label en la PR | Efecto |
|---|---|
| `release:major` | `1.2.3` → `2.0.0` |
| `release:minor` | `1.2.3` → `1.3.0` |
| *(ninguna)* | `1.2.3` → `1.2.4` |
| `release:skip` | no versiona |

- PR a **`dev`** → pre-release `vX.Y.Z-rc.N`, imágenes `:X.Y.Z-rc.N` y `:dev`
- PR a **`main`** → release final `vX.Y.Z`, imágenes `:X.Y.Z`, `:X.Y` y `:latest`

Probar el cálculo sin tocar GitHub:

```bash
DRY_RUN=1 GITHUB_REF=refs/heads/main PR_LABELS="release:minor" MOCK_TAGS="v0.1.0" \
  bash .github/scripts/compute-version.sh     # -> version=0.2.0
```

## Setup único del repo

```bash
gh label create release:minor -c 0e8a16 -d "Sube MINOR al mergear"
gh label create release:major -c b60205 -d "Sube MAJOR al mergear"
gh label create release:skip  -c cccccc -d "No versiona esta PR"

git tag v0.1.0 && git push origin v0.1.0
```

Además: Settings → Actions → Workflow permissions → **Read and write**, y hacer público el
package en GHCR si el server lo baja sin login.

## Endpoints de estado

| Ruta | Qué hace |
|---|---|
| `GET /version` | versión inyectada en build |
| `GET /health/live` | liveness: 200 mientras el proceso viva. **No toca la base.** |
| `GET /health/ready` | readiness: 200 sólo si la base responde; 503 si no |

El `HEALTHCHECK` del container apunta a **live**, no a ready: una base caída no debe
reiniciar el container.

## Deploy

```bash
cp .env.example .env     # completar CONNECTION_STRING
docker compose up -d
```

La cadena de conexión **nunca entra a la imagen**: llega por la variable de entorno
`ConnectionStrings__Proveedores`, que el compose lee del `.env` del server (no versionado).

Para fijar una versión en vez de `latest`, poner `IMAGE_TAG=0.1.0` en el `.env`.

## Permisos de base

El usuario necesita sólo `SELECT` sobre las 5 vistas del esquema `web`:
`api_portalproveedores_login`, `_ordenescompra`, `_itemsordenescompra`, `_pagos`,
`_facturaspendientes`.

## Pendiente

Las contraseñas de `web.api_portalproveedores_login` están **sin hashear** y viajan en texto
plano sobre HTTP. Las consultas ya están parametrizadas (EF Core), así que la inyección SQL
que tenía `EscorialAPI` está cerrada, pero el hash de contraseñas queda por resolver.
