using ProveedoresApiCore;

namespace ProveedoresApiCore.Tests;

public class FormatoTests
{
    [Fact]
    public void Fecha_usa_dia_mes_anio()
        => Assert.Equal("03/03/2026", Formato.Fecha(new DateTime(2026, 3, 3, 14, 37, 45)));

    [Fact]
    public void Fecha_nula_es_vacia()
        => Assert.Equal(string.Empty, Formato.Fecha(null));

    [Fact]
    public void Importe_usa_formato_argentino()
        => Assert.Contains("1.234,50", Formato.Importe(1234.5m));

    [Fact]
    public void Importe_nulo_es_vacio()
        => Assert.Equal(string.Empty, Formato.Importe(null));

    [Theory]
    [InlineData(10, "10")]
    [InlineData(10.5, "10,5")]
    [InlineData(10.125, "10,125")]   // la vista redondea a 3 decimales
    public void Numero_usa_coma_decimal(double valor, string esperado)
        => Assert.Equal(esperado, Formato.Numero((decimal)valor));

    [Fact]
    public void Numero_nulo_es_vacio()
        => Assert.Equal(string.Empty, Formato.Numero(null));

    [Fact]
    public void Ahora_tiene_formato_24_horas_con_segundos()
        => Assert.Matches(@"^\d{2}/\d{2}/\d{4} \d{2}:\d{2}:\d{2}$", Formato.Ahora());

    [Fact]
    public void CotizacionTexto_numerica_se_formatea_como_importe()
        => Assert.Contains("1,00", Formato.CotizacionTexto("1"));

    [Fact]
    public void CotizacionTexto_compuesta_pasa_tal_cual()
        => Assert.Equal("1234.00  -  (2026-06-30)", Formato.CotizacionTexto("1234.00  -  (2026-06-30)"));

    [Fact]
    public void CotizacionTexto_nula_es_vacia()
        => Assert.Equal(string.Empty, Formato.CotizacionTexto(null));
}
