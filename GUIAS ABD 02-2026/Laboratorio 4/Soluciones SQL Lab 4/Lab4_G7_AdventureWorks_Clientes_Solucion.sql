-- Laboratorio 4 | Solución Grupo 7 - AdventureWorks - Clientes

-- Ejercicio 1 · Esquemas y secuencias
USE AdventureWorks2022;
GO
CREATE SCHEMA Mercadeo AUTHORIZATION dbo;
GO
ALTER SCHEMA Mercadeo TRANSFER Person.ContactType;
GO
SELECT s.name AS Esquema, t.name AS Tabla
FROM sys.tables AS t
JOIN sys.schemas AS s ON s.schema_id = t.schema_id
WHERE t.name = N'ContactType';
GO
CREATE SEQUENCE Mercadeo.seq_bitacora_mercadeo
    AS INT
    START WITH 100
    INCREMENT BY 1
    NO CYCLE
    CACHE 20;
GO
SELECT name, start_value, increment, is_cycling, is_cached, cache_size
FROM sys.sequences
WHERE name = N'seq_bitacora_mercadeo';
GO
CREATE TABLE Mercadeo.Bitacora (
    id_registro INT NOT NULL
        CONSTRAINT DF_Bitacora_id_registro DEFAULT (NEXT VALUE FOR Mercadeo.seq_bitacora_mercadeo),
    usuario VARCHAR(50) NOT NULL,
    fecha DATE NOT NULL,
    CONSTRAINT PK_Bitacora PRIMARY KEY (id_registro)
);
GO
INSERT INTO Mercadeo.Bitacora (usuario, fecha) VALUES ('mercadeo.admin', '20261026');
INSERT INTO Mercadeo.Bitacora (usuario, fecha) VALUES ('mercadeo.auditor', '20261027');
GO
SELECT id_registro, usuario, fecha
FROM Mercadeo.Bitacora;
GO
SELECT s.name AS Esquema, t.name AS Tabla
FROM sys.tables AS t
JOIN sys.schemas AS s ON s.schema_id = t.schema_id
WHERE s.name = N'Mercadeo';
GO

-- Ejercicio 2 · Índices y planes de ejecución
USE AdventureWorks2022;
GO
SET STATISTICS IO ON;
GO
SELECT CustomerID, StoreID, TerritoryID
FROM Sales.Customer
WHERE PersonID = 13531;
GO
CREATE NONCLUSTERED INDEX IX_Customer_PersonID
ON Sales.Customer(PersonID);
GO
SELECT CustomerID, StoreID, TerritoryID
FROM Sales.Customer
WHERE PersonID = 13531;
GO

-- Ejercicio 3 · Optimizando el Key Lookup con INCLUDE
USE AdventureWorks2022;
GO
SET STATISTICS IO ON;
GO
SELECT BusinessEntityID, EmailAddress, ModifiedDate
FROM Person.EmailAddress
WHERE EmailAddress = N'ken0@adventure-works.com';
GO
CREATE NONCLUSTERED INDEX IX_EmailAddress_EmailAddress
ON Person.EmailAddress(EmailAddress)
INCLUDE (ModifiedDate)
WITH (DROP_EXISTING = ON);
GO
SELECT BusinessEntityID, EmailAddress, ModifiedDate
FROM Person.EmailAddress
WHERE EmailAddress = N'ken0@adventure-works.com';
GO

-- Ejercicio 4 · Análisis de JOINs y rendimiento
USE AdventureWorks2022;
GO
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO
SELECT a.City AS Ciudad, COUNT(*) AS Clientes
FROM Sales.Customer AS c
JOIN Person.Person AS p ON p.BusinessEntityID = c.PersonID
JOIN Person.EmailAddress AS ea ON ea.BusinessEntityID = p.BusinessEntityID
JOIN Person.BusinessEntityAddress AS bea ON bea.BusinessEntityID = p.BusinessEntityID
JOIN Person.Address AS a ON a.AddressID = bea.AddressID
WHERE a.City IN (N'Seattle', N'Bothell', N'Redmond') AND p.EmailPromotion = 1
GROUP BY a.City
ORDER BY Clientes DESC;
GO
CREATE NONCLUSTERED INDEX IX_Person_EmailPromotion
ON Person.Person(EmailPromotion);
GO
SELECT a.City AS Ciudad, COUNT(*) AS Clientes
FROM Sales.Customer AS c
JOIN Person.Person AS p ON p.BusinessEntityID = c.PersonID
JOIN Person.EmailAddress AS ea ON ea.BusinessEntityID = p.BusinessEntityID
JOIN Person.BusinessEntityAddress AS bea ON bea.BusinessEntityID = p.BusinessEntityID
JOIN Person.Address AS a ON a.AddressID = bea.AddressID
WHERE a.City IN (N'Seattle', N'Bothell', N'Redmond') AND p.EmailPromotion = 1
GROUP BY a.City
ORDER BY Clientes DESC;
GO
SET STATISTICS TIME OFF;
GO
