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
        [HttpGet("{proveedorId}")]
        public async Task<IActionResult> GetFacturasPendientes(string proveedorId)
        {
            try
            {
                var facturas = await context.FacturasPendientes
                    .Where(f => f.ProveedorId == proveedorId)
                    .OrderByDescending(f => f.FechaFactura)
                    .Take(50)
                    .ToListAsync();

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
                Cotizacion = Formato.Importe(f.Cotizacion),
                FechaActualizacion = Formato.Ahora()
            };
    }
}
