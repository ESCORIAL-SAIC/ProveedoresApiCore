using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ProveedoresApiCore.Models;
using ProveedoresApiCore.Models.Dtos;

namespace ProveedoresApiCore.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class OrdenesPagoController(
        ProveedoresContext context, ILogger<OrdenesPagoController> log) : ControllerBase
    {
        private static readonly string[] Ordenables = ["fecha", "numero", "importe"];

        // Reemplaza los 4 métodos casi idénticos de OrdenPagoController: sólo cambiaba
        // el WHERE, así que los filtros pasan a ser query string opcionales.
        [HttpGet("{proveedorId}")]
        public async Task<IActionResult> GetOrdenesPago(
            Guid proveedorId, string? buscar = null, string? orden = null, string? factura = null)
        {
            var c = Consulta.Leer(Request.Query, Ordenables, out var error);
            if (c is null) return BadRequest(error);
            try
            {
                var q = context.OrdenesPago.Where(p => p.ProveedorId == proveedorId);

                if (c.Desde is { } desde) q = q.Where(p => p.Fecha >= desde);
                if (c.HastaFin is { } fin) q = q.Where(p => p.Fecha < fin);

                if (!string.IsNullOrWhiteSpace(orden))
                    q = q.Where(p => EF.Functions.ILike(p.OrdenPago!, $"%{orden}%"));

                if (!string.IsNullOrWhiteSpace(factura))
                    q = q.Where(p => EF.Functions.ILike(p.Factura!, $"%{factura}%"));

                if (!string.IsNullOrWhiteSpace(buscar))
                    q = q.Where(p => EF.Functions.ILike(p.OrdenPago!, $"%{buscar}%")
                                  || EF.Functions.ILike(p.Factura!, $"%{buscar}%"));

                // La vista no tiene columna única: se desempata por las columnas que salen en el DTO.
                var pagos = await q.Paginar(f => (c.Ordenar switch
                    {
                        "numero" => f.OrdenarPor(p => p.NumeroPago, c.Desc),
                        "importe" => f.OrdenarPor(p => p.Importe, c.Desc),
                        _ => f.OrdenarPor(p => p.Fecha, c.Desc)
                    })
                    .ThenBy(p => p.NumeroPago).ThenBy(p => p.Factura).ThenBy(p => p.OrdenPago)
                    .ThenBy(p => p.Importe).ThenBy(p => p.Total).ThenBy(p => p.Proveedor), c, Response);

                return Ok(pagos.Select(MapToDto).ToList());
            }
            catch (Exception ex)
            {
                log.LogError(ex, "Error al obtener las ordenes de pago de {Proveedor}", proveedorId);
                return StatusCode(StatusCodes.Status500InternalServerError,
                    "Error al obtener las ordenes de pago.");
            }
        }

        private static OrdenPagoDto MapToDto(OrdenPagoVista p) =>
            new()
            {
                NumeroPago = p.NumeroPago ?? string.Empty,
                Fecha = Formato.Fecha(p.Fecha),
                Proveedor = p.Proveedor ?? string.Empty,
                Cuit = p.Cuit ?? string.Empty,
                NombreDocumento = p.OrdenPago ?? string.Empty,
                Factura = p.Factura ?? string.Empty,
                Importe = Formato.Importe(p.Importe),
                Total = Formato.Importe(p.Total),
                Moneda = p.Moneda ?? string.Empty,
                Cotizacion = Formato.Importe(p.Cotizacion)
            };
    }
}
