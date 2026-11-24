# ProveedoresApiCore — versionado, imagen y deploy

API de portal de proveedores, extraída de `EscorialAPI`. Lee 5 vistas de solo lectura
del esquema `web` en PostgreSQL. El consumidor es `PortalProveedores.Web`.

## Versionado y publicación

La versión vive en **tags anotados** (`0.1.1-rc.1`, mensaje `versionCode=N`), sin prefijo
`v`. El CI nunca commitea versiones. Cada PR compila la imagen con su versión definitiva
y, al mergear, se publica **esa misma imagen** (no se recompila).

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

## Listados: paginación, fechas y orden

`GET api/ordenescompra/{id}`, `api/ordenespago/{id}` y `api/facturaspendientes/{id}` aceptan
estos parámetros, todos opcionales. Sin ninguno responden igual que siempre: lista JSON de 50
filas en el orden de siempre.

| Parámetro | Detalle |
|---|---|
| `pagina` | Desde 1. Default 1. |
| `tamano` | Default 50, máximo 200 (si pasa, se recorta a 200). |
| `desde`, `hasta` | `yyyy-MM-dd`, ambos inclusivos. OC: `fechatransaccion`. Pagos: `fecha`. Facturas: `fechavencimiento`. Con filtro, las filas sin esa fecha quedan afuera. `desde > hasta` da lista vacía. |
| `ordenar`, `dir` | `dir` = `asc` o `desc` (default `desc`). Sin `ordenar` rige el orden de siempre. |

Valores de `ordenar` por listado: OC `fecha`, `transaccion`; pagos `fecha`, `numero`, `importe`;
facturas `fecha`, `vencimiento`, `saldo`. Sin `ordenar`: OC por `transaccion` desc, pagos por
`fecha` desc, facturas por `fecha` (de la factura) desc.

- Un valor inválido (`pagina=0`, `-1`, `abc`; `tamano` igual; fecha mal formada; `ordenar`
  o `dir` desconocidos) responde **400**.
- El header **`X-Total-Count`** trae el total de filas del filtro, antes de paginar. Una página
  fuera de rango da `200 []` con el total correcto. El cuerpo sigue siendo la lista, sin envoltorio.
- El orden es estable entre páginas: siempre se desempata por `transaccion_id` (OC) o por las
  columnas que salen en el listado (pagos y facturas, cuyas vistas no tienen columna única).
- Conviven con `buscar`, `orden` y `factura` (pagos).
- CORS expone `X-Total-Count` para el caso de un cliente en navegador.

## Resumen

`GET api/resumen/{proveedorId}`: una consulta, sin tope de filas, números crudos y JSON en
**camelCase** (el resto de la API sigue en PascalCase). "Hoy" es `America/Argentina/Buenos_Aires`.

```json
{
  "ocPendientes": 12,
  "facturasAbiertas": 87,
  "saldoTotal": 1234567.89,
  "facturasVencidas": 42,
  "facturasPorVencer7": 2,
  "facturasSinVencimiento": 1,
  "pagosUltimos6Meses": [ { "mes": "2026-06", "cantidad": 3 } ]
}
```

- `saldoTotal` es la suma de `saldoconv` en pesos (las notas de crédito restan).
- `facturasVencidas`: `fechavencimiento < hoy`. `facturasPorVencer7`: entre hoy y hoy+7, inclusive.
  `facturasSinVencimiento`: `fechavencimiento` nulo.
- `pagosUltimos6Meses`: siempre 6 entradas, del mes más viejo al actual, con `cantidad` 0 en los
  meses sin pagos. Cuenta números de pago distintos.
- Proveedor sin datos: todo en 0, 6 meses en 0 y 200 (no 404).

Prueba local: `docker compose -f db-test/docker-compose.test.yml up -d && bash db-test/smoke.sh`.

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

`api_portalproveedores_login` debe exponer `proveedor_id`, `usuario`, `clave` y `nombre`.
Desplegar la vista con `nombre` antes que la API: sin la columna el login da 500.

## Pendiente

Las contraseñas de `web.api_portalproveedores_login` están **sin hashear** y viajan en texto
plano sobre HTTP. Las consultas ya están parametrizadas (EF Core), así que la inyección SQL
que tenía `EscorialAPI` está cerrada, pero el hash de contraseñas queda por resolver.
