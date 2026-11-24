-- BASE DE PRUEBA SINTÉTICA. Nada de esto viene de producción.
-- Tipos y nombres de columna copiados del catálogo real (pg_attribute) del esquema web.
-- Las vistas reales dependen de v_trcompra, v_itemtr, etc.; acá cada vista lee una tabla
-- plana en el esquema `base`, que alcanza para probar tipos y comportamiento de la API.

create schema base;
create schema web;

create table base.login (
    proveedor_id uuid, usuario varchar(50), clave varchar(50), nombre varchar(100));

create table base.ordenescompra (
    transaccion_id uuid, numerodocumento varchar(20), transaccion varchar(100),
    proveedor varchar(100), fechatransaccion date, proveedor_id uuid);

create table base.itemsordenescompra (
    transaccion_id uuid, codigoproducto varchar(30), descripcionproducto varchar(150),
    cantidadpendiente numeric, fechaestimada date);

create table base.pagos (
    numeropago varchar(20), fecha date, proveedor varchar(100), cuit varchar(40),
    ordenpago varchar(60), factura varchar(130), importe numeric, total numeric,
    moneda varchar(40), cotizacion numeric(22,10), proveedor_id uuid);

create table base.facturaspendientes (
    fechafactura date, nrofactura varchar(20), tipotransaccion varchar(40),
    proveedor varchar(100), moneda varchar(40), total numeric(25,2), saldo numeric(25,2),
    fechavencimiento date, saldoconv numeric(25,2), cotizacion text, proveedor_id uuid);

create view web.api_portalproveedores_login as select * from base.login;
create view web.api_portalproveedores_ordenescompra as select * from base.ordenescompra;
create view web.api_portalproveedores_itemsordenescompra as select * from base.itemsordenescompra;
create view web.api_portalproveedores_pagos as select * from base.pagos;
create view web.api_portalproveedores_facturaspendientes as select * from base.facturaspendientes;

-- Proveedor 1: 11111111-..., proveedor 2: 22222222-...
insert into base.login values
 ('11111111-1111-1111-1111-111111111111', 'prov1', 'clave1', 'Proveedor Uno Ñandú S.A.'),
 ('22222222-2222-2222-2222-222222222222', 'prov2', 'clave2', 'Proveedor Dos S.R.L.');

-- Órdenes de compra: 60 del proveedor 1 (prueba limit 50), 2 del proveedor 2.
insert into base.ordenescompra
select md5('oc' || i)::uuid, 'ND-' || lpad(i::text, 4, '0'), 'OC-' || lpad(i::text, 4, '0'),
       'Proveedor Uno Ñandú S.A.', date '2026-01-01' + i, '11111111-1111-1111-1111-111111111111'
from generate_series(1, 60) i;
insert into base.ordenescompra values
 (md5('oc-esp')::uuid, 'ND-ESP', 'OC-ESP_100%', 'Proveedor Uno Ñandú S.A.', null, '11111111-1111-1111-1111-111111111111'),
 (md5('oc-p2-1')::uuid, 'ND-P2', 'OC-P2-0001', 'Proveedor Dos', date '2026-02-02', '22222222-2222-2222-2222-222222222222'),
 (md5('oc-p2-2')::uuid, null, null, null, null, '22222222-2222-2222-2222-222222222222');

-- Items de la OC 1: cantidades con 3 decimales, entera, nulos. Más 60 de la OC 2 (limit 50).
insert into base.itemsordenescompra values
 (md5('oc1')::uuid, 'PROD-A', 'Tornillo ñoño', 10.125, date '2026-03-01'),
 (md5('oc1')::uuid, 'PROD-B', 'Tuerca', 10.000, date '2026-03-02'),
 (md5('oc1')::uuid, 'PROD-C', null, 5, null),
 (md5('oc1')::uuid, 'PROD-D', 'Arandela', 0.5, date '2026-03-04');
