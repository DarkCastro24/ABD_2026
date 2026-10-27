-- Laboratorio 4 | Solución Grupo 1 - Northwind - Ventas

-- Ejercicio 1 · Esquemas y secuencias
USE Northwind;
GO
CREATE SCHEMA Despacho AUTHORIZATION dbo;
GO
ALTER SCHEMA Despacho TRANSFER dbo.Shippers;
GO
SELECT s.name AS Esquema, t.name AS Tabla
FROM sys.tables AS t
JOIN sys.schemas AS s ON s.schema_id = t.schema_id
WHERE t.name = N'Shippers';
GO
CREATE SEQUENCE Despacho.seq_auditoria_despacho
    AS INT
    START WITH 5000
    INCREMENT BY 10
    NO CYCLE
    CACHE 20;
GO
SELECT name, start_value, increment, is_cycling, is_cached, cache_size
FROM sys.sequences
WHERE name = N'seq_auditoria_despacho';
GO
CREATE TABLE Despacho.Bitacora (
    id_registro INT NOT NULL
        CONSTRAINT DF_Bitacora_id_registro DEFAULT (NEXT VALUE FOR Despacho.seq_auditoria_despacho),
    usuario VARCHAR(50) NOT NULL,
    fecha DATE NOT NULL,
    CONSTRAINT PK_Bitacora PRIMARY KEY (id_registro)
);
GO
INSERT INTO Despacho.Bitacora (usuario, fecha) VALUES ('logistica.admin', '20261026');
INSERT INTO Despacho.Bitacora (usuario, fecha) VALUES ('logistica.auditor', '20261027');
GO
SELECT id_registro, usuario, fecha
FROM Despacho.Bitacora;
GO
SELECT s.name AS Esquema, t.name AS Tabla
FROM sys.tables AS t
JOIN sys.schemas AS s ON s.schema_id = t.schema_id
WHERE s.name = N'Despacho';
GO

-- Ejercicio 2 · Índices y planes de ejecución
USE Northwind;
GO
SET STATISTICS IO ON;
GO
SELECT OrderID, CustomerID, OrderDate, Freight
FROM dbo.Orders
WHERE Freight > 500;
GO
CREATE NONCLUSTERED INDEX IX_Orders_Freight
ON dbo.Orders(Freight);
GO
SELECT OrderID, CustomerID, OrderDate, Freight
FROM dbo.Orders
WHERE Freight > 500;
GO

-- Ejercicio 3 · Optimizando el Key Lookup con INCLUDE
USE Northwind;
GO
SET STATISTICS IO ON;
GO
SELECT OrderID, OrderDate, ShipCountry, Freight
FROM dbo.Orders
WHERE OrderDate >= '19980501';
GO
CREATE NONCLUSTERED INDEX OrderDate
ON dbo.Orders(OrderDate)
INCLUDE (ShipCountry, Freight)
WITH (DROP_EXISTING = ON);
GO
SELECT OrderID, OrderDate, ShipCountry, Freight
FROM dbo.Orders
WHERE OrderDate >= '19980501';
GO

-- Ejercicio 4 · Análisis de JOINs y rendimiento
USE Northwind;
GO
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO
SELECT c.Country, cat.CategoryName,
       SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)) AS Ventas
FROM dbo.Customers AS c
JOIN dbo.Orders AS o ON o.CustomerID = c.CustomerID
JOIN dbo.[Order Details] AS od ON od.OrderID = o.OrderID
JOIN dbo.Products AS p ON p.ProductID = od.ProductID
JOIN dbo.Categories AS cat ON cat.CategoryID = p.CategoryID
WHERE o.OrderDate >= '19970101' AND o.OrderDate < '19980101'
GROUP BY c.Country, cat.CategoryName
ORDER BY Ventas DESC;
GO
CREATE NONCLUSTERED INDEX IX_Orders_OrderDate_CustomerID
ON dbo.Orders(OrderDate)
INCLUDE (CustomerID);
GO
SELECT c.Country, cat.CategoryName,
       SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)) AS Ventas
FROM dbo.Customers AS c
JOIN dbo.Orders AS o ON o.CustomerID = c.CustomerID
JOIN dbo.[Order Details] AS od ON od.OrderID = o.OrderID
JOIN dbo.Products AS p ON p.ProductID = od.ProductID
JOIN dbo.Categories AS cat ON cat.CategoryID = p.CategoryID
WHERE o.OrderDate >= '19970101' AND o.OrderDate < '19980101'
GROUP BY c.Country, cat.CategoryName
ORDER BY Ventas DESC;
GO
SET STATISTICS TIME OFF;
GO
