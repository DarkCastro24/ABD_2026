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
-- Justificación: índice no agrupado. Sales.Customer ya tiene su índice agrupado en la llave primaria
-- (CustomerID) y solo puede haber uno por tabla; cambiarlo obligaría a reconstruir la llave primaria y los
-- demás índices. La búsqueda por PersonID devuelve 1 de 19,820 clientes, así que un índice no agrupado sobre
-- PersonID basta para pasar a Index Seek. El plan pasa de Clustered Index Scan (123 lecturas) a Index Seek +
-- Key Lookup (4 lecturas); el Key Lookup queda porque StoreID y TerritoryID no están en el índice.
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
-- Justificación: se reemplaza el índice existente IX_EmailAddress_EmailAddress con DROP_EXISTING = ON en
-- lugar de crear otro: se conserva su nombre y su clave (EmailAddress), se evita mantener dos índices sobre
-- la misma columna y la reconstrucción se hace en un solo paso. Solo hace falta incluir ModifiedDate:
-- BusinessEntityID ya está en todo índice no agrupado porque forma parte de la clave agrupada
-- (BusinessEntityID, EmailAddressID). El plan pasa de Index Seek + Key Lookup (5 lecturas) a un único Index
-- Seek (3 lecturas); la mejora es pequeña porque se busca una sola fila y solo se ahorra su Key Lookup.
-- Columnas incluidas: ModifiedDate solo se devuelve en el SELECT; no se usan para filtrar ni para ordenar,
-- así que no necesita formar parte de la clave. En INCLUDE se guarda solo en el nivel hoja: la clave sigue
-- angosta y el índice cubre la consulta sin Key Lookup.
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
-- Justificación del índice: el operador más costoso es el Clustered Index Seek sobre Person (51%), que se
-- repite por cada dirección de las tres ciudades para comprobar EmailPromotion = 1. IX_Person_EmailPromotion
-- (clave EmailPromotion, sin columnas incluidas) es mucho más angosto que el índice agrupado de Person y ya
-- trae BusinessEntityID, porque SQL Server agrega la clave agrupada a todo índice no agrupado; con él, el
-- motor lee de una vez a las 5,044 personas con EmailPromotion = 1.
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
-- Conclusión: antes del índice, Person era la tabla con más lecturas (1,326) y su Clustered Index Seek el
-- operador más costoso (51%). Con IX_Person_EmailPromotion las lecturas de Person bajan a 12, el costo
-- estimado del plan baja de 1.66 a 0.87 y el tiempo de CPU baja de ~23 ms a ~10 ms. Sí cambió un algoritmo de
-- unión: Person ya no se une con Nested Loops (una búsqueda por cada dirección) sino con Hash Match, leyendo
-- de una vez a las 5,044 personas del índice. Las demás uniones se mantienen: Address con
-- BusinessEntityAddress y Customer con Hash Match, y EmailAddress con Nested Loops. Ahora el operador más
-- costoso es el Index Scan de Address (21%).
SET STATISTICS TIME OFF;
GO
