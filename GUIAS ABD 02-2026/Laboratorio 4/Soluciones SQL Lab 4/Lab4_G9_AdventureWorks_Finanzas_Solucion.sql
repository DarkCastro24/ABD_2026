-- Laboratorio 4 | Solución Grupo 9 - AdventureWorks - Finanzas

-- Ejercicio 1 · Esquemas y secuencias
USE AdventureWorks2022;
GO
CREATE SCHEMA Tesoreria AUTHORIZATION dbo;
GO
ALTER SCHEMA Tesoreria TRANSFER Sales.Currency;
GO
SELECT s.name AS Esquema, t.name AS Tabla
FROM sys.tables AS t
JOIN sys.schemas AS s ON s.schema_id = t.schema_id
WHERE t.name = N'Currency';
GO
CREATE SEQUENCE Tesoreria.seq_bitacora_tesoreria
    AS INT
    START WITH 1500
    INCREMENT BY 5
    NO CYCLE
    CACHE 20;
GO
SELECT name, start_value, increment, is_cycling, is_cached, cache_size
FROM sys.sequences
WHERE name = N'seq_bitacora_tesoreria';
GO
CREATE TABLE Tesoreria.Bitacora (
    id_registro INT NOT NULL
        CONSTRAINT DF_Bitacora_id_registro DEFAULT (NEXT VALUE FOR Tesoreria.seq_bitacora_tesoreria),
    usuario VARCHAR(50) NOT NULL,
    fecha DATE NOT NULL,
    CONSTRAINT PK_Bitacora PRIMARY KEY (id_registro)
);
GO
INSERT INTO Tesoreria.Bitacora (usuario, fecha) VALUES ('tesoreria.admin', '20261026');
INSERT INTO Tesoreria.Bitacora (usuario, fecha) VALUES ('tesoreria.auditor', '20261027');
GO
SELECT id_registro, usuario, fecha
FROM Tesoreria.Bitacora;
GO
SELECT s.name AS Esquema, t.name AS Tabla
FROM sys.tables AS t
JOIN sys.schemas AS s ON s.schema_id = t.schema_id
WHERE s.name = N'Tesoreria';
GO

-- Ejercicio 2 · Índices y planes de ejecución
USE AdventureWorks2022;
GO
SET STATISTICS IO ON;
GO
SELECT SalesOrderID, CustomerID, SubTotal, TotalDue
FROM Sales.SalesOrderHeader
WHERE DueDate >= '20130715' AND DueDate < '20130716';
GO
-- Justificación: índice no agrupado. SalesOrderHeader ya tiene su índice agrupado en la llave primaria
-- (SalesOrderID) y solo puede haber uno por tabla; cambiarlo obligaría a reconstruir la llave primaria y los
-- demás índices. DueDate no es única y el 15 de julio de 2013 vencen solo 46 de 31,465 pedidos, así que un
-- índice no agrupado sobre DueDate basta para pasar a Index Seek. El plan pasa de Clustered Index Scan (686
-- lecturas) a Index Seek + Key Lookup (151 lecturas); el Key Lookup queda porque CustomerID, SubTotal y
-- TotalDue no están en el índice.
CREATE NONCLUSTERED INDEX IX_SalesOrderHeader_DueDate
ON Sales.SalesOrderHeader(DueDate);
GO
SELECT SalesOrderID, CustomerID, SubTotal, TotalDue
FROM Sales.SalesOrderHeader
WHERE DueDate >= '20130715' AND DueDate < '20130716';
GO

-- Ejercicio 3 · Optimizando el Key Lookup con INCLUDE
USE AdventureWorks2022;
GO
SET STATISTICS IO ON;
GO
SELECT CurrencyRateDate, ToCurrencyCode, AverageRate, EndOfDayRate
FROM Sales.CurrencyRate
WHERE CurrencyRateDate = '20130701';
GO
-- Justificación: se reemplaza el índice existente con DROP_EXISTING = ON en lugar de crear otro. Se conserva
-- UNIQUE y la misma clave, así sigue garantizando que no haya dos tasas para la misma fecha y par de monedas,
-- y CurrencyRateDate sigue como primera columna, que es la que filtra la consulta. ToCurrencyCode ya está en
-- la clave, así que solo se incluyen AverageRate y EndOfDayRate. El plan pasa de Index Seek + Key Lookup (26
-- lecturas) a un único Index Seek (2 lecturas).
-- Columnas incluidas: AverageRate y EndOfDayRate solo se devuelven en el SELECT; no se usan para filtrar ni
-- para ordenar, así que no necesitan formar parte de la clave. En INCLUDE se guardan solo en el nivel hoja:
-- la clave sigue angosta y el índice cubre la consulta sin Key Lookup. Además, agregarlas a la clave
-- cambiaría la regla de unicidad del índice.
CREATE UNIQUE NONCLUSTERED INDEX AK_CurrencyRate_CurrencyRateDate_FromCurrencyCode_ToCurrencyCode
ON Sales.CurrencyRate(CurrencyRateDate, FromCurrencyCode, ToCurrencyCode)
INCLUDE (AverageRate, EndOfDayRate)
WITH (DROP_EXISTING = ON);
GO
SELECT CurrencyRateDate, ToCurrencyCode, AverageRate, EndOfDayRate
FROM Sales.CurrencyRate
WHERE CurrencyRateDate = '20130701';
GO

