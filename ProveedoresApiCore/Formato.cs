using System.Globalization;

namespace ProveedoresApiCore;

// Centraliza el formateo que en EscorialAPI estaba repetido en cada controller.
public static class Formato
{
    // Cultura fija: los controllers viejos usaban la del proceso, así que el mismo dato
    // salía distinto según dónde corriera la API (y distinto todavía bajo LANG=C).
    private static readonly CultureInfo Ar = CultureInfo.GetCultureInfo("es-AR");

    public static string Fecha(DateTime? d) => d?.ToString("dd/MM/yyyy", Ar) ?? string.Empty;

    public static string Importe(decimal? d) => d?.ToString("C2", Ar) ?? string.Empty;

    // Cantidades sin símbolo de moneda.
    public static string Numero(decimal? d) => d?.ToString("0.##", Ar) ?? string.Empty;

    // El original era "dd/MM/yyyy hh:MM:ss": MM en posición de minutos imprime el mes,
    // y hh es 12 horas sin AM/PM. A las 14:37 del 3 de marzo daba "03/03/2026 02:03:45".
    public static string Ahora() => DateTime.Now.ToString("dd/MM/yyyy HH:mm:ss", Ar);

    public static void SelfCheck()
    {
        var fecha = new DateTime(2026, 3, 3, 14, 37, 45);
        Assert(Fecha(fecha) == "03/03/2026", $"Fecha: {Fecha(fecha)}");
        Assert(Fecha(null) == string.Empty, "Fecha(null) debería ser vacío");

        // Formato argentino: punto para miles, coma para decimales.
        Assert(Importe(1234.5m).Contains("1.234,50"), $"Importe: {Importe(1234.5m)}");
        Assert(Importe(null) == string.Empty, "Importe(null) debería ser vacío");

        Assert(Numero(10m) == "10", $"Numero(10): {Numero(10m)}");
        Assert(Numero(10.5m) == "10,5", $"Numero(10.5): {Numero(10.5m)}");
        Assert(Numero(null) == string.Empty, "Numero(null) debería ser vacío");

        // El bug que se corrige: con "hh:MM:ss" acá aparecería el mes (03) como minutos.
        var ahora = fecha.ToString("dd/MM/yyyy HH:mm:ss", Ar);
        Assert(ahora == "03/03/2026 14:37:45", $"Ahora: {ahora}");

        Console.WriteLine("self-check OK");
    }

    private static void Assert(bool cond, string mensaje)
    {
        if (!cond) throw new Exception("self-check FALLÓ: " + mensaje);
    }
}
