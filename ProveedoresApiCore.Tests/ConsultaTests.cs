using Microsoft.AspNetCore.Http;
using ProveedoresApiCore;
using ProveedoresApiCore.Controllers;

namespace ProveedoresApiCore.Tests;

public class ConsultaTests
{
    private static readonly string[] Ord = ["fecha", "saldo"];

    private static Consulta? Leer(string qs, out string? error) =>
        Consulta.Leer(new QueryCollection(Microsoft.AspNetCore.WebUtilities.QueryHelpers.ParseQuery(qs)), Ord, out error);

    [Fact]
    public void Sin_parametros_es_pagina_1_de_50_descendente()
    {
        var c = Leer("", out var e)!;
        Assert.Null(e);
        Assert.Equal((1, 50, 0, true, null), (c.Pagina, c.Tamano, c.Skip, c.Desc, c.Ordenar));
    }

    [Theory]
    [InlineData("tamano=500", 200)]
    [InlineData("tamano=200", 200)]
    [InlineData("tamano=199", 199)]
    [InlineData("tamano=99999999999999999999", 200)]
    public void Tamano_se_recorta_a_200(string qs, int esperado) =>
        Assert.Equal(esperado, Leer(qs, out _)!.Tamano);

    [Theory]
    [InlineData("pagina=0")] [InlineData("pagina=-1")] [InlineData("pagina=abc")] [InlineData("pagina=")]
    [InlineData("pagina=1.5")] [InlineData("pagina=%2B1")] [InlineData("tamano=0")] [InlineData("tamano=-5")]
    [InlineData("tamano=x")] [InlineData("desde=2025-13-01")] [InlineData("desde=01/02/2025")]
    [InlineData("desde=2025-1-1")] [InlineData("hasta=hoy")] [InlineData("ordenar=zzz")] [InlineData("dir=arriba")]
    public void Valores_invalidos_dan_null_con_mensaje(string qs)
    {
        Assert.Null(Leer(qs, out var e));
        Assert.False(string.IsNullOrEmpty(e));
    }

    [Fact]
    public void Skip_de_pagina_enorme_no_desborda() =>
        Assert.Equal(int.MaxValue, Leer("pagina=2147483647&tamano=200", out _)!.Skip);

    [Fact]
    public void Hasta_es_inclusivo_hasta_el_fin_del_dia()
    {
        var c = Leer("desde=2025-01-02&hasta=2025-01-04", out _)!;
        Assert.Equal(new DateTime(2025, 1, 2), c.Desde);
        Assert.Equal(new DateTime(2025, 1, 5), c.HastaFin);
    }

    [Fact]
    public void Ordenar_y_dir_no_distinguen_mayusculas()
    {
        var c = Leer("ordenar=SALDO&dir=ASC", out _)!;
        Assert.Equal(("saldo", false), (c.Ordenar, c.Desc));
    }

    [Fact]
    public void Hoy_en_buenos_aires_usa_utc_menos_3()
    {
        // 02:00 UTC del 1/3 todavía es 28/2 (23:00) en Buenos Aires.
        Assert.Equal(new DateOnly(2026, 2, 28), ResumenController.HoyArgentina(new DateTime(2026, 3, 1, 2, 0, 0, DateTimeKind.Utc)));
        Assert.Equal(new DateOnly(2026, 3, 1), ResumenController.HoyArgentina(new DateTime(2026, 3, 1, 3, 0, 0, DateTimeKind.Utc)));
    }
}
