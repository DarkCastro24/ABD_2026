-- Laboratorio 4 | Solución Grupo 4 - AdventureWorks - Compras

-- Ejercicio 1 · Esquemas y secuencias
USE AdventureWorks2022;
GO
CREATE SCHEMA Auditoria AUTHORIZATION dbo;
GO
ALTER SCHEMA Auditoria TRANSFER Purchasing.ShipMethod;
GO
SELECT s.name AS Esquema, t.name AS Tabla
FROM sys.tables AS t
JOIN sys.schemas AS s ON s.schema_id = t.schema_id
WHERE t.name = N'ShipMethod';
GO
CREATE SEQUENCE Auditoria.seq_auditoria_envios
    AS INT
    START WITH 9000
    INCREMENT BY 1
    NO CYCLE
    CACHE 20;
GO
SELECT name, start_value, increment, is_cycling, is_cached, cache_size
FROM sys.sequences
WHERE name = N'seq_auditoria_envios';
GO
CREATE TABLE Auditoria.Bitacora (
    id_registro INT NOT NULL
        CONSTRAINT DF_Bitacora_id_registro DEFAULT (NEXT VALUE FOR Auditoria.seq_auditoria_envios),
    usuario VARCHAR(50) NOT NULL,
    fecha DATE NOT NULL,
    CONSTRAINT PK_Bitacora PRIMARY KEY (id_registro)
);
GO
INSERT INTO Auditoria.Bitacora (usuario, fecha) VALUES ('compras.admin', '20261026');
INSERT INTO Auditoria.Bitacora (usuario, fecha) VALUES ('compras.auditor', '20261027');
GO
SELECT id_registro, usuario, fecha
FROM Auditoria.Bitacora;
GO
SELECT s.name AS Esquema, t.name AS Tabla
FROM sys.tables AS t
JOIN sys.schemas AS s ON s.schema_id = t.schema_id
WHERE s.name = N'Auditoria';
GO

-- Ejercicio 2 · Índices y planes de ejecución
USE AdventureWorks2022;
GO
SET STATISTICS IO ON;
GO
SELECT PurchaseOrderID, PurchaseOrderDetailID, ProductID, OrderQty, UnitPrice
FROM Purchasing.PurchaseOrderDetail
WHERE DueDate >= '20130801' AND DueDate < '20130808';
GO
CREATE NONCLUSTERED INDEX IX_PurchaseOrderDetail_DueDate
ON Purchasing.PurchaseOrderDetail(DueDate);
GO
SELECT PurchaseOrderID, PurchaseOrderDetailID, ProductID, OrderQty, UnitPrice
FROM Purchasing.PurchaseOrderDetail
WHERE DueDate >= '20130801' AND DueDate < '20130808';
GO

-- Ejercicio 3 · Optimizando el Key Lookup con INCLUDE
USE AdventureWorks2022;
GO
SET STATISTICS IO ON;
GO
SELECT OrderQty, UnitPrice, DueDate
FROM Purchasing.PurchaseOrderDetail
WHERE ProductID = 468;
GO
CREATE NONCLUSTERED INDEX IX_PurchaseOrderDetail_ProductID
ON Purchasing.PurchaseOrderDetail(ProductID)
INCLUDE (OrderQty, UnitPrice, DueDate)
WITH (DROP_EXISTING = ON);
GO
SELECT OrderQty, UnitPrice, DueDate
FROM Purchasing.PurchaseOrderDetail
WHERE ProductID = 468;
GO

-- Ejercicio 4 · Análisis de JOINs y rendimiento
USE AdventureWorks2022;
GO
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO
SELECT v.Name AS Proveedor, p.Name AS Producto,
       SUM(pod.OrderQty) AS Unidades,
       SUM(pod.OrderQty * pod.UnitPrice) AS Monto
FROM Purchasing.PurchaseOrderHeader AS poh
JOIN Purchasing.PurchaseOrderDetail AS pod ON pod.PurchaseOrderID = poh.PurchaseOrderID
JOIN Purchasing.Vendor AS v ON v.BusinessEntityID = poh.VendorID
JOIN Production.Product AS p ON p.ProductID = pod.ProductID
WHERE poh.OrderDate >= '20130101' AND poh.OrderDate < '20140101'
GROUP BY v.Name, p.Name
ORDER BY Monto DESC;
GO
CREATE NONCLUSTERED INDEX IX_PurchaseOrderDetail_PurchaseOrderID
ON Purchasing.PurchaseOrderDetail(PurchaseOrderID)
INCLUDE (ProductID, OrderQty, UnitPrice);
GO
SELECT v.Name AS Proveedor, p.Name AS Producto,
       SUM(pod.OrderQty) AS Unidades,
       SUM(pod.OrderQty * pod.UnitPrice) AS Monto
FROM Purchasing.PurchaseOrderHeader AS poh
JOIN Purchasing.PurchaseOrderDetail AS pod ON pod.PurchaseOrderID = poh.PurchaseOrderID
JOIN Purchasing.Vendor AS v ON v.BusinessEntityID = poh.VendorID
JOIN Production.Product AS p ON p.ProductID = pod.ProductID
WHERE poh.OrderDate >= '20130101' AND poh.OrderDate < '20140101'
GROUP BY v.Name, p.Name
ORDER BY Monto DESC;
GO
SET STATISTICS TIME OFF;
GO
