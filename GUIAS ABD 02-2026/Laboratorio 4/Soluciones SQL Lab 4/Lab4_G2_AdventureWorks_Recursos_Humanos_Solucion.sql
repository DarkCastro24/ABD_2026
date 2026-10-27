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
-- Justificación: índice no agrupado. Person.Person ya tiene su índice agrupado en la llave primaria
-- (BusinessEntityID) y solo puede haber uno por tabla; cambiarlo obligaría a reconstruir la llave primaria y
-- los demás índices. PersonType no es única y 'EM' devuelve solo 273 de 19,972 filas (1.4%), así que un
-- índice no agrupado sobre la columna de búsqueda basta para que el motor haga un Index Seek. El plan pasa de
-- Clustered Index Scan (3,818 lecturas) a Index Seek + Key Lookup (847 lecturas); el Key Lookup queda porque
-- Title, EmailPromotion y ModifiedDate no están en el índice.
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
-- Justificación: se reemplaza el índice existente con DROP_EXISTING = ON en lugar de crear otro. Se conserva
-- su nombre y su clave (LastName, FirstName, MiddleName), así las consultas que ya lo usaban siguen igual, y
-- se evita mantener dos índices sobre las mismas columnas. FirstName ya está en la clave; solo faltan
-- EmailPromotion y ModifiedDate. El plan pasa de Index Seek + Key Lookup (611 lecturas) a un único Index Seek
-- (4 lecturas).
-- Columnas incluidas: EmailPromotion y ModifiedDate solo se devuelven en el SELECT; no se usan para filtrar
-- ni para ordenar, así que no necesitan formar parte de la clave. En INCLUDE se guardan solo en el nivel
-- hoja: la clave sigue angosta y el índice cubre la consulta sin Key Lookup.
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
-- Justificación del índice: el operador más costoso es el Clustered Index Seek sobre Person (59%), que se
-- repite por cada empleado para comprobar EmailPromotion = 0. IX_Person_EmailPromotion (clave EmailPromotion,
-- sin columnas incluidas) es mucho más angosto que el índice agrupado de Person y ya trae BusinessEntityID,
-- porque SQL Server agrega la clave agrupada a todo índice no agrupado; así cada búsqueda lee menos páginas.
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
-- Conclusión: antes del índice, Person era la tabla con más lecturas (1,294) y su Clustered Index Seek el
-- operador más costoso (59%). Con IX_Person_EmailPromotion las lecturas de Person bajan a 607, el costo
-- estimado del plan baja de 0.352 a 0.193 y el tiempo de CPU baja de ~11 ms a ~4 ms. Los algoritmos de unión
-- no cambian: EmployeeDepartmentHistory–Person sigue con Nested Loops y las uniones con EmployeePayHistory,
-- Employee y Department siguen con Hash Match. Solo cambia el acceso a Person, que ahora es un Index Seek
-- sobre el índice nuevo (25% del costo). Employee, EmployeeDepartmentHistory, Department y EmployeePayHistory
-- leen de 2 a 4 páginas cada una, por eso la mejora se concentra en Person.
SET STATISTICS TIME OFF;
GO
