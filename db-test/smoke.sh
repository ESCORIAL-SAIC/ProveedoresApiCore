#!/usr/bin/env bash
# Smoke test de la API contra la base SINTÉTICA de db-test/. Nunca usa una base real:
# la cadena de conexión está fija a 127.0.0.1:54329.
# Uso: docker compose -f db-test/docker-compose.test.yml up -d && bash db-test/smoke.sh
set -u
cd "$(dirname "$0")/../ProveedoresApiCore"

PORT=5199
BASE="http://127.0.0.1:$PORT"
P1=11111111-1111-1111-1111-111111111111
P2=22222222-2222-2222-2222-222222222222
OC1=$(docker exec proveedores-test-db psql -U postgres -d escorial_test -Atc "select md5('oc1')::uuid")
OC2=$(docker exec proveedores-test-db psql -U postgres -d escorial_test -Atc "select md5('oc2')::uuid")

export ConnectionStrings__Proveedores="Host=127.0.0.1;Port=54329;Database=escorial_test;Username=api_test;Password=api_test"
export Cors__Origenes__0="http://localhost:5000"
export ASPNETCORE_URLS="$BASE"
export ASPNETCORE_ENVIRONMENT=Production

dotnet build -v q >/dev/null || { echo "build falló"; exit 1; }
mkdir -p /tmp/opencode
dotnet run --no-build --no-launch-profile >/tmp/opencode/proveedores-api.log 2>&1 &
API=$!
trap 'kill $API 2>/dev/null' EXIT
for _ in $(seq 1 30); do curl -fs "$BASE/health/live" >/dev/null 2>&1 && break; sleep 1; done

FAIL=0
check() { # nombre, esperado, real
  if [ "$2" == "$3" ]; then echo "ok    $1"; else echo "FALLA $1: esperado [$2] real [$3]"; FAIL=1; fi
}
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }
body() { curl -s "$@"; }

check "version"            200 "$(code $BASE/version)"
check "health/ready"       200 "$(code $BASE/health/ready)"

# Login
check "login ok"           200 "$(code -X POST $BASE/api/login -H 'Content-Type: application/json' -d '{"User":"prov1","Password":"clave1"}')"
check "login proveedor"    "$P1" "$(body -X POST $BASE/api/login -H 'Content-Type: application/json' -d '{"User":"prov1","Password":"clave1"}' | jq -r .Proveedor)"
check "login mala clave"   401 "$(code -X POST $BASE/api/login -H 'Content-Type: application/json' -d '{"User":"prov1","Password":"mala"}')"
check "login inyeccion"    401 "$(code -X POST $BASE/api/login -H 'Content-Type: application/json' -d "{\"User\":\"' or '1'='1' --\",\"Password\":\"x\"}")"
check "login sin body"     400 "$(code -X POST $BASE/api/login -H 'Content-Type: application/json')"

# Ordenes de compra
check "oc limit 50"        50 "$(body $BASE/api/ordenescompra/$P1 | jq length)"
check "oc proveedor 2"     2 "$(body $BASE/api/ordenescompra/$P2 | jq length)"
check "oc campos"          "FechaTransaccion,Id,NombreProveedor,NumeroDocumento,Transaccion" "$(body $BASE/api/ordenescompra/$P1 | jq -r '.[0]|keys|join(",")')"
check "oc buscar _ literal" 1 "$(body "$BASE/api/ordenescompra/$P1?buscar=OC-ESP" | jq length)"
check "oc fecha nula"      '""' "$(body "$BASE/api/ordenescompra/$P1?buscar=OC-ESP" | jq '.[0].FechaTransaccion')"
check "oc buscar sin res"  0 "$(body "$BASE/api/ordenescompra/$P1?buscar=zzzz" | jq length)"
check "oc buscar comilla"  200 "$(code "$BASE/api/ordenescompra/$P1?buscar=%27%20or%20%271%27=%271")"
check "oc buscar NUL"     400 "$(code "$BASE/api/ordenescompra/$P1?buscar=a%00b")"
check "pagos orden NUL"    400 "$(code "$BASE/api/ordenespago/$P1?orden=a%00b")"
check "login NUL"          401 "$(code -X POST $BASE/api/login -H 'Content-Type: application/json' -d '{"User":"a\u0000b","Password":"x"}')"
check "oc id no uuid"      400 "$(code $BASE/api/ordenescompra/no-es-uuid)"

