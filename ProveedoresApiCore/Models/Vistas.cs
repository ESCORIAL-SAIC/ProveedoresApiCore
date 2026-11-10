using System.ComponentModel.DataAnnotations.Schema;

namespace ProveedoresApiCore.Models;

// Las 5 vistas de solo lectura del esquema `web`. Se usan los tipos reales de la vista
// (DateTime, decimal) en vez de string: los controllers de EscorialAPI hacían
// DateTime.Parse(item[...].ToString()), o sea convertir a texto y volver a parsear,
// lo que depende de la cultura del proceso. Acá el valor llega tipado desde Npgsql.
// Los ids son uuid en la base; leerlos como string revienta en Npgsql.

public sealed class LoginVista
{
    [Column("proveedor_id")] public Guid ProveedorId { get; set; }
    [Column("usuario")] public string Usuario { get; set; } = string.Empty;
    [Column("clave")] public string Clave { get; set; } = string.Empty;
}

public sealed class OrdenCompraVista
{
    [Column("proveedor_id")] public Guid ProveedorId { get; set; }
    [Column("transaccion_id")] public Guid TransaccionId { get; set; }
    [Column("numerodocumento")] public string? NumeroDocumento { get; set; }
    [Column("transaccion")] public string? Transaccion { get; set; }
    [Column("proveedor")] public string? Proveedor { get; set; }
    [Column("fechatransaccion")] public DateTime? FechaTransaccion { get; set; }
}

public sealed class ItemOrdenCompraVista
{
    [Column("transaccion_id")] public Guid TransaccionId { get; set; }
    [Column("codigoproducto")] public string? CodigoProducto { get; set; }
    [Column("descripcionproducto")] public string? DescripcionProducto { get; set; }
    [Column("cantidadpendiente")] public decimal? CantidadPendiente { get; set; }
    [Column("fechaestimada")] public DateTime? FechaEstimada { get; set; }
}

public sealed class OrdenPagoVista
{
    [Column("proveedor_id")] public Guid ProveedorId { get; set; }
    [Column("numeropago")] public string? NumeroPago { get; set; }
    [Column("fecha")] public DateTime? Fecha { get; set; }
    [Column("proveedor")] public string? Proveedor { get; set; }
    [Column("cuit")] public string? Cuit { get; set; }
    [Column("ordenpago")] public string? OrdenPago { get; set; }
    [Column("factura")] public string? Factura { get; set; }
    [Column("importe")] public decimal? Importe { get; set; }
    [Column("total")] public decimal? Total { get; set; }
    [Column("moneda")] public string? Moneda { get; set; }
    [Column("cotizacion")] public decimal? Cotizacion { get; set; }
}

public sealed class FacturaPendienteVista
{
    [Column("proveedor_id")] public Guid ProveedorId { get; set; }
    [Column("fechafactura")] public DateTime? FechaFactura { get; set; }
    [Column("nrofactura")] public string? NroFactura { get; set; }
    [Column("tipotransaccion")] public string? TipoTransaccion { get; set; }
    [Column("proveedor")] public string? Proveedor { get; set; }
    [Column("moneda")] public string? Moneda { get; set; }
    [Column("total")] public decimal? Total { get; set; }
    [Column("saldo")] public decimal? Saldo { get; set; }
    [Column("fechavencimiento")] public DateTime? FechaVencimiento { get; set; }
    [Column("saldoconv")] public decimal? SaldoConv { get; set; }
    [Column("cotizacion")] public string? Cotizacion { get; set; }
}
