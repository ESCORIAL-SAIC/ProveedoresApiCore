using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ProveedoresApiCore.Models;
using ProveedoresApiCore.Models.Dtos;

namespace ProveedoresApiCore.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class OrdenesCompraController(
        ProveedoresContext context, ILogger<OrdenesCompraController> log) : ControllerBase
    {
        [HttpGet("{proveedorId}")]
        public async Task<IActionResult> GetOrdenesCompra(Guid proveedorId, string? buscar = null)
        {
            try
            {
                var q = context.OrdenesCompra.Where(o => o.ProveedorId == proveedorId);

                // EF.Functions.ILike genera el ILIKE de PostgreSQL con el valor
                // parametrizado: la interpolación la traduce EF, no se concatena al SQL.
                if (!string.IsNullOrWhiteSpace(buscar))
                    q = q.Where(o => EF.Functions.ILike(o.Transaccion!, $"%{buscar}%"));

                var ordenes = await q
                    .OrderByDescending(o => o.Transaccion)
                    .Take(50)
                    .ToListAsync();

                return Ok(ordenes.Select(MapToDto).ToList());
            }
            catch (Exception ex)
            {
                log.LogError(ex, "Error al obtener las ordenes de compra de {Proveedor}", proveedorId);
                return StatusCode(StatusCodes.Status500InternalServerError,
                    "Error al obtener las ordenes de compra.");
            }
        }

        // La ruta vieja era .../item/lista/proveedor/{id}, pero el parámetro nunca fue
        // un proveedor: filtra por transaccion_id. La ruta nueva lo refleja.
        [HttpGet("{transaccionId}/items")]
        public async Task<IActionResult> GetItems(Guid transaccionId)
        {
            try
            {
                var items = await context.ItemsOrdenCompra
                    .Where(i => i.TransaccionId == transaccionId)
                    .OrderByDescending(i => i.CodigoProducto)
                    .Take(50)
                    .ToListAsync();

                return Ok(items.Select(MapItemToDto).ToList());
            }
            catch (Exception ex)
            {
                log.LogError(ex, "Error al obtener los items de la transaccion {Transaccion}", transaccionId);
                return StatusCode(StatusCodes.Status500InternalServerError,
                    "Error al obtener los items de la orden de compra.");
            }
        }

        private static OrdenCompraDto MapToDto(OrdenCompraVista o) =>
            new()
            {
                Id = o.TransaccionId.ToString(),
                NumeroDocumento = o.NumeroDocumento ?? string.Empty,
                Transaccion = o.Transaccion ?? string.Empty,
                NombreProveedor = o.Proveedor ?? string.Empty,
                FechaTransaccion = Formato.Fecha(o.FechaTransaccion)
            };

        private static ItemOrdenCompraDto MapItemToDto(ItemOrdenCompraVista i) =>
            new()
            {
                Id = i.TransaccionId.ToString(),
                CodigoProducto = i.CodigoProducto ?? string.Empty,
                DescripcionProducto = i.DescripcionProducto ?? string.Empty,
                CantidadPendiente = Formato.Numero(i.CantidadPendiente),
                FechaEstimada = Formato.Fecha(i.FechaEstimada)
            };
    }
}
