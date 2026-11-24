#!/usr/bin/env bash
# Verifica el share SMB de prueba (container proveedores-test-share): que exista, que la
# carpeta con llaves se liste y que un PDF se descargue y empiece con %PDF.
# Uso: bash db-test/make-share.sh && docker compose -f db-test/docker-compose.test.yml up -d && bash db-test/check-share.sh
set -u
FAIL=0
C=(docker exec proveedores-test-share smbclient //localhost/PortalProveedores -U portal%portal)
P1=11111111-1111-1111-1111-111111111111
check() { if [ "$2" == "$3" ]; then echo "ok    $1"; else echo "FALLA $1: esperado [$2] real [$3]"; FAIL=1; fi; }

check "share visible"       1  "$(docker exec proveedores-test-share smbclient -L localhost -U portal%portal 2>&1 | grep -c PortalProveedores)"
check "pagos prov1 (60)"    60 "$("${C[@]}" -c "ls \"PDF\\OrdenPago\\{$P1}\\*\"" 2>&1 | grep -c "PAG-.*\.pdf")"
check "compras prov1 (60)"  60 "$("${C[@]}" -c "ls \"PDF\\OrdenCompra\\{$P1}\\*\"" 2>&1 | grep -c "ND-.*\.pdf")"
"${C[@]}" -c "get \"PDF\\OrdenPago\\{$P1}\\PAG-0001.pdf\" /tmp/check-pag.pdf" >/dev/null 2>&1
check "descarga es PDF"     "%PDF-1.4" "$(docker exec proveedores-test-share head -c 8 /tmp/check-pag.pdf 2>/dev/null)"
check "prov2 aislado (1)"   1  "$("${C[@]}" -c 'ls "PDF\OrdenPago\{22222222-2222-2222-2222-222222222222}\*"' 2>&1 | grep -c "PAG-.*\.pdf")"

[ $FAIL == 0 ] && echo "TODO OK" || { echo "HAY FALLAS"; exit 1; }
