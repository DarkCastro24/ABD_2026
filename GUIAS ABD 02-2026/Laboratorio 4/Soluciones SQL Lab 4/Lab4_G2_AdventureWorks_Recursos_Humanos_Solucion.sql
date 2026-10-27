-- Laboratorio 4 | Solución Grupo 2 - AdventureWorks - Recursos Humanos

-- Ejercicio 1 · Esquemas y secuencias
USE AdventureWorks2022;
GO
CREATE SCHEMA Reportes AUTHORIZATION dbo;
GO
ALTER SCHEMA Reportes TRANSFER HumanResources.Shift;
GO
SELECT s.name AS Esquema, t.name AS Tabla
FROM sys.tables AS t
JOIN sys.schemas AS s ON s.schema_id = t.schema_id
WHERE t.name = N'Shift';
GO
CREATE SEQUENCE Reportes.seq_auditoria_horarios
    AS INT
    START WITH 100
    INCREMENT BY 1
    NO CYCLE
    CACHE 20;
GO
SELECT name, start_value, increment, is_cycling, is_cached, cache_size
FROM sys.sequences
WHERE name = N'seq_auditoria_horarios';
GO
CREATE TABLE Reportes.Historial (
    id_registro INT NOT NULL
        CONSTRAINT DF_Historial_id_registro DEFAULT (NEXT VALUE FOR Reportes.seq_auditoria_horarios),
    usuario VARCHAR(50) NOT NULL,
    fecha DATE NOT NULL,
    CONSTRAINT PK_Historial PRIMARY KEY (id_registro)
);
GO
INSERT INTO Reportes.Historial (usuario, fecha) VALUES ('rrhh.admin', '20261026');
INSERT INTO Reportes.Historial (usuario, fecha) VALUES ('rrhh.auditor', '20261027');
GO
SELECT id_registro, usuario, fecha
FROM Reportes.Historial;
GO
SELECT s.name AS Esquema, t.name AS Tabla
FROM sys.tables AS t
JOIN sys.schemas AS s ON s.schema_id = t.schema_id
WHERE s.name = N'Reportes';
GO

-- Ejercicio 2 · Índices y planes de ejecución
USE AdventureWorks2022;
GO
SET STATISTICS IO ON;
GO
SELECT BusinessEntityID, Title, EmailPromotion, ModifiedDate
FROM Person.Person
WHERE PersonType = N'EM';
GO
CREATE NONCLUSTERED INDEX IX_Person_PersonType
ON Person.Person(PersonType);
GO
SELECT BusinessEntityID, Title, EmailPromotion, ModifiedDate
FROM Person.Person
WHERE PersonType = N'EM';
GO

-- Ejercicio 3 · Optimizando el Key Lookup con INCLUDE
USE AdventureWorks2022;
GO
SET STATISTICS IO ON;
GO
SELECT LastName, FirstName, EmailPromotion, ModifiedDate
FROM Person.Person
WHERE LastName = N'Smith';
GO
CREATE NONCLUSTERED INDEX IX_Person_LastName_FirstName_MiddleName
ON Person.Person(LastName, FirstName, MiddleName)
INCLUDE (EmailPromotion, ModifiedDate)
WITH (DROP_EXISTING = ON);
GO
SELECT LastName, FirstName, EmailPromotion, ModifiedDate
FROM Person.Person
WHERE LastName = N'Smith';
GO

-- Ejercicio 4 · Análisis de JOINs y rendimiento
USE AdventureWorks2022;
GO
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO
SELECT d.Name AS Departamento,
       COUNT(DISTINCT e.BusinessEntityID) AS Empleados,
       AVG(ph.Rate) AS TarifaPromedio
FROM HumanResources.Employee AS e
JOIN Person.Person AS p ON p.BusinessEntityID = e.BusinessEntityID
JOIN HumanResources.EmployeeDepartmentHistory AS edh ON edh.BusinessEntityID = e.BusinessEntityID
JOIN HumanResources.Department AS d ON d.DepartmentID = edh.DepartmentID
JOIN HumanResources.EmployeePayHistory AS ph ON ph.BusinessEntityID = e.BusinessEntityID
WHERE edh.EndDate IS NULL AND p.EmailPromotion = 0
GROUP BY d.Name
ORDER BY TarifaPromedio DESC;
GO
CREATE NONCLUSTERED INDEX IX_Person_EmailPromotion
ON Person.Person(EmailPromotion);
GO
SELECT d.Name AS Departamento,
       COUNT(DISTINCT e.BusinessEntityID) AS Empleados,
       AVG(ph.Rate) AS TarifaPromedio
FROM HumanResources.Employee AS e
JOIN Person.Person AS p ON p.BusinessEntityID = e.BusinessEntityID
JOIN HumanResources.EmployeeDepartmentHistory AS edh ON edh.BusinessEntityID = e.BusinessEntityID
JOIN HumanResources.Department AS d ON d.DepartmentID = edh.DepartmentID
JOIN HumanResources.EmployeePayHistory AS ph ON ph.BusinessEntityID = e.BusinessEntityID
WHERE edh.EndDate IS NULL AND p.EmailPromotion = 0
GROUP BY d.Name
ORDER BY TarifaPromedio DESC;
GO
SET STATISTICS TIME OFF;
GO
