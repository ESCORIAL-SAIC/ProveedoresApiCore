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
            // Un NUL en el texto hace fallar a Postgres con 500; no puede ser una credencial válida.
            if (datosLogin.User.Contains('\0') || datosLogin.Password.Contains('\0'))
                return Unauthorized();
            try
            {
                // EF Core parametriza la comparación. El controller de EscorialAPI
                // concatenaba usuario y clave en el SQL, así que un usuario
                // "' or '1'='1' --" entraba como cualquier proveedor sin credenciales.
                // Guid? porque proveedor_id es uuid: FirstOrDefault de un Guid devolvería
                // Guid.Empty y no habría forma de distinguir "sin coincidencias".
                var proveedorId = await context.Logins
                    .Where(l => l.Usuario == datosLogin.User && l.Clave == datosLogin.Password)
                    .Select(l => (Guid?)l.ProveedorId)
                    .FirstOrDefaultAsync();

                if (proveedorId is null)
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
