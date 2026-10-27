-- Laboratorio 4 | Solución Grupo 5 - AdventureWorks - Ventas

-- Ejercicio 1 · Esquemas y secuencias
USE AdventureWorks2022;
GO
CREATE SCHEMA Comercial AUTHORIZATION dbo;
GO
ALTER SCHEMA Comercial TRANSFER Sales.SalesReason;
GO
SELECT s.name AS Esquema, t.name AS Tabla
FROM sys.tables AS t
JOIN sys.schemas AS s ON s.schema_id = t.schema_id
WHERE t.name = N'SalesReason';
GO
CREATE SEQUENCE Comercial.seq_historial_campanas
    AS INT
    START WITH 700
    INCREMENT BY 5
    NO CYCLE
    CACHE 20;
GO
SELECT name, start_value, increment, is_cycling, is_cached, cache_size
FROM sys.sequences
WHERE name = N'seq_historial_campanas';
GO
CREATE TABLE Comercial.Historial (
    id_registro INT NOT NULL
        CONSTRAINT DF_Historial_id_registro DEFAULT (NEXT VALUE FOR Comercial.seq_historial_campanas),
    usuario VARCHAR(50) NOT NULL,
    fecha DATE NOT NULL,
    CONSTRAINT PK_Historial PRIMARY KEY (id_registro)
);
GO
INSERT INTO Comercial.Historial (usuario, fecha) VALUES ('mercadeo.admin', '20261026');
INSERT INTO Comercial.Historial (usuario, fecha) VALUES ('mercadeo.auditor', '20261027');
GO
SELECT id_registro, usuario, fecha
FROM Comercial.Historial;
GO
SELECT s.name AS Esquema, t.name AS Tabla
FROM sys.tables AS t
JOIN sys.schemas AS s ON s.schema_id = t.schema_id
WHERE s.name = N'Comercial';
GO

-- Ejercicio 2 · Índices y planes de ejecución
USE AdventureWorks2022;
GO
SET STATISTICS IO ON;
GO
SELECT SalesOrderID, CustomerID, TerritoryID, TotalDue
FROM Sales.SalesOrderHeader
WHERE OrderDate >= '20130701' AND OrderDate < '20130702';
GO
CREATE NONCLUSTERED INDEX IX_SalesOrderHeader_OrderDate
ON Sales.SalesOrderHeader(OrderDate);
GO
SELECT SalesOrderID, CustomerID, TerritoryID, TotalDue
FROM Sales.SalesOrderHeader
WHERE OrderDate >= '20130701' AND OrderDate < '20130702';
GO

-- Ejercicio 3 · Optimizando el Key Lookup con INCLUDE
USE AdventureWorks2022;
GO
SET STATISTICS IO ON;
GO
SELECT OrderDate, Status, TotalDue
FROM Sales.SalesOrderHeader
WHERE CustomerID = 11091;
GO
CREATE NONCLUSTERED INDEX IX_SalesOrderHeader_CustomerID
ON Sales.SalesOrderHeader(CustomerID)
INCLUDE (OrderDate, Status, TotalDue)
WITH (DROP_EXISTING = ON);
GO
SELECT OrderDate, Status, TotalDue
FROM Sales.SalesOrderHeader
WHERE CustomerID = 11091;
GO

-- Ejercicio 4 · Análisis de JOINs y rendimiento
USE AdventureWorks2022;
GO
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO
SELECT t.Name AS Territorio, p.Name AS Producto,
       SUM(sod.OrderQty) AS Unidades, SUM(sod.LineTotal) AS Ventas
FROM Sales.SalesOrderHeader AS soh
JOIN Sales.SalesOrderDetail AS sod ON sod.SalesOrderID = soh.SalesOrderID
JOIN Production.Product AS p ON p.ProductID = sod.ProductID
JOIN Sales.SalesTerritory AS t ON t.TerritoryID = soh.TerritoryID
WHERE soh.OrderDate >= '20130101' AND soh.OrderDate < '20140101'
GROUP BY t.Name, p.Name
ORDER BY Ventas DESC;
GO
CREATE NONCLUSTERED INDEX IX_SalesOrderDetail_SalesOrderID
ON Sales.SalesOrderDetail(SalesOrderID)
INCLUDE (ProductID, OrderQty, LineTotal);
GO
SELECT t.Name AS Territorio, p.Name AS Producto,
       SUM(sod.OrderQty) AS Unidades, SUM(sod.LineTotal) AS Ventas
FROM Sales.SalesOrderHeader AS soh
JOIN Sales.SalesOrderDetail AS sod ON sod.SalesOrderID = soh.SalesOrderID
JOIN Production.Product AS p ON p.ProductID = sod.ProductID
JOIN Sales.SalesTerritory AS t ON t.TerritoryID = soh.TerritoryID
WHERE soh.OrderDate >= '20130101' AND soh.OrderDate < '20140101'
GROUP BY t.Name, p.Name
ORDER BY Ventas DESC;
GO
SET STATISTICS TIME OFF;
GO
