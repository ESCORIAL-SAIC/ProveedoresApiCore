using System.Globalization;
using System.Linq.Expressions;
using Microsoft.EntityFrameworkCore;

namespace ProveedoresApiCore;

// Parámetros comunes de los listados: pagina, tamano, desde, hasta, ordenar, dir.
// Sin ninguno, el resultado es el de siempre: pagina 1, 50 filas, orden por defecto del listado.
public sealed record Consulta(int Pagina, int Tamano, DateTime? Desde, DateTime? Hasta, string? Ordenar, bool Desc)
{
    public const int TamanoPorDefecto = 50;
    public const int TamanoMaximo = 200;

    // Límite superior exclusivo de ?hasta (inclusivo = día completo). null = sin tope.
    public DateTime? HastaFin => Hasta is { } h && h < DateTime.MaxValue.Date ? h.AddDays(1) : null;

    public int Skip => (int)Math.Min((long)(Pagina - 1) * Tamano, int.MaxValue);

    // Devuelve null y el motivo en `error` si algún parámetro es inválido (el controller responde 400).
    // `ordenables`: los únicos valores aceptados en ?ordenar (lista fija, nunca se arma SQL con texto del cliente).
    public static Consulta? Leer(IQueryCollection q, string[] ordenables, out string? error)
    {
        error = null;
        var pagina = 1L;
        var tamano = (long)TamanoPorDefecto;

        if (q.ContainsKey("pagina") && !Positivo(q["pagina"].ToString(), out pagina))
            return Falla("pagina debe ser un entero mayor a 0.", out error);
        if (q.ContainsKey("tamano") && !Positivo(q["tamano"].ToString(), out tamano))
            return Falla("tamano debe ser un entero mayor a 0.", out error);

        DateTime? desde = null, hasta = null;
        if (q.ContainsKey("desde") && (desde = Fecha(q["desde"].ToString())) is null)
            return Falla("desde debe tener formato yyyy-MM-dd.", out error);
        if (q.ContainsKey("hasta") && (hasta = Fecha(q["hasta"].ToString())) is null)
            return Falla("hasta debe tener formato yyyy-MM-dd.", out error);

        string? ordenar = null;
        if (q.ContainsKey("ordenar"))
        {
            ordenar = q["ordenar"].ToString().ToLowerInvariant();
            if (!ordenables.Contains(ordenar))
                return Falla($"ordenar debe ser uno de: {string.Join(", ", ordenables)}.", out error);
        }

        // Sin ?dir se ordena descendente, como todos los listados desde siempre.
        var desc = true;
        if (q.ContainsKey("dir"))
        {
            var dir = q["dir"].ToString().ToLowerInvariant();
            if (dir is not ("asc" or "desc"))
                return Falla("dir debe ser asc o desc.", out error);
            desc = dir == "desc";
        }

        return new Consulta(
            (int)Math.Min(pagina, int.MaxValue), (int)Math.Min(tamano, TamanoMaximo),
            desde, hasta, ordenar, desc);
    }

    private static Consulta? Falla(string mensaje, out string? error)
    {
        error = mensaje;
        return null;
    }

    // Solo dígitos ASCII (rechaza "-1", "+1", " 1", "1,5", ""). Un número que no entra en long
    // se trata como long.MaxValue: tamano se recorta y pagina queda fuera de rango (lista vacía).
    private static bool Positivo(string s, out long valor)
    {
        valor = 0;
        if (s.Length == 0 || !s.All(char.IsAsciiDigit)) return false;
        valor = long.TryParse(s, NumberStyles.None, CultureInfo.InvariantCulture, out var v) ? v : long.MaxValue;
        return valor > 0;
    }

    private static DateTime? Fecha(string s) =>
        DateTime.TryParseExact(s, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var d) ? d : null;
}

public static class ConsultaExtensions
{
    public static IOrderedQueryable<T> OrdenarPor<T, TKey>(
        this IQueryable<T> q, Expression<Func<T, TKey>> clave, bool desc) =>
        desc ? q.OrderByDescending(clave) : q.OrderBy(clave);

    // Cuenta las filas del filtro (X-Total-Count), después trae sólo la página pedida.
    public static async Task<List<T>> Paginar<T>(
        this IQueryable<T> filtrada, Func<IQueryable<T>, IOrderedQueryable<T>> orden,
        Consulta c, HttpResponse res)
    {
        var total = await filtrada.CountAsync();
        res.Headers["X-Total-Count"] = total.ToString(System.Globalization.CultureInfo.InvariantCulture);
        if (c.Skip >= total) return [];
        return await orden(filtrada).Skip(c.Skip).Take(c.Tamano).ToListAsync();
    }
}
