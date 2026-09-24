-- Laboratorio 3 | Ciclo 02-2026 | Versión 1
-- Autor: Diego Eduardo Castro Quintanilla
-- Catálogo de una biblioteca universitaria. Datos ficticios.
-- Ejecuta cada bloque siguiendo las explicaciones de la guía.
-- Requiere C:\AuditLogs\BibliotecaLab03\ en el servidor y permisos de escritura del servicio.
-- Comprueba que los objetos no existan. Ejecuta las inserciones una sola vez.

-- Comprobación previa de SSMS: no modifica datos
USE master;

PRINT N'Lote 1 ejecutado';
GO

SELECT DB_NAME() AS BaseActual;
GO

-- Preparar el catálogo
USE master;
GO

CREATE DATABASE BibliotecaLab03;
GO

USE BibliotecaLab03;
GO

-- Cada fila representa una ficha del catálogo.
CREATE TABLE dbo.Libros (
    Id INT PRIMARY KEY,
    Titulo NVARCHAR(100) NOT NULL,
    PrecioReferencia DECIMAL(10,2) NOT NULL
);

-- La primera ficha está duplicada en otro catálogo y se retirará.
INSERT INTO dbo.Libros (Id, Titulo, PrecioReferencia)
VALUES (1, N'Introducción a la programación (ficha duplicada)', 25.00),
       (2, N'Fundamentos de bases de datos', 32.50);
GO

-- Configurar y activar la auditoría
USE master;
GO

-- Define dónde se guardarán los eventos.
CREATE SERVER AUDIT AuditoriaBiblioteca
TO FILE (
    FILEPATH = N'C:\AuditLogs\BibliotecaLab03\',
    MAXSIZE = 10 MB,
    MAX_FILES = 5
)
WITH (QUEUE_DELAY = 1000, ON_FAILURE = CONTINUE);
GO

-- Crear el objeto no lo activa: es necesario encenderlo.
ALTER SERVER AUDIT AuditoriaBiblioteca WITH (STATE = ON);
GO

USE BibliotecaLab03;
GO

-- Define qué acciones se registrarán y sobre qué tabla.
CREATE DATABASE AUDIT SPECIFICATION AuditoriaBibliotecaDB
FOR SERVER AUDIT AuditoriaBiblioteca
ADD (SELECT, INSERT, DELETE ON OBJECT::dbo.Libros BY public)
WITH (STATE = ON);
GO

-- Simular la revisión del catálogo
USE BibliotecaLab03;
GO

-- Consultar el catálogo antes de modificarlo.
SELECT Id, Titulo, PrecioReferencia FROM dbo.Libros;

-- Registrar un nuevo título.
INSERT INTO dbo.Libros (Id, Titulo, PrecioReferencia)
VALUES (3, N'Redes de computadoras', 40.00);

-- Retirar únicamente la ficha duplicada.
DELETE FROM dbo.Libros WHERE Id = 1;

-- Revisar cómo quedó el catálogo.
SELECT Id, Titulo, PrecioReferencia FROM dbo.Libros ORDER BY Id;
GO

-- Consultar las evidencias
USE master;
GO

SELECT event_time, action_id, succeeded,
       server_principal_name, database_name,
       schema_name, object_name, statement
FROM sys.fn_get_audit_file(
    N'C:\AuditLogs\BibliotecaLab03\*.sqlaudit', DEFAULT, DEFAULT)
WHERE database_name = N'BibliotecaLab03'
  AND schema_name = N'dbo'
  AND object_name = N'Libros'
ORDER BY event_time DESC;
GO

-- Ejercicio: agrega UPDATE a la especificación y cambia PrecioReferencia
-- del libro Id = 2 a 35.00. Sigue los pasos de la guía y conserva las evidencias.
