using Microsoft.EntityFrameworkCore;

namespace ProveedoresApiCore.Models;

public sealed class ProveedoresContext(DbContextOptions<ProveedoresContext> options) : DbContext(options)
{
    public DbSet<LoginVista> Logins => Set<LoginVista>();
    public DbSet<OrdenCompraVista> OrdenesCompra => Set<OrdenCompraVista>();
    public DbSet<ItemOrdenCompraVista> ItemsOrdenCompra => Set<ItemOrdenCompraVista>();
    public DbSet<OrdenPagoVista> OrdenesPago => Set<OrdenPagoVista>();
    public DbSet<FacturaPendienteVista> FacturasPendientes => Set<FacturaPendienteVista>();

    protected override void OnModelCreating(ModelBuilder b)
    {
        // Vistas de solo lectura sin PK: con HasNoKey EF Core nunca intenta escribirlas.
        b.HasDefaultSchema("web");
        b.Entity<LoginVista>().HasNoKey().ToView("api_portalproveedores_login");
        b.Entity<OrdenCompraVista>().HasNoKey().ToView("api_portalproveedores_ordenescompra");
        b.Entity<ItemOrdenCompraVista>().HasNoKey().ToView("api_portalproveedores_itemsordenescompra");
        b.Entity<OrdenPagoVista>().HasNoKey().ToView("api_portalproveedores_pagos");
        b.Entity<FacturaPendienteVista>().HasNoKey().ToView("api_portalproveedores_facturaspendientes");
    }
}
