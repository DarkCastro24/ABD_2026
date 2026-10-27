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
SET STATISTICS TIME OFF;
GO
