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
SET STATISTICS TIME OFF;
GO
