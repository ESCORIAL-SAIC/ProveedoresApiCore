using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ProveedoresApiCore.Models;
using ProveedoresApiCore.Models.Dtos;

namespace ProveedoresApiCore.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class FacturasPendientesController(
        ProveedoresContext context, ILogger<FacturasPendientesController> log) : ControllerBase
    {
        private static readonly string[] Ordenables = ["fecha", "vencimiento", "saldo"];

        // Parámetros opcionales: pagina, tamano, desde, hasta (sobre fechavencimiento), ordenar, dir.
        [HttpGet("{proveedorId}")]
        public async Task<IActionResult> GetFacturasPendientes(Guid proveedorId)
        {
            var c = Consulta.Leer(Request.Query, Ordenables, out var error);
            if (c is null) return BadRequest(error);
            try
            {
                var q = context.FacturasPendientes.Where(f => f.ProveedorId == proveedorId);

                if (c.Desde is { } desde) q = q.Where(f => f.FechaVencimiento >= desde);
                if (c.HastaFin is { } fin) q = q.Where(f => f.FechaVencimiento < fin);

                // La vista no tiene columna única: se desempata por las columnas que salen en el DTO.
                var facturas = await q.Paginar(f => (c.Ordenar switch
                    {
                        "vencimiento" => f.OrdenarPor(x => x.FechaVencimiento, c.Desc),
                        "saldo" => f.OrdenarPor(x => x.SaldoConv, c.Desc),
                        _ => f.OrdenarPor(x => x.FechaFactura, c.Desc)
                    })
                    .ThenBy(x => x.NroFactura).ThenBy(x => x.TipoTransaccion).ThenBy(x => x.Total)
                    .ThenBy(x => x.Saldo).ThenBy(x => x.FechaVencimiento).ThenBy(x => x.Moneda)
                    .ThenBy(x => x.Proveedor), c, Response);

                // Lista vacía devuelve 200 [], no 404: el portal trata "sin resultados"
                // y "no existe" igual, y un 404 lo obligaría a distinguirlos.
                return Ok(facturas.Select(MapToDto).ToList());
            }
            catch (Exception ex)
            {
                log.LogError(ex, "Error al obtener las facturas pendientes de {Proveedor}", proveedorId);
                return StatusCode(StatusCodes.Status500InternalServerError,
                    "Error al obtener las facturas pendientes.");
            }
        }

        private static FacturaPendienteDto MapToDto(FacturaPendienteVista f) =>
            new()
            {
                FechaFactura = Formato.Fecha(f.FechaFactura),
                NumeroFactura = f.NroFactura ?? string.Empty,
                TipoTransaccion = f.TipoTransaccion ?? string.Empty,
                Proveedor = f.Proveedor ?? string.Empty,
                Moneda = f.Moneda ?? string.Empty,
                Total = Formato.Importe(f.Total),
                Saldo = Formato.Importe(f.Saldo),
                FechaVencimiento = Formato.Fecha(f.FechaVencimiento),
                SaldoConvertido = Formato.Importe(f.SaldoConv),
                Cotizacion = Formato.CotizacionTexto(f.Cotizacion),
                FechaActualizacion = Formato.Ahora()
            };
    }
}
