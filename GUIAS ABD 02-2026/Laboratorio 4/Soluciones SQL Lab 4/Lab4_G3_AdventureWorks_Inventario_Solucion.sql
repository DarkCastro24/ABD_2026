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
-- Justificación: índice no agrupado. TransactionHistory ya tiene su índice agrupado en la llave primaria
-- (TransactionID) y solo puede haber uno por tabla; cambiarlo obligaría a reconstruir la llave primaria y los
-- demás índices. TransactionDate no es única y el 11 de julio de 2014 tiene solo 26 de 113,443 movimientos,
-- así que un índice no agrupado sobre la fecha basta para pasar a Index Seek. El plan pasa de Clustered Index
-- Scan (792 lecturas) a Index Seek + Key Lookup (89 lecturas); el Key Lookup queda porque ProductID,
-- TransactionType y Quantity no están en el índice.
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
-- Justificación: se reemplaza el índice existente IX_TransactionHistory_ProductID con DROP_EXISTING = ON en
-- lugar de crear otro: se conserva su nombre y su clave (ProductID), se evita mantener dos índices sobre la
-- misma columna y la reconstrucción se hace en un solo paso. El plan pasa de Index Seek + Key Lookup (unas
-- 335 lecturas) a un único Index Seek (4 lecturas).
-- Columnas incluidas: TransactionDate, Quantity y ActualCost solo se devuelven en el SELECT; no se usan para
-- filtrar ni para ordenar, así que no necesitan formar parte de la clave. En INCLUDE se guardan solo en el
-- nivel hoja: la clave sigue angosta y el índice cubre la consulta sin Key Lookup.
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
-- Justificación del índice: el operador más costoso es el Clustered Index Scan de TransactionHistory (60%),
-- que lee los 113,443 movimientos para quedarse con 20,594. El índice pone TransactionType primero (filtro de
-- igualdad) y TransactionDate después (rango), así el motor busca un solo tramo continuo; ProductID (columna
-- de unión) y ActualCost (se suma) van en INCLUDE para cubrir la consulta sin Key Lookup.
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
-- Conclusión: antes del índice, TransactionHistory se leía completa con un Clustered Index Scan (792
-- lecturas, 60% del costo). Con el índice nuevo pasa a un Index Seek de 86 lecturas, el costo estimado del
-- plan baja de 1.19 a 0.45 y el tiempo de CPU baja de ~16 ms a ~10 ms. Los algoritmos de unión no cambian:
-- ProductSubcategory–ProductCategory sigue con Nested Loops y las uniones con Product y TransactionHistory
-- siguen con Hash Match, porque se unen unas 20,000 filas y para ese volumen el Hash Match sigue siendo lo
-- más barato. Ahora el operador más costoso es el Hash Match con TransactionHistory (36%). Product,
-- ProductSubcategory y ProductCategory casi no cambian porque son tablas pequeñas.
SET STATISTICS TIME OFF;
GO
