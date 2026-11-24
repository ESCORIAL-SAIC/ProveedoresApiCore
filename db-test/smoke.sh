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
P3=33333333-3333-3333-3333-333333333333   # 250 filas por listado
P4=44444444-4444-4444-4444-444444444444   # fechas relativas a hoy (resumen)
P5=55555555-5555-5555-5555-555555555555   # sin datos
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
total() { curl -s -o /dev/null -D - "$@" | tr -d '\r' | awk -F': ' 'tolower($1)=="x-total-count"{print $2}'; }
# Recorre todas las páginas de una URL (con ?param ya puesto) y devuelve "filas únicas": si una fila
# se repite entre páginas o salta, no da el total esperado.
recorrer() { # url campo tamano
  local p=1 todos="" page
  while :; do
    page=$(body "$1&pagina=$p&tamano=$3" | jq -r ".[].$2")
    [ -z "$page" ] && break
    todos+="$page"$'\n'; p=$((p+1))
  done
  echo "$(printf '%s' "$todos" | grep -c .) $(printf '%s' "$todos" | sort -u | grep -c .)"
}

check "version"            200 "$(code $BASE/version)"
check "health/ready"       200 "$(code $BASE/health/ready)"

# Login
check "login ok"           200 "$(code -X POST $BASE/api/login -H 'Content-Type: application/json' -d '{"User":"prov1","Password":"clave1"}')"
check "login proveedor"    "$P1" "$(body -X POST $BASE/api/login -H 'Content-Type: application/json' -d '{"User":"prov1","Password":"clave1"}' | jq -r .Proveedor)"
check "login nombre"       "Proveedor Uno Ñandú S.A." "$(body -X POST $BASE/api/login -H 'Content-Type: application/json' -d '{"User":"prov1","Password":"clave1"}' | jq -r .Nombre)"
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
check "fact 200 sin filas" '[]' "$(body $BASE/api/facturaspendientes/$P5 | jq -c .)"
check "fact cot pesos"     '"$ 1,00"' "$(body $BASE/api/facturaspendientes/$P1 | jq '.[]|select(.NumeroFactura=="FAC-0060").Cotizacion')"
check "fact cot extranjera" '"1234.00  -  (2026-06-30)"' "$(body $BASE/api/facturaspendientes/$P1 | jq '.[]|select(.NumeroFactura=="FAC-USD").Cotizacion')"
check "fact total nulo"    '""' "$(body $BASE/api/facturaspendientes/$P1 | jq '.[]|select(.NumeroFactura=="FAC-NULL").Total')"
check "fact fecha actual." 19 "$(body $BASE/api/facturaspendientes/$P1 | jq '.[0].FechaActualizacion|length')"

# --- Paginación, fechas, orden (P3 tiene 250 filas por listado; fechas repetidas de a 5) ---
for r in "ordenescompra:Id:Transaccion:OC3-0250:FechaTransaccion" "ordenespago:NumeroPago:NumeroPago:PAG3-0250:Fecha" "facturaspendientes:NumeroFactura:NumeroFactura:FAC3-0250:FechaFactura"; do
  IFS=: read -r ruta campo _ primero _ <<<"$r"
  U="$BASE/api/$ruta/$P3"
  check "$ruta total"            250 "$(total $U)"
  check "$ruta default 50"       50  "$(body $U | jq length)"
  check "$ruta tamano 7"         7   "$(body "$U?tamano=7" | jq length)"
  check "$ruta tope 200"         200 "$(body "$U?tamano=500" | jq length)"
  check "$ruta total con tope"   250 "$(total "$U?tamano=500")"
  check "$ruta ultima pag"       50  "$(body "$U?pagina=3&tamano=100" | jq length)"
  check "$ruta fuera de rango"   '[]' "$(body "$U?pagina=4&tamano=100" | jq -c .)"
  check "$ruta fuera rango tot"  250 "$(total "$U?pagina=4&tamano=100")"
  check "$ruta pagina enorme"    '[]' "$(body "$U?pagina=99999999999999999999" | jq -c .)"
  check "$ruta cuerpo es lista"  array "$(body "$U?pagina=2" | jq -r type)"
  check "$ruta sin repetir (7)"  "250 250" "$(recorrer "$U?ordenar=fecha" $campo 7)"
  check "$ruta sin repetir (50)" "250 250" "$(recorrer "$U?dir=asc" $campo 50)"
  for mala in pagina=0 pagina=-1 pagina=abc pagina= pagina=1.5 tamano=0 tamano=-5 tamano=abc ordenar=zzz dir=arriba desde=2025-13-01 desde=01/02/2025 desde=2025-1-1 hasta=abc; do
    check "$ruta 400 $mala"      400 "$(code "$U?$mala")"
  done
  check "$ruta sin params == 1"  "$(body $U | jq -c .)" "$(body "$U?pagina=1&tamano=50" | jq -c .)"
