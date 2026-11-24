# ProveedoresApiCore — versionado, imagen y deploy

API de portal de proveedores, extraída de `EscorialAPI`. Lee 5 vistas de solo lectura
del esquema `web` en PostgreSQL. El consumidor es `PortalProveedores.Web`.

## Versionado y publicación

La versión vive en **tags anotados** (`0.1.1-rc.1`, mensaje `versionCode=N`), sin prefijo
`v`. El CI nunca commitea versiones. Cada PR compila la imagen con su versión definitiva
y, al mergear, se publica **esa misma imagen** (no se recompila). El zip para IIS se compila
en la misma PR y se adjunta a la release byte a byte igual.

| Destino de la PR | Resultado |
|---|---|
| PR a **`dev`** | pre-release `X.Y.Z-rc.N`, imágenes `:X.Y.Z-rc.N` y `:dev` |
| PR **`dev` → `main`** | release estable `X.Y.Z`, imágenes `:X.Y.Z`, `:X.Y` y `:latest` |

Etiqueta de la PR a `dev` (sin etiqueta = `bugfix`):

| Etiqueta | Efecto |
|---|---|
| `bugfix` | sube PATCH |
| `feature` | sube MINOR |
| `breaking` | sube MAJOR |

Checks obligatorios para mergear: `test` (xUnit, un check por test) y `Compilar imagen`
(build + escaneo trivy; falla ante HIGH/CRITICAL con fix disponible). Solo merge commit.

Probar el cálculo de versión sin tocar GitHub: `bash .github/scripts/test-version.sh`.
Tests locales: `dotnet test ProveedoresApiCore.slnx`.

## Setup único del repo

```bash
gh label create bugfix   -c d73a4a -d "PR que sube PATCH (default)"
gh label create feature  -c 0e8a16 -d "PR que sube MINOR"
gh label create breaking -c b60205 -d "PR que sube MAJOR"
gh api -X PATCH repos/ESCORIAL-SAIC/ProveedoresApiCore \
  -F allow_merge_commit=true -F allow_squash_merge=false -F allow_rebase_merge=false
```

Además: Settings → Actions → Workflow permissions → **Read and write**, rulesets de `dev` y
`main` con los checks `test` y `Compilar imagen`, y el package de GHCR público si el server
lo baja sin login.

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

## Instalar en IIS (Windows Server, sin Docker)

Cada release de GitHub adjunta `proveedores-api-X.Y.Z-win-x64.zip`: la API publicada para
Windows, dependiente del runtime. Es adicional a la imagen Docker, que sigue yendo a GHCR.
`/version` devuelve la misma versión que la imagen.

Todo lo de abajo lo hace `scripts/instalar-iis.ps1` (PowerShell como administrador):
`.\instalar-iis.ps1 -Zip C:\ruta\proveedores-api-X.Y.Z-win-x64.zip`. Pide la cadena de conexion
la primera vez, y el mismo comando con un zip nuevo actualiza. El .NET 10 Hosting Bundle hay que
instalarlo antes (el script avisa si falta). `-Sitio`, `-Ruta` y `-Puerto` son opcionales.

Una sola vez en el servidor:

1. Rol **IIS**.
2. **.NET 10 Hosting Bundle**.
3. Sitio con app pool **sin código administrado**.
4. Binding del sitio solo a `127.0.0.1`: la consume únicamente el portal, en el mismo servidor.
   Bajo IIS el enlace lo define el binding.
5. Cadena de conexión en la variable de entorno **`ConnectionStrings__Proveedores`** del app pool
   (doble guion bajo). **Nunca** en el zip ni en el repo. El usuario de base debe tener solo
   `SELECT` (ver "Permisos de base"). Los orígenes CORS se ajustan con un `appsettings.json` propio
   en la carpeta del sitio, a partir de `appsettings.ejemplo.json`.

Para actualizar:

1. Descargar el zip de la release en GitHub.
2. Crear `app_offline.htm` en la carpeta del sitio (IIS detiene la app sin reiniciar el servidor).
3. Descomprimir encima. El zip **no incluye `appsettings.json`**, así que no pisa la configuración
   (solo trae `appsettings.ejemplo.json`).
4. Borrar `app_offline.htm`.

## Permisos de base

El usuario necesita sólo `SELECT` sobre las 5 vistas del esquema `web`:
`api_portalproveedores_login`, `_ordenescompra`, `_itemsordenescompra`, `_pagos`,
`_facturaspendientes`.

## Pendiente

Las contraseñas de `web.api_portalproveedores_login` están **sin hashear** y viajan en texto
plano sobre HTTP. Las consultas ya están parametrizadas (EF Core), así que la inyección SQL
que tenía `EscorialAPI` está cerrada, pero el hash de contraseñas queda por resolver.
