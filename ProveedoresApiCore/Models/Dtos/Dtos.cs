namespace ProveedoresApiCore.Models.Dtos;

// Todos los campos son string con los mismos nombres que exponía EscorialAPI:
// el portal deserializa contra estos nombres y no debe requerir cambios.

public sealed class LoginRequest
{
    public string User { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
}

public sealed class OrdenCompraDto
{
    public string Id { get; set; } = string.Empty;
    public string NumeroDocumento { get; set; } = string.Empty;
    public string Transaccion { get; set; } = string.Empty;
    public string NombreProveedor { get; set; } = string.Empty;
    public string FechaTransaccion { get; set; } = string.Empty;
}

public sealed class ItemOrdenCompraDto
{
    public string Id { get; set; } = string.Empty;
    public string CodigoProducto { get; set; } = string.Empty;
    public string DescripcionProducto { get; set; } = string.Empty;
    public string CantidadPendiente { get; set; } = string.Empty;
    public string FechaEstimada { get; set; } = string.Empty;
}

public sealed class OrdenPagoDto
{
    public string NumeroPago { get; set; } = string.Empty;
    public string Fecha { get; set; } = string.Empty;
    public string Proveedor { get; set; } = string.Empty;
    public string Cuit { get; set; } = string.Empty;
    public string NombreDocumento { get; set; } = string.Empty;
    public string Factura { get; set; } = string.Empty;
    public string Importe { get; set; } = string.Empty;
    public string Total { get; set; } = string.Empty;
    public string Moneda { get; set; } = string.Empty;
    public string Cotizacion { get; set; } = string.Empty;
}

public sealed class FacturaPendienteDto
{
    public string FechaFactura { get; set; } = string.Empty;
    public string NumeroFactura { get; set; } = string.Empty;
    public string TipoTransaccion { get; set; } = string.Empty;
    public string Proveedor { get; set; } = string.Empty;
    public string Moneda { get; set; } = string.Empty;
    public string Total { get; set; } = string.Empty;
    public string Saldo { get; set; } = string.Empty;
    public string FechaVencimiento { get; set; } = string.Empty;
    public string SaldoConvertido { get; set; } = string.Empty;
    public string Cotizacion { get; set; } = string.Empty;
    public string FechaActualizacion { get; set; } = string.Empty;
}