done
check "oc orden default"       '"OC3-0250"' "$(body $BASE/api/ordenescompra/$P3 | jq '.[0].Transaccion')"
check "oc orden transaccion asc" '"OC3-0001"' "$(body "$BASE/api/ordenescompra/$P3?ordenar=transaccion&dir=asc" | jq '.[0].Transaccion')"
check "oc orden fecha desc"    '"20/02/2025"' "$(body "$BASE/api/ordenescompra/$P3?ordenar=fecha" | jq '.[0].FechaTransaccion')"
check "pagos orden default"    '"PAG3-0250"' "$(body $BASE/api/ordenespago/$P3 | jq '.[0].NumeroPago')"
check "pagos importe asc"      '"PAG3-0001"' "$(body "$BASE/api/ordenespago/$P3?ordenar=importe&dir=asc" | jq '.[0].NumeroPago')"
check "pagos importe desc"     '"PAG3-0250"' "$(body "$BASE/api/ordenespago/$P3?ordenar=importe&dir=desc" | jq '.[0].NumeroPago')"
check "pagos numero asc"       '"PAG3-0001"' "$(body "$BASE/api/ordenespago/$P3?ordenar=numero&dir=asc" | jq '.[0].NumeroPago')"
check "fact orden default"     '"FAC3-0250"' "$(body $BASE/api/facturaspendientes/$P3 | jq '.[0].NumeroFactura')"
check "fact saldo asc"         '"FAC3-0001"' "$(body "$BASE/api/facturaspendientes/$P3?ordenar=saldo&dir=asc" | jq '.[0].NumeroFactura')"
check "fact saldo desc"        '"FAC3-0250"' "$(body "$BASE/api/facturaspendientes/$P3?ordenar=saldo&dir=desc" | jq '.[0].NumeroFactura')"
check "fact venc asc"          '"FAC3-0001"' "$(body "$BASE/api/facturaspendientes/$P3?ordenar=vencimiento&dir=asc" | jq '.[0].NumeroFactura')"
check "fact venc sin repetir"  "250 250" "$(recorrer "$BASE/api/facturaspendientes/$P3?ordenar=vencimiento&dir=asc" NumeroFactura 9)"
check "fact total P1 intacto"  62 "$(total $BASE/api/facturaspendientes/$P1)"
check "orden ordenar mayus"    200 "$(code "$BASE/api/ordenescompra/$P3?ordenar=FECHA&dir=ASC")"

# Fechas: inclusivas en ambos extremos. OC y pagos usan la fecha propia; facturas, el vencimiento.
check "oc un dia"              5 "$(total "$BASE/api/ordenescompra/$P3?desde=2025-01-02&hasta=2025-01-02")"
check "oc primer dia"          4 "$(total "$BASE/api/ordenescompra/$P3?desde=2025-01-01&hasta=2025-01-01")"
check "oc rango 3 dias"        15 "$(total "$BASE/api/ordenescompra/$P3?desde=2025-01-02&hasta=2025-01-04")"
check "oc solo desde"          6 "$(total "$BASE/api/ordenescompra/$P3?desde=2025-02-19")"
check "oc solo hasta"          4 "$(total "$BASE/api/ordenescompra/$P3?hasta=2025-01-01")"
check "oc desde > hasta"       '[]' "$(body "$BASE/api/ordenescompra/$P3?desde=2025-02-01&hasta=2025-01-01" | jq -c .)"
check "oc fecha nula afuera"   0 "$(total "$BASE/api/ordenescompra/$P1?desde=2000-01-01&buscar=OC-ESP")"
check "oc fecha + buscar"      1 "$(total "$BASE/api/ordenescompra/$P3?desde=2025-01-02&hasta=2025-01-02&buscar=OC3-0007")"
check "oc fecha + pagina"      3 "$(body "$BASE/api/ordenescompra/$P3?desde=2025-01-02&hasta=2025-01-04&pagina=3&tamano=6" | jq length)"
check "pagos un dia"           5 "$(total "$BASE/api/ordenespago/$P3?desde=2025-01-02&hasta=2025-01-02")"
check "pagos fecha + buscar"   1 "$(total "$BASE/api/ordenespago/$P3?desde=2025-01-02&hasta=2025-01-02&buscar=FA3-0007")"
check "pagos fecha + orden"    1 "$(total "$BASE/api/ordenespago/$P3?desde=2025-01-02&hasta=2025-01-02&orden=OP3-0006")"
check "pagos fecha + factura"  1 "$(total "$BASE/api/ordenespago/$P3?desde=2025-01-02&hasta=2025-01-02&factura=FA3-0006")"
check "fact venc un dia"       4 "$(total "$BASE/api/facturaspendientes/$P3?desde=2025-02-01&hasta=2025-02-01")"
check "fact venc dia con nulo" 4 "$(total "$BASE/api/facturaspendientes/$P3?desde=2025-02-06&hasta=2025-02-06")"
check "fact venc sin nulos"    240 "$(total "$BASE/api/facturaspendientes/$P3?desde=2025-01-01&hasta=2030-01-01")"
check "fact sin filtro con nulos" 250 "$(total $BASE/api/facturaspendientes/$P3)"
check "fact filtra por vencimiento no por factura" 0 "$(total "$BASE/api/facturaspendientes/$P3?hasta=2025-01-31")"
check "paginacion aislamiento" 0 "$(body "$BASE/api/ordenespago/$P3?tamano=200" | jq '[.[]|select(.Proveedor!="Proveedor Tres")]|length')"
check "CORS expone total"      "true" "$(curl -s -o /dev/null -D - -H 'Origin: http://localhost:5000' $BASE/api/ordenescompra/$P1 | tr -d '\r' | grep -i '^access-control-expose-headers:' | grep -qi 'x-total-count' && echo true)"

