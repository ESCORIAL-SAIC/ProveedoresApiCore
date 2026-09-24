using System.Reflection;
using System.Text.Json;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using ProveedoresApiCore;
using ProveedoresApiCore.Models;

// Corre los asserts de Formato sin levantar el host: `dotnet run -- --self-check`.
if (args.Contains("--self-check"))
{
    try { Formato.SelfCheck(); return 0; }
    catch (Exception ex) { Console.Error.WriteLine(ex.Message); return 1; }
}

var builder = WebApplication.CreateBuilder(args);

builder.Configuration
    .SetBasePath(Directory.GetCurrentDirectory())
    .AddJsonFile("appsettings.json", optional: true, reloadOnChange: true)
    .AddJsonFile($"appsettings.{builder.Environment.EnvironmentName}.json", optional: true, reloadOnChange: true);

// Falla acá con un mensaje claro, en vez de una excepción de Npgsql en el primer request.
var conexion = builder.Configuration.GetConnectionString("Proveedores");
if (string.IsNullOrWhiteSpace(conexion))
    throw new InvalidOperationException(
        "Falta ConnectionStrings:Proveedores. Definila en appsettings.json (no versionado) " +
        "o por la variable de entorno ConnectionStrings__Proveedores.");

builder.Services.AddDbContext<ProveedoresContext>(o => o.UseNpgsql(conexion));

// EscorialAPI responde Access-Control-Allow-Origin: * para todo (Global.asax.cs:20).
// Acá se acota a los orígenes configurados: el único consumidor es el portal.
var origenes = builder.Configuration.GetSection("Cors:Origenes").Get<string[]>() ?? [];
builder.Services.AddCors(o => o.AddDefaultPolicy(p =>
    p.WithOrigins(origenes).AllowAnyHeader().WithMethods("GET", "POST")));

// PascalCase como el Newtonsoft de EscorialAPI: el default de ASP.NET Core es
// camelCase y cambiaría los nombres de campo que ya consumen los clientes.
// readiness toca la base; liveness no (ver los endpoints más abajo).
builder.Services.AddHealthChecks()
    .AddDbContextCheck<ProveedoresContext>("db", tags: ["ready"]);

builder.Services.AddControllers()
    .AddJsonOptions(o => o.JsonSerializerOptions.PropertyNamingPolicy = null);
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseCors();

// La versión la inyecta MinVer en build (o /p:MinVerVersionOverride en el CI).
// El sufijo "+metadata" del InformationalVersion no aporta acá.
var version = Assembly.GetExecutingAssembly()
    .GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion
    ?.Split('+')[0] ?? "0.0.0";

app.MapGet("/version", () => Results.Ok(new { Version = version }));

// Liveness: el proceso está vivo. No consulta dependencias, así que una base
// caída no debe reiniciar el container.
app.MapHealthChecks("/health/live", new HealthCheckOptions { Predicate = _ => false });

// Readiness: listo para recibir tráfico, o sea con la base accesible.
app.MapHealthChecks("/health/ready", new HealthCheckOptions
{
    Predicate = r => r.Tags.Contains("ready"),
    ResponseWriter = async (ctx, report) =>
    {
        ctx.Response.ContentType = "application/json";
        await ctx.Response.WriteAsync(JsonSerializer.Serialize(new
        {
            status = report.Status.ToString(),
            version,
            checks = report.Entries.Select(e => new
            {
                name = e.Key,
                status = e.Value.Status.ToString(),
                description = e.Value.Description
            })
        }));
    }
});

app.MapControllers();

app.Run();
return 0;