# Items
check "items cantidad 3dec" "10,125" "$(body $BASE/api/ordenescompra/$OC1/items | jq -r '.[]|select(.CodigoProducto=="PROD-A").CantidadPendiente')"
check "items entero"       "10" "$(body $BASE/api/ordenescompra/$OC1/items | jq -r '.[]|select(.CodigoProducto=="PROD-B").CantidadPendiente')"
check "items nulos"        '""' "$(body $BASE/api/ordenescompra/$OC1/items | jq '.[]|select(.CodigoProducto=="PROD-C").FechaEstimada')"
check "items limit 50"     50 "$(body $BASE/api/ordenescompra/$OC2/items | jq length)"

# Pagos
check "pagos limit 50"     50 "$(body $BASE/api/ordenespago/$P1 | jq length)"
check "pagos importe es-AR" '"$ 1.235,50"' "$(body "$BASE/api/ordenespago/$P1?orden=OP-0001" | jq '.[0].Importe')"
check "pagos fecha"        '"02/01/2026"' "$(body "$BASE/api/ordenespago/$P1?orden=OP-0001" | jq '.[0].Fecha')"
check "pagos filtro orden" 1 "$(body "$BASE/api/ordenespago/$P1?orden=OP-0007" | jq length)"
check "pagos filtro fact"  1 "$(body "$BASE/api/ordenespago/$P1?factura=FA-0007" | jq length)"
check "pagos buscar"       1 "$(body "$BASE/api/ordenespago/$P1?buscar=FA-0007" | jq length)"
check "pagos acento ILIKE" 1 "$(body "$BASE/api/ordenespago/$P1?orden=%C3%91" | jq length)"
check "pagos nulos"        '""' "$(body "$BASE/api/ordenespago/$P1?orden=OP_" | jq '.[]|select(.NumeroPago=="PAG-ESP").Importe')"
check "pagos aislamiento"  1 "$(body "$BASE/api/ordenespago/$P2" | jq '[.[].NumeroPago]|unique|length')"

# Facturas pendientes
check "fact limit 50"      50 "$(body $BASE/api/facturaspendientes/$P1 | jq length)"
check "fact orden desc"    '"FAC-USD"' "$(body $BASE/api/facturaspendientes/$P1 | jq '.[1].NumeroFactura')"
check "fact 200 sin filas" '[]' "$(body $BASE/api/facturaspendientes/33333333-3333-3333-3333-333333333333 | jq -c .)"
check "fact cot pesos"     '"$ 1,00"' "$(body $BASE/api/facturaspendientes/$P1 | jq '.[]|select(.NumeroFactura=="FAC-0060").Cotizacion')"
check "fact cot extranjera" '"1234.00  -  (2026-06-30)"' "$(body $BASE/api/facturaspendientes/$P1 | jq '.[]|select(.NumeroFactura=="FAC-USD").Cotizacion')"
check "fact total nulo"    '""' "$(body $BASE/api/facturaspendientes/$P1 | jq '.[]|select(.NumeroFactura=="FAC-NULL").Total')"
check "fact fecha actual." 19 "$(body $BASE/api/facturaspendientes/$P1 | jq '.[0].FechaActualizacion|length')"

echo
[ $FAIL == 0 ] && echo "TODO OK" || { echo "HAY FALLAS (log de la API: /tmp/opencode/proveedores-api.log)"; exit 1; }
