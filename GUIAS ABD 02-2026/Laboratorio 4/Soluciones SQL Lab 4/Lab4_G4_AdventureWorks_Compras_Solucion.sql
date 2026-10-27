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
-- Justificación: índice no agrupado. PurchaseOrderDetail ya tiene su índice agrupado en la llave primaria
-- (PurchaseOrderID, PurchaseOrderDetailID) y solo puede haber uno por tabla; cambiarlo obligaría a
-- reconstruir la llave primaria y los demás índices. DueDate no es única y la primera semana de agosto de
-- 2013 tiene solo 5 de 8,845 líneas, así que un índice no agrupado sobre DueDate basta para pasar a Index
-- Seek. El plan pasa de Clustered Index Scan (66 lecturas) a Index Seek + Key Lookup (12 lecturas); el Key
-- Lookup queda porque ProductID, OrderQty y UnitPrice no están en el índice (PurchaseOrderID y
-- PurchaseOrderDetailID sí, porque forman la clave agrupada).
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
-- Justificación: se reemplaza el índice existente IX_PurchaseOrderDetail_ProductID con DROP_EXISTING = ON en
-- lugar de crear otro: se conserva su nombre y su clave (ProductID), se evita mantener dos índices sobre la
-- misma columna y la reconstrucción se hace en un solo paso. El plan pasa de Index Seek + Key Lookup (30
-- lecturas) a un único Index Seek (2 lecturas).
-- Columnas incluidas: OrderQty, UnitPrice y DueDate solo se devuelven en el SELECT; no se usan para filtrar
-- ni para ordenar, así que no necesitan formar parte de la clave. En INCLUDE se guardan solo en el nivel
-- hoja: la clave sigue angosta y el índice cubre la consulta sin Key Lookup.
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
-- Justificación del índice: el operador más costoso es el Hash Match entre PurchaseOrderHeader y
-- PurchaseOrderDetail (20%), alimentado por un Clustered Index Scan de PurchaseOrderDetail, la tabla de mayor
-- volumen (8,845 líneas). El índice usa la columna de unión (PurchaseOrderID) como clave e incluye ProductID,
-- OrderQty y UnitPrice, las únicas columnas que la consulta necesita de esa tabla, así el motor lee un índice
-- más angosto que la tabla completa.
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
-- Conclusión: antes del índice, PurchaseOrderDetail se leía con un Clustered Index Scan de 66 lecturas y el
-- operador más costoso era el Hash Match con PurchaseOrderHeader (20%). Con el índice cubierto las lecturas
-- de PurchaseOrderDetail bajan a 33, el costo estimado del plan baja de 0.400 a 0.376 y el tiempo de CPU baja
-- de ~10 ms a ~7 ms. Los algoritmos de unión no cambian: las tres uniones (con PurchaseOrderHeader, Product y
-- Vendor) siguen con Hash Match, y el motor sigue recorriendo todo el índice porque necesita todas las líneas
-- de las órdenes de 2013. La mejora es pequeña porque las tablas son pequeñas: PurchaseOrderDetail tiene
-- 8,845 filas y PurchaseOrderHeader se lee en 44 páginas.
SET STATISTICS TIME OFF;
GO