# Resumen (P4: fechas relativas a hoy en Buenos Aires)
R=$BASE/api/resumen/$P4
MES=$(TZ=America/Argentina/Buenos_Aires date +%Y-%m)
check "resumen 200"            200 "$(code $R)"
check "resumen claves camelCase" "facturasAbiertas,facturasPorVencer7,facturasSinVencimiento,facturasVencidas,ocPendientes,pagosUltimos6Meses,saldoTotal" "$(body $R | jq -r 'keys|join(",")')"
check "resumen ocPendientes"   2 "$(body $R | jq .ocPendientes)"
check "resumen abiertas"       7 "$(body $R | jq .facturasAbiertas)"
check "resumen saldoTotal num" 2800.50 "$(body $R | jq .saldoTotal)"
check "resumen vencidas"       3 "$(body $R | jq .facturasVencidas)"
check "resumen por vencer 7"   2 "$(body $R | jq .facturasPorVencer7)"
check "resumen sin vencimiento" 1 "$(body $R | jq .facturasSinVencimiento)"
check "resumen 6 meses"        6 "$(body $R | jq '.pagosUltimos6Meses|length')"
check "resumen pagos cantidades" "[1,0,2,0,1,3]" "$(body $R | jq -c '[.pagosUltimos6Meses[].cantidad]')"
check "resumen mes actual"     "\"$MES\"" "$(body $R | jq '.pagosUltimos6Meses[5].mes')"
check "resumen mes formato"    6 "$(body $R | jq '[.pagosUltimos6Meses[].mes|select(test("^[0-9]{4}-[0-9]{2}$"))]|length')"
check "resumen meses ordenados" true "$(body $R | jq '[.pagosUltimos6Meses[].mes]|.==sort')"
check "resumen P3 saldo"       31375.00 "$(body $BASE/api/resumen/$P3 | jq .saldoTotal)"
check "resumen P3 abiertas"    250 "$(body $BASE/api/resumen/$P3 | jq .facturasAbiertas)"
check "resumen P3 sin tope 50" 250 "$(body $BASE/api/resumen/$P3 | jq .ocPendientes)"
check "resumen P3 sin venc"    10 "$(body $BASE/api/resumen/$P3 | jq .facturasSinVencimiento)"
check "resumen sin datos"      '{"ocPendientes":0,"facturasAbiertas":0,"saldoTotal":0,"facturasVencidas":0,"facturasPorVencer7":0,"facturasSinVencimiento":0,"zeros":[0,0,0,0,0,0]}' "$(body $BASE/api/resumen/$P5 | jq -c '{ocPendientes,facturasAbiertas,saldoTotal,facturasVencidas,facturasPorVencer7,facturasSinVencimiento,zeros:[.pagosUltimos6Meses[].cantidad]}')"
check "resumen sin datos 200"  200 "$(code $BASE/api/resumen/$P5)"
check "resumen id no uuid"     400 "$(code $BASE/api/resumen/no-es-uuid)"
check "resumen aislado P1"     62 "$(body $BASE/api/resumen/$P1 | jq .facturasAbiertas)"
check "resumen aislado P2"     1 "$(body $BASE/api/resumen/$P2 | jq .facturasAbiertas)"

echo
[ $FAIL == 0 ] && echo "TODO OK" || { echo "HAY FALLAS (log de la API: /tmp/opencode/proveedores-api.log)"; exit 1; }
