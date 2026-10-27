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
-- Justificación: índice no agrupado. SalesOrderHeader ya tiene su índice agrupado en la llave primaria
-- (SalesOrderID) y solo puede haber uno por tabla; cambiarlo obligaría a reconstruir la llave primaria y los
-- demás índices. OrderDate no es única y el 1 de julio de 2013 tiene solo 43 de 31,465 pedidos, así que un
-- índice no agrupado sobre OrderDate basta para pasar a Index Seek. El plan pasa de Clustered Index Scan (686
-- lecturas) a Index Seek + Key Lookup (142 lecturas); el Key Lookup queda porque CustomerID, TerritoryID y
-- TotalDue no están en el índice.
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
-- Justificación: se reemplaza el índice existente IX_SalesOrderHeader_CustomerID con DROP_EXISTING = ON en
-- lugar de crear otro: se conserva su nombre y su clave (CustomerID), se evita mantener dos índices sobre la
-- misma columna y la reconstrucción se hace en un solo paso. TotalDue es una columna calculada; al incluirla,
-- el índice guarda su valor ya calculado. El plan pasa de Index Seek + Key Lookup (142 lecturas) a un único
-- Index Seek (3 lecturas).
-- Columnas incluidas: OrderDate, Status y TotalDue solo se devuelven en el SELECT; no se usan para filtrar ni
-- para ordenar, así que no necesitan formar parte de la clave. En INCLUDE se guardan solo en el nivel hoja:
-- la clave sigue angosta y el índice cubre la consulta sin Key Lookup.
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
-- Justificación del índice: el operador más costoso es el Clustered Index Scan de SalesOrderDetail (41%), la
-- tabla de mayor volumen (121,317 líneas). El índice usa la columna de unión (SalesOrderID) como clave e
-- incluye ProductID, OrderQty y LineTotal, las únicas columnas que la consulta necesita de esa tabla, así el
-- motor lee un índice más angosto que la tabla completa.
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
-- Conclusión: antes del índice, SalesOrderDetail se leía con un Clustered Index Scan (890 lecturas, 41% del
-- costo) y se unía con SalesOrderHeader mediante Merge Join. Con el índice las lecturas de SalesOrderDetail
-- bajan a 569, pero el motor cambió ese Merge Join por un Hash Match y ahora agrupa después de unir con
-- Product y SalesTerritory, así que el costo estimado del plan sube de 2.57 a 3.39 y el tiempo de CPU no
-- mejora (~53 ms a ~69 ms). Las uniones con Product y SalesTerritory siguen con Hash Match. La mejora es
-- pequeña porque la consulta necesita igual unas 56,600 líneas de 2013: el índice reduce el ancho de lo que
-- se lee, no la cantidad de filas, así que habría que evaluar si vale la pena mantenerlo.
SET STATISTICS TIME OFF;
GO
