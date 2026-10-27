-- Laboratorio 4 | Solución Grupo 3 - AdventureWorks - Inventario

-- Ejercicio 1 · Esquemas y secuencias
USE AdventureWorks2022;
GO
CREATE SCHEMA Bodega AUTHORIZATION dbo;
GO
ALTER SCHEMA Bodega TRANSFER Production.Location;
GO
SELECT s.name AS Esquema, t.name AS Tabla
FROM sys.tables AS t
JOIN sys.schemas AS s ON s.schema_id = t.schema_id
WHERE t.name = N'Location';
GO
CREATE SEQUENCE Bodega.seq_registro_bodega
    AS INT
    START WITH 200
    INCREMENT BY 1
    NO CYCLE
    CACHE 20;
GO
SELECT name, start_value, increment, is_cycling, is_cached, cache_size
FROM sys.sequences
WHERE name = N'seq_registro_bodega';
GO
CREATE TABLE Bodega.Registro (
    id_registro INT NOT NULL
        CONSTRAINT DF_Registro_id_registro DEFAULT (NEXT VALUE FOR Bodega.seq_registro_bodega),
    usuario VARCHAR(50) NOT NULL,
    fecha DATE NOT NULL,
    CONSTRAINT PK_Registro PRIMARY KEY (id_registro)
);
GO
INSERT INTO Bodega.Registro (usuario, fecha) VALUES ('bodega.admin', '20261026');
INSERT INTO Bodega.Registro (usuario, fecha) VALUES ('bodega.auditor', '20261027');
GO
SELECT id_registro, usuario, fecha
FROM Bodega.Registro;
GO
SELECT s.name AS Esquema, t.name AS Tabla
FROM sys.tables AS t
JOIN sys.schemas AS s ON s.schema_id = t.schema_id
WHERE s.name = N'Bodega';
GO

-- Ejercicio 2 · Índices y planes de ejecución
USE AdventureWorks2022;
GO
SET STATISTICS IO ON;
GO
SELECT TransactionID, ProductID, TransactionType, Quantity
FROM Production.TransactionHistory
WHERE TransactionDate >= '20140711' AND TransactionDate < '20140712';
GO
CREATE NONCLUSTERED INDEX IX_TransactionHistory_TransactionDate
ON Production.TransactionHistory(TransactionDate);
GO
SELECT TransactionID, ProductID, TransactionType, Quantity
FROM Production.TransactionHistory
WHERE TransactionDate >= '20140711' AND TransactionDate < '20140712';
GO

-- Ejercicio 3 · Optimizando el Key Lookup con INCLUDE
USE AdventureWorks2022;
GO
SET STATISTICS IO ON;
GO
SELECT TransactionDate, Quantity, ActualCost
FROM Production.TransactionHistory
WHERE ProductID = 717;
GO
CREATE NONCLUSTERED INDEX IX_TransactionHistory_ProductID
ON Production.TransactionHistory(ProductID)
INCLUDE (TransactionDate, Quantity, ActualCost)
WITH (DROP_EXISTING = ON);
GO
SELECT TransactionDate, Quantity, ActualCost
FROM Production.TransactionHistory
WHERE ProductID = 717;
GO

-- Ejercicio 4 · Análisis de JOINs y rendimiento
USE AdventureWorks2022;
GO
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO
SELECT pc.Name AS Categoria, ps.Name AS Subcategoria,
       COUNT(*) AS Movimientos, SUM(th.ActualCost) AS Costo
FROM Production.TransactionHistory AS th
JOIN Production.Product AS p ON p.ProductID = th.ProductID
JOIN Production.ProductSubcategory AS ps ON ps.ProductSubcategoryID = p.ProductSubcategoryID
JOIN Production.ProductCategory AS pc ON pc.ProductCategoryID = ps.ProductCategoryID
WHERE th.TransactionType = N'S'
  AND th.TransactionDate >= '20131001' AND th.TransactionDate < '20140101'
GROUP BY pc.Name, ps.Name
ORDER BY Costo DESC;
GO
CREATE NONCLUSTERED INDEX IX_TransactionHistory_TransactionType_TransactionDate
ON Production.TransactionHistory(TransactionType, TransactionDate)
INCLUDE (ProductID, ActualCost);
GO
SELECT pc.Name AS Categoria, ps.Name AS Subcategoria,
       COUNT(*) AS Movimientos, SUM(th.ActualCost) AS Costo
FROM Production.TransactionHistory AS th
JOIN Production.Product AS p ON p.ProductID = th.ProductID
JOIN Production.ProductSubcategory AS ps ON ps.ProductSubcategoryID = p.ProductSubcategoryID
JOIN Production.ProductCategory AS pc ON pc.ProductCategoryID = ps.ProductCategoryID
WHERE th.TransactionType = N'S'
  AND th.TransactionDate >= '20131001' AND th.TransactionDate < '20140101'
GROUP BY pc.Name, ps.Name
ORDER BY Costo DESC;
GO
SET STATISTICS TIME OFF;
GO