insert into base.itemsordenescompra
select md5('oc2')::uuid, 'ITEM-' || lpad(i::text, 3, '0'), 'Item ' || i, i, date '2026-04-01' + i
from generate_series(1, 60) i;

-- Pagos: 60 del proveedor 1, uno con caracteres especiales, nulos; 2 del proveedor 2.
insert into base.pagos
select 'PAG-' || lpad(i::text, 4, '0'), date '2026-01-01' + i, 'Proveedor Uno Ñandú S.A.', '30-12345678-9',
       'OP-' || lpad(i::text, 4, '0'), 'FA-' || lpad(i::text, 4, '0'),
       1234.5 + i, 100000.75 + i, 'Pesos', 1.0000000000, '11111111-1111-1111-1111-111111111111'
from generate_series(1, 60) i;
insert into base.pagos values
 ('PAG-ESP', date '2026-05-05', null, null, 'OP_ñ%x', 'FA_ñ%x', null, null, null, null, '11111111-1111-1111-1111-111111111111'),
 ('PAG-P2', date '2026-05-06', 'Proveedor Dos', '30-99999999-1', 'OP-P2', 'FA-P2', 50, 50, 'Dolar', 1234.5678901234, '22222222-2222-2222-2222-222222222222');

-- Facturas pendientes: cotizacion es text. '1' en pesos, texto compuesto en moneda extranjera.
insert into base.facturaspendientes
select date '2026-01-01' + i, 'FAC-' || lpad(i::text, 4, '0'), 'Factura de compra', 'Proveedor Uno Ñandú S.A.',
       'Pesos', 1000.50 + i, 500.25 + i, date '2026-06-01' + i, 500.25 + i, '1',
       '11111111-1111-1111-1111-111111111111'
from generate_series(1, 60) i;
insert into base.facturaspendientes values
 (date '2026-07-01', 'FAC-USD', 'Factura de compra', 'Proveedor Uno Ñandú S.A.', 'Dolar', 100.00, 100.00,
  date '2026-08-01', 123400.00, '1234.00  -  (2026-06-30)', '11111111-1111-1111-1111-111111111111'),
 (date '2026-07-02', 'FAC-NULL', null, null, null, null, null, null, null, null, '11111111-1111-1111-1111-111111111111'),
 (date '2026-07-03', 'FAC-P2', 'Nota de credito', 'Proveedor Dos', 'Pesos', -50.00, -50.00,
  date '2026-08-03', -50.00, '1', '22222222-2222-2222-2222-222222222222');

-- Proveedor 3 (33333333-...): 250 filas por listado, para probar paginación y el tope de 200.
-- Las fechas se repiten de a 5 (i/5) a propósito: obligan al desempate del orden.
-- Cada 25 facturas una sin vencimiento (para probar que ?desde/?hasta la excluyen).
insert into base.ordenescompra
select md5('oc3-' || i)::uuid, 'ND3-' || lpad(i::text, 4, '0'), 'OC3-' || lpad(i::text, 4, '0'),
       'Proveedor Tres', date '2025-01-01' + (i / 5), '33333333-3333-3333-3333-333333333333'
from generate_series(1, 250) i;
insert into base.pagos
select 'PAG3-' || lpad(i::text, 4, '0'), date '2025-01-01' + (i / 5), 'Proveedor Tres', '30-33333333-3',
       'OP3-' || lpad(i::text, 4, '0'), 'FA3-' || lpad(i::text, 4, '0'),
       i, i * 10, 'Pesos', 1.0000000000, '33333333-3333-3333-3333-333333333333'
from generate_series(1, 250) i;
insert into base.facturaspendientes
select date '2025-01-01' + (i / 5), 'FAC3-' || lpad(i::text, 4, '0'), 'Factura de compra', 'Proveedor Tres',
       'Pesos', 1000 + i, i, case when i % 25 = 0 then null else date '2025-02-01' + (i / 5) end, i, '1',
       '33333333-3333-3333-3333-333333333333'