-- Ejercicio 4 · Análisis de JOINs y rendimiento
USE AdventureWorks2022;
GO
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO
SELECT cr.ToCurrencyCode AS Moneda, cc.CardType AS TipoTarjeta,
       COUNT(*) AS Pedidos, SUM(soh.TotalDue * cr.AverageRate) AS MontoMonedaLocal
FROM Sales.SalesOrderHeader AS soh
JOIN Sales.CurrencyRate AS cr ON cr.CurrencyRateID = soh.CurrencyRateID
JOIN Sales.CreditCard AS cc ON cc.CreditCardID = soh.CreditCardID
JOIN Sales.SalesTerritory AS t ON t.TerritoryID = soh.TerritoryID
WHERE t.[Group] = N'Europe'
  AND soh.OrderDate >= '20130101' AND soh.OrderDate < '20140101'
GROUP BY cr.ToCurrencyCode, cc.CardType
ORDER BY MontoMonedaLocal DESC;
GO
-- Justificación del índice: el operador más costoso es el Clustered Index Scan de SalesOrderHeader (39%), que
-- lee los 31,465 pedidos para quedarse con los de Europa en 2013. El índice pone TerritoryID primero (se une
-- con los 3 territorios de Europa) y OrderDate después (rango de 2013), así el motor busca un tramo continuo
-- por territorio; CurrencyRateID y CreditCardID (columnas de unión) y TotalDue (se suma) van en INCLUDE para
-- cubrir la consulta sin Key Lookup.
CREATE NONCLUSTERED INDEX IX_SalesOrderHeader_TerritoryID_OrderDate
ON Sales.SalesOrderHeader(TerritoryID, OrderDate)
INCLUDE (CurrencyRateID, CreditCardID, TotalDue);
GO
SELECT cr.ToCurrencyCode AS Moneda, cc.CardType AS TipoTarjeta,
       COUNT(*) AS Pedidos, SUM(soh.TotalDue * cr.AverageRate) AS MontoMonedaLocal
FROM Sales.SalesOrderHeader AS soh
JOIN Sales.CurrencyRate AS cr ON cr.CurrencyRateID = soh.CurrencyRateID
JOIN Sales.CreditCard AS cc ON cc.CreditCardID = soh.CreditCardID
JOIN Sales.SalesTerritory AS t ON t.TerritoryID = soh.TerritoryID
WHERE t.[Group] = N'Europe'
  AND soh.OrderDate >= '20130101' AND soh.OrderDate < '20140101'
GROUP BY cr.ToCurrencyCode, cc.CardType
ORDER BY MontoMonedaLocal DESC;
GO
-- Conclusión: antes del índice, SalesOrderHeader se leía completa con un Clustered Index Scan (686 lecturas,
-- 39% del costo). Con el índice nuevo pasa a 3 Index Seek (uno por territorio de Europa) con 28 lecturas en
-- total, el costo estimado del plan baja de 1.39 a 0.74 y el tiempo de CPU baja de ~17 ms a ~6 ms. Sí cambió
-- un algoritmo de unión: SalesTerritory–SalesOrderHeader pasó de Hash Match a Nested Loops, porque ahora el
-- motor busca en el índice los pedidos de cada territorio. Las uniones con CurrencyRate y CreditCard siguen
-- con Hash Match y ahora son los operadores más costosos (27% cada uno). CurrencyRate (98 lecturas) y
-- CreditCard (189) no cambian porque se siguen recorriendo completas.
SET STATISTICS TIME OFF;
GO
