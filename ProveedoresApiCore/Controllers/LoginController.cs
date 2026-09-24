using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ProveedoresApiCore.Models;
using ProveedoresApiCore.Models.Dtos;

namespace ProveedoresApiCore.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class LoginController(ProveedoresContext context, ILogger<LoginController> log) : ControllerBase
    {
        [HttpPost]
        public async Task<IActionResult> PostLogin([FromBody] LoginRequest? datosLogin)
        {
            if (datosLogin is null)
                return BadRequest("Faltan las credenciales.");
            try
            {
                // EF Core parametriza la comparación. El controller de EscorialAPI
                // concatenaba usuario y clave en el SQL, así que un usuario
                // "' or '1'='1' --" entraba como cualquier proveedor sin credenciales.
                var proveedorId = await context.Logins
                    .Where(l => l.Usuario == datosLogin.User && l.Clave == datosLogin.Password)
                    .Select(l => l.ProveedorId)
                    .FirstOrDefaultAsync();

                if (string.IsNullOrEmpty(proveedorId))
                    return Unauthorized();

                return Ok(new { Status = "OK", Proveedor = proveedorId });
            }
            catch (Exception ex)
            {
                // El mensaje de la excepción se loguea, no se devuelve: filtraría
                // detalles de la base al cliente.
                log.LogError(ex, "Error al validar el login");
                return StatusCode(StatusCodes.Status500InternalServerError, "Error al validar el login.");
            }
        }
    }
}
