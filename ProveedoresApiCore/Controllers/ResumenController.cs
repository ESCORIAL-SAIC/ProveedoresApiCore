using System.ComponentModel.DataAnnotations.Schema;
using System.Globalization;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace ProveedoresApiCore.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class ResumenController(Models.ProveedoresContext context, ILogger<ResumenController> log) : ControllerBase
    {
        [HttpGet("{proveedorId}")]
        public async Task<IActionResult> GetResumen(Guid proveedorId)
        {
            try
            {
                var hoy = HoyArgentina();
                var desde = new DateOnly(hoy.Year, hoy.Month, 1).AddMonths(-5);
                var finMes = desde.AddMonths(6);   // exclusivo: primer día del mes siguiente al actual
                var en7 = hoy.AddDays(7);

                // Una sola consulta, sólo SELECT sobre las vistas del esquema web. Los números llegan
                // crudos (sin Formato). ocpendientes cuenta igual que el listado de OC: una fila por OC
                // de la vista (que ya filtra las que tienen algún item pendiente).
                var r = (await context.Database.SqlQuery<ResumenFila>($"""
                    select
                      (select count(*) from web.api_portalproveedores_ordenescompra
                        where proveedor_id = {proveedorId}) as ocpendientes,
                      f.abiertas, f.saldototal, f.vencidas, f.porvencer7, f.sinvencimiento,
                      (select coalesce(json_agg(json_build_object('mes', m.mes, 'cantidad', m.cant) order by m.mes), '[]'::json)::text
                         from (select to_char(fecha, 'YYYY-MM') as mes, count(distinct numeropago) as cant
                                 from web.api_portalproveedores_pagos
                                where proveedor_id = {proveedorId} and fecha >= {desde} and fecha < {finMes}
                                group by 1) m) as pagos
                    from (select count(*) as abiertas,
                                 coalesce(sum(saldoconv), 0) as saldototal,
                                 count(*) filter (where fechavencimiento < {hoy}) as vencidas,
                                 count(*) filter (where fechavencimiento >= {hoy} and fechavencimiento <= {en7}) as porvencer7,
                                 count(*) filter (where fechavencimiento is null) as sinvencimiento
                            from web.api_portalproveedores_facturaspendientes
                           where proveedor_id = {proveedorId}) f
                    """).ToListAsync()).Single();

                var porMes = JsonSerializer.Deserialize<List<PagosMes>>(r.Pagos ?? "[]") ?? [];

                // Siempre 6 entradas, de la más vieja a la actual, con 0 en los meses sin pagos.
                var meses = Enumerable.Range(0, 6)
                    .Select(i => desde.AddMonths(i).ToString("yyyy-MM", CultureInfo.InvariantCulture))
                    .Select(m => new PagosMes(m, porMes.FirstOrDefault(p => p.Mes == m)?.Cantidad ?? 0))
                    .ToList();

                return Ok(new ResumenDto(
                    r.OcPendientes, r.Abiertas, r.SaldoTotal, r.Vencidas, r.PorVencer7, r.SinVencimiento, meses));
            }
            catch (Exception ex)
            {
                log.LogError(ex, "Error al obtener el resumen de {Proveedor}", proveedorId);
                return StatusCode(StatusCodes.Status500InternalServerError, "Error al obtener el resumen.");
            }
        }

        // "Hoy" en Buenos Aires. Si la imagen no trae tzdata cae a UTC-3 fijo (Argentina no tiene horario de verano).
        public static DateOnly HoyArgentina(DateTime? utcAhora = null)
        {
            var utc = utcAhora ?? DateTime.UtcNow;
            try
            {
                var tz = TimeZoneInfo.FindSystemTimeZoneById("America/Argentina/Buenos_Aires");
                return DateOnly.FromDateTime(TimeZoneInfo.ConvertTimeFromUtc(utc, tz));
            }
            catch (TimeZoneNotFoundException)
            {
                return DateOnly.FromDateTime(utc.AddHours(-3));
            }
        }

        private sealed class ResumenFila
        {
            [Column("ocpendientes")] public long OcPendientes { get; set; }
            [Column("abiertas")] public long Abiertas { get; set; }
            [Column("saldototal")] public decimal SaldoTotal { get; set; }
            [Column("vencidas")] public long Vencidas { get; set; }
            [Column("porvencer7")] public long PorVencer7 { get; set; }
            [Column("sinvencimiento")] public long SinVencimiento { get; set; }
            [Column("pagos")] public string? Pagos { get; set; }
        }
    }

    // camelCase explícito: el resumen sigue el pedido del portal; el resto de la API sigue en PascalCase.
    public sealed record PagosMes(
        [property: JsonPropertyName("mes")] string Mes,
        [property: JsonPropertyName("cantidad")] int Cantidad);

    public sealed record ResumenDto(
        [property: JsonPropertyName("ocPendientes")] long OcPendientes,
        [property: JsonPropertyName("facturasAbiertas")] long FacturasAbiertas,
        [property: JsonPropertyName("saldoTotal")] decimal SaldoTotal,
        [property: JsonPropertyName("facturasVencidas")] long FacturasVencidas,
        [property: JsonPropertyName("facturasPorVencer7")] long FacturasPorVencer7,
        [property: JsonPropertyName("facturasSinVencimiento")] long FacturasSinVencimiento,
        [property: JsonPropertyName("pagosUltimos6Meses")] List<PagosMes> PagosUltimos6Meses);
}
