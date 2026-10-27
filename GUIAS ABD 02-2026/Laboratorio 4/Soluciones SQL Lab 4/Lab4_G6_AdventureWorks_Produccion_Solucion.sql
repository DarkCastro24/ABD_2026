-- Laboratorio 4 | Solución Grupo 6 - AdventureWorks - Producción

-- Ejercicio 1 · Esquemas y secuencias
USE AdventureWorks2022;
GO
CREATE SCHEMA Calidad AUTHORIZATION dbo;
GO
ALTER SCHEMA Calidad TRANSFER Production.ScrapReason;
GO
SELECT s.name AS Esquema, t.name AS Tabla
FROM sys.tables AS t
JOIN sys.schemas AS s ON s.schema_id = t.schema_id
WHERE t.name = N'ScrapReason';
GO
CREATE SEQUENCE Calidad.seq_registro_calidad
    AS INT
    START WITH 3000
    INCREMENT BY 1
    NO CYCLE
    CACHE 20;
GO
SELECT name, start_value, increment, is_cycling, is_cached, cache_size
FROM sys.sequences
WHERE name = N'seq_registro_calidad';
GO
CREATE TABLE Calidad.Registro (
    id_registro INT NOT NULL
        CONSTRAINT DF_Registro_id_registro DEFAULT (NEXT VALUE FOR Calidad.seq_registro_calidad),
    usuario VARCHAR(50) NOT NULL,
    fecha DATE NOT NULL,
    CONSTRAINT PK_Registro PRIMARY KEY (id_registro)
);
GO
INSERT INTO Calidad.Registro (usuario, fecha) VALUES ('calidad.admin', '20261026');
INSERT INTO Calidad.Registro (usuario, fecha) VALUES ('calidad.auditor', '20261027');
GO
SELECT id_registro, usuario, fecha
FROM Calidad.Registro;
GO
SELECT s.name AS Esquema, t.name AS Tabla
FROM sys.tables AS t
JOIN sys.schemas AS s ON s.schema_id = t.schema_id
WHERE s.name = N'Calidad';
GO

-- Ejercicio 2 · Índices y planes de ejecución
USE AdventureWorks2022;
GO
SET STATISTICS IO ON;
GO
SELECT WorkOrderID, ProductID, OrderQty, ScrappedQty
FROM Production.WorkOrder
WHERE StartDate >= '20130603' AND StartDate < '20130604';
GO
CREATE NONCLUSTERED INDEX IX_WorkOrder_StartDate
ON Production.WorkOrder(StartDate);
GO
SELECT WorkOrderID, ProductID, OrderQty, ScrappedQty
FROM Production.WorkOrder
WHERE StartDate >= '20130603' AND StartDate < '20130604';
GO

-- Ejercicio 3 · Optimizando el Key Lookup con INCLUDE
USE AdventureWorks2022;
GO
SET STATISTICS IO ON;
GO
SELECT WorkOrderID, ProductID, ScrappedQty, StartDate
FROM Production.WorkOrder
WHERE ScrapReasonID = 4;
GO
CREATE NONCLUSTERED INDEX IX_WorkOrder_ScrapReasonID
ON Production.WorkOrder(ScrapReasonID)
INCLUDE (ProductID, ScrappedQty, StartDate)
WITH (DROP_EXISTING = ON);
GO
SELECT WorkOrderID, ProductID, ScrappedQty, StartDate
FROM Production.WorkOrder
WHERE ScrapReasonID = 4;
GO

-- Ejercicio 4 · Análisis de JOINs y rendimiento
USE AdventureWorks2022;
GO
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO
SELECT l.Name AS Ubicacion, p.Name AS Producto,
       COUNT(*) AS Operaciones, SUM(wor.ActualCost) AS CostoReal
FROM Production.WorkOrder AS wo
JOIN Production.WorkOrderRouting AS wor ON wor.WorkOrderID = wo.WorkOrderID
JOIN Production.Product AS p ON p.ProductID = wo.ProductID
JOIN Production.Location AS l ON l.LocationID = wor.LocationID
WHERE wo.StartDate >= '20130101' AND wo.StartDate < '20140101'
GROUP BY l.Name, p.Name
ORDER BY CostoReal DESC;
GO
CREATE NONCLUSTERED INDEX IX_WorkOrderRouting_WorkOrderID
ON Production.WorkOrderRouting(WorkOrderID)
INCLUDE (LocationID, ActualCost);
GO
SELECT l.Name AS Ubicacion, p.Name AS Producto,
       COUNT(*) AS Operaciones, SUM(wor.ActualCost) AS CostoReal
FROM Production.WorkOrder AS wo
JOIN Production.WorkOrderRouting AS wor ON wor.WorkOrderID = wo.WorkOrderID
JOIN Production.Product AS p ON p.ProductID = wo.ProductID
JOIN Production.Location AS l ON l.LocationID = wor.LocationID
WHERE wo.StartDate >= '20130101' AND wo.StartDate < '20140101'
GROUP BY l.Name, p.Name
ORDER BY CostoReal DESC;
GO
SET STATISTICS TIME OFF;
GO
