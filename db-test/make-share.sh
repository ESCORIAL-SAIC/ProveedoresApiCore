#!/usr/bin/env bash
# Genera PDFs de prueba con la estructura que lee el portal (Config.cs):
#   <share>/PDF/OrdenPago/{<proveedor_id>}/<NumeroPago>.pdf
#   <share>/PDF/OrdenCompra/{<proveedor_id>}/<NumeroDocumento>.pdf
# Los nombres salen de db-test/init.sql: el portal busca los archivos cuyo path CONTIENE
# NumeroPago (PAG-0001) o NumeroDocumento (ND-0001). Las llaves de la carpeta son literales.
set -euo pipefail
cd "$(dirname "$0")"
python3 - <<'PY'
import os, shutil

def pdf(texto):
    cont = f"BT /F1 18 Tf 72 720 Td ({texto}) Tj ET".encode()
    objs = [b"<< /Type /Catalog /Pages 2 0 R >>",
            b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
            b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R "
            b"/Resources << /Font << /F1 5 0 R >> >> >>",
            b"<< /Length %d >>\nstream\n" % len(cont) + cont + b"\nendstream",
            b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"]
    out, pos = b"%PDF-1.4\n", []
    for i, o in enumerate(objs, 1):
        pos.append(len(out)); out += b"%d 0 obj\n" % i + o + b"\nendobj\n"
    xref = len(out)
    out += b"xref\n0 %d\n0000000000 65535 f \n" % (len(objs) + 1)
    out += b"".join(b"%010d 00000 n \n" % p for p in pos)
    return out + b"trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n" % (len(objs) + 1, xref)

P1, P2 = "11111111-1111-1111-1111-111111111111", "22222222-2222-2222-2222-222222222222"
shutil.rmtree("share", ignore_errors=True)
def crear(tipo, prov, nombre):
    d = f"share/PDF/{tipo}/{{{prov}}}"
    os.makedirs(d, exist_ok=True)
    open(f"{d}/{nombre}.pdf", "wb").write(pdf(f"PRUEBA {tipo} {nombre}"))

for i in range(1, 61):
    crear("OrdenPago", P1, f"PAG-{i:04d}")
    crear("OrdenCompra", P1, f"ND-{i:04d}")
crear("OrdenPago", P2, "PAG-P2")
crear("OrdenCompra", P2, "ND-P2")
print("PDFs:", sum(len(f) for _, _, f in os.walk("share")))
PY