from generate_series(1, 250) i;

-- Proveedor 4 (44444444-...): fechas relativas a hoy, para probar el resumen sin depender del día.
-- La base corre en America/Argentina/Buenos_Aires, igual que el "hoy" de la API.
-- Facturas: 3 vencidas, 2 por vencer (hoy y hoy+7, ambos inclusivos), 1 a hoy+8 (ni vencida ni por vencer),
-- 1 sin vencimiento. Saldo total = 100+200+300+400+500+600+700.50 = 2800.50.
insert into base.facturaspendientes values
 (current_date - 40, 'FAC4-V1', 'Factura de compra', 'Proveedor Cuatro', 'Pesos', 100, 100, current_date - 30, 100, '1', '44444444-4444-4444-4444-444444444444'),
 (current_date - 30, 'FAC4-V2', 'Factura de compra', 'Proveedor Cuatro', 'Pesos', 200, 200, current_date - 10, 200, '1', '44444444-4444-4444-4444-444444444444'),
 (current_date - 20, 'FAC4-V3', 'Factura de compra', 'Proveedor Cuatro', 'Pesos', 300, 300, current_date - 1, 300, '1', '44444444-4444-4444-4444-444444444444'),
 (current_date - 10, 'FAC4-H0', 'Factura de compra', 'Proveedor Cuatro', 'Pesos', 400, 400, current_date, 400, '1', '44444444-4444-4444-4444-444444444444'),
 (current_date - 5,  'FAC4-H7', 'Factura de compra', 'Proveedor Cuatro', 'Pesos', 500, 500, current_date + 7, 500, '1', '44444444-4444-4444-4444-444444444444'),
 (current_date - 4,  'FAC4-H8', 'Factura de compra', 'Proveedor Cuatro', 'Pesos', 600, 600, current_date + 8, 600, '1', '44444444-4444-4444-4444-444444444444'),
 (current_date - 3,  'FAC4-NV', 'Factura de compra', 'Proveedor Cuatro', 'Pesos', 700.50, 700.50, null, 700.50, '1', '44444444-4444-4444-4444-444444444444');
insert into base.ordenescompra values
 (md5('oc4-1')::uuid, 'ND4-1', 'OC4-0001', 'Proveedor Cuatro', current_date - 5, '44444444-4444-4444-4444-444444444444'),
 (md5('oc4-2')::uuid, 'ND4-2', 'OC4-0002', 'Proveedor Cuatro', current_date - 2, '44444444-4444-4444-4444-444444444444');
-- Pagos por mes (día 15): mes actual 3 números distintos (uno repetido en 2 filas, o sea 4 filas),
-- mes -1: 1, mes -3: 2, mes -5: 1, mes -6: 5 (fuera de la ventana de 6 meses).
insert into base.pagos
select n, (date_trunc('month', current_date) - (m || ' month')::interval)::date + 14, 'Proveedor Cuatro', '30-44444444-4',
       'OP-' || n, f, 10, 10, 'Pesos', 1, '44444444-4444-4444-4444-444444444444'
from (values
  (0, 'P4-A', 'FA-1'), (0, 'P4-A', 'FA-2'), (0, 'P4-B', 'FA-3'), (0, 'P4-C', 'FA-4'),
  (1, 'P4-D', 'FA-5'),
  (3, 'P4-E', 'FA-6'), (3, 'P4-F', 'FA-7'),
  (5, 'P4-G', 'FA-8'),
  (6, 'P4-H1', 'FA-9'), (6, 'P4-H2', 'FA-10'), (6, 'P4-H3', 'FA-11'), (6, 'P4-H4', 'FA-12'), (6, 'P4-H5', 'FA-13')
) t(m, n, f);

-- Usuario de la API: sólo SELECT sobre las vistas, como pide DEPLOY.md.
create role api_test login password 'api_test';
grant usage on schema web to api_test;
grant select on all tables in schema web to api_test;
