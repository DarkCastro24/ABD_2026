-- Laboratorio 4 | Solución Grupo 8 - Northwind - Productos y Proveedores

-- Ejercicio 1 · Esquemas y secuencias
USE Northwind;
GO
CREATE SCHEMA Geografia AUTHORIZATION dbo;
GO
ALTER SCHEMA Geografia TRANSFER dbo.Region;
GO
SELECT s.name AS Esquema, t.name AS Tabla
FROM sys.tables AS t
JOIN sys.schemas AS s ON s.schema_id = t.schema_id
WHERE t.name = N'Region';
GO
CREATE SEQUENCE Geografia.seq_historial_zonas
    AS INT
    START WITH 10
    INCREMENT BY 10
    NO CYCLE
    CACHE 20;
GO
SELECT name, start_value, increment, is_cycling, is_cached, cache_size
FROM sys.sequences
WHERE name = N'seq_historial_zonas';
GO
CREATE TABLE Geografia.Historial (
    id_registro INT NOT NULL
        CONSTRAINT DF_Historial_id_registro DEFAULT (NEXT VALUE FOR Geografia.seq_historial_zonas),
    usuario VARCHAR(50) NOT NULL,
    fecha DATE NOT NULL,
    CONSTRAINT PK_Historial PRIMARY KEY (id_registro)
);
GO
INSERT INTO Geografia.Historial (usuario, fecha) VALUES ('logistica.admin', '20261026');
INSERT INTO Geografia.Historial (usuario, fecha) VALUES ('logistica.auditor', '20261027');
GO
SELECT id_registro, usuario, fecha
FROM Geografia.Historial;
GO
SELECT s.name AS Esquema, t.name AS Tabla
FROM sys.tables AS t
JOIN sys.schemas AS s ON s.schema_id = t.schema_id
WHERE s.name = N'Geografia';
GO

-- Ejercicio 2 · Índices y planes de ejecución
USE Northwind;
GO
SET STATISTICS IO ON;
GO
SELECT OrderID, ProductID, UnitPrice, Quantity
FROM dbo.[Order Details]
WHERE Quantity >= 130;
GO
-- Justificación: índice no agrupado. [Order Details] ya tiene su índice agrupado en la llave primaria
-- (OrderID, ProductID) y solo puede haber uno por tabla; cambiarlo obligaría a reconstruir la llave primaria
-- y los demás índices. Quantity no es única y solo 2 de 2,155 líneas tienen 130 unidades o más, así que un
-- índice no agrupado sobre Quantity basta para pasar a Index Seek. El plan pasa de Clustered Index Scan (11
-- lecturas) a Index Seek + Key Lookup (6 lecturas); el Key Lookup queda porque UnitPrice no está en el
-- índice. La mejora es pequeña porque la tabla completa se lee en 11 páginas.
CREATE NONCLUSTERED INDEX IX_OrderDetails_Quantity
ON dbo.[Order Details](Quantity);
GO
SELECT OrderID, ProductID, UnitPrice, Quantity
FROM dbo.[Order Details]
WHERE Quantity >= 130;
GO

-- Ejercicio 3 · Optimizando el Key Lookup con INCLUDE
USE Northwind;
GO
SET STATISTICS IO ON;
GO
SELECT UnitPrice, Quantity, Discount
FROM dbo.[Order Details]
WHERE ProductID = 38;
GO
-- Justificación: al inicio el motor usa un Clustered Index Scan (11 lecturas) y no el índice ProductID:
-- estima 24 filas, y un Index Seek con 24 Key Lookups leería más páginas que recorrer las 11 de la tabla
-- completa. Se reemplaza el índice ProductID con DROP_EXISTING = ON, conservando su nombre y su clave, en
-- lugar de crear un tercer índice sobre ProductID (la tabla ya tiene también ProductsOrder_Details sobre esa
-- columna). Con el índice cubierto ya no hace falta Key Lookup y el plan pasa a un único Index Seek (2
-- lecturas).
-- Columnas incluidas: UnitPrice, Quantity y Discount solo se devuelven en el SELECT; no se usan para filtrar
-- ni para ordenar, así que no necesitan formar parte de la clave. En INCLUDE se guardan solo en el nivel
-- hoja: la clave sigue angosta y el índice cubre la consulta sin Key Lookup.
CREATE NONCLUSTERED INDEX ProductID
ON dbo.[Order Details](ProductID)
INCLUDE (UnitPrice, Quantity, Discount)
WITH (DROP_EXISTING = ON);
GO
SELECT UnitPrice, Quantity, Discount
FROM dbo.[Order Details]
WHERE ProductID = 38;
GO

-- Ejercicio 4 · Análisis de JOINs y rendimiento
USE Northwind;
GO
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO
SELECT s.Country, s.CompanyName, cat.CategoryName, SUM(od.Quantity) AS Unidades
FROM dbo.Suppliers AS s
JOIN dbo.Products AS p ON p.SupplierID = s.SupplierID
JOIN dbo.Categories AS cat ON cat.CategoryID = p.CategoryID
JOIN dbo.[Order Details] AS od ON od.ProductID = p.ProductID
WHERE p.Discontinued = 0
GROUP BY s.Country, s.CompanyName, cat.CategoryName
ORDER BY Unidades DESC;
GO
-- Justificación del índice: los operadores más costosos son los Hash Match de las uniones (unos 19% cada
-- uno), empezando por el de Products con [Order Details], que recorre las 2,155 líneas con un Clustered Index
-- Scan. El índice usa la columna de unión (ProductID) como clave e incluye Quantity, la otra columna que se
-- usa (se suma), así el motor puede buscar directamente las líneas de cada producto vigente.
CREATE NONCLUSTERED INDEX IX_OrderDetails_ProductID_Quantity
ON dbo.[Order Details](ProductID)
INCLUDE (Quantity);
GO
SELECT s.Country, s.CompanyName, cat.CategoryName, SUM(od.Quantity) AS Unidades
FROM dbo.Suppliers AS s
JOIN dbo.Products AS p ON p.SupplierID = s.SupplierID
JOIN dbo.Categories AS cat ON cat.CategoryID = p.CategoryID
JOIN dbo.[Order Details] AS od ON od.ProductID = p.ProductID
WHERE p.Discontinued = 0
GROUP BY s.Country, s.CompanyName, cat.CategoryName
ORDER BY Unidades DESC;
GO
-- Conclusión: antes del índice las tres uniones usaban Hash Match y [Order Details] se leía completa en 11
-- páginas. Con el índice el motor cambió las tres uniones a Nested Loops: recorre los 69 productos vigentes y
-- por cada uno busca su categoría, su proveedor y sus líneas en el índice nuevo. Por eso las lecturas suben
-- ([Order Details] de 11 a 142, Suppliers de 3 a 138 y Categories de 2 a 138), pero el costo estimado del
-- plan baja de 0.157 a 0.092 y el tiempo de CPU baja de ~11 ms a ~4 ms. Como las tablas de Northwind son tan
-- pequeñas, esas búsquedas repetidas salen más baratas que construir las tablas hash. Ahora el operador más
-- costoso es el Index Seek sobre [Order Details] (26%).
SET STATISTICS TIME OFF;
GO
