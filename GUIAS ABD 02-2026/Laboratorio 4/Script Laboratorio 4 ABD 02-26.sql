-- Laboratorio 4 | Ciclo 02-2026 | Versión 2
-- Autor: Diego Eduardo Castro Quintanilla
-- Fuente: G04.md. Regenerado por scripts/build-guide.cjs.
-- Ejemplos informativos: ejecuta por bloques en el orden de la guía sobre una base nueva.
-- La carga adjunta genera 50 000 filas en total, de las cuales 45 000 son préstamos.
-- Ejecuta esa carga cuando se indique más adelante, antes de continuar con los índices.
-- Activa Ctrl+M para medir. Desactívalo en las pruebas de permisos.
-- Las tablas de referencia de comandos no se ejecutan de nuevo.

-- ========================================================================
-- Introducción
-- ========================================================================

-- ========================================================================
-- Índices
-- ========================================================================

USE master;
GO
CREATE DATABASE BibliotecaLab04;
GO
USE BibliotecaLab04;
GO
CREATE TABLE dbo.Socio (
    socio_id INT NOT NULL,
    nombre NVARCHAR(50) NOT NULL,
    apellido NVARCHAR(50) NOT NULL,
    carrera NVARCHAR(50) NOT NULL,
    CONSTRAINT PK_Socio PRIMARY KEY NONCLUSTERED (socio_id)
);
CREATE TABLE dbo.Libro (
    libro_id INT NOT NULL,
    titulo NVARCHAR(150) NOT NULL,
    categoria NVARCHAR(50) NOT NULL,
    CONSTRAINT PK_Libro PRIMARY KEY CLUSTERED (libro_id)
);
CREATE TABLE dbo.Ejemplar (
    ejemplar_id INT NOT NULL,
    libro_id INT NOT NULL,
    codigo_inventario VARCHAR(20) NOT NULL,
    CONSTRAINT PK_Ejemplar PRIMARY KEY CLUSTERED (ejemplar_id),
    CONSTRAINT FK_Ejemplar_Libro FOREIGN KEY (libro_id)
        REFERENCES dbo.Libro(libro_id)
);
CREATE TABLE dbo.Prestamo (
    prestamo_id INT NOT NULL,
    socio_id INT NOT NULL,
    ejemplar_id INT NOT NULL,
    fecha_prestamo DATE NOT NULL,
    fecha_devolucion_prevista DATE NOT NULL,
    estado NVARCHAR(20) NOT NULL,
    observaciones VARCHAR(400) NOT NULL,
    CONSTRAINT PK_Prestamo PRIMARY KEY CLUSTERED (prestamo_id),
    CONSTRAINT FK_Prestamo_Socio FOREIGN KEY (socio_id)
        REFERENCES dbo.Socio(socio_id),
    CONSTRAINT FK_Prestamo_Ejemplar FOREIGN KEY (ejemplar_id)
        REFERENCES dbo.Ejemplar(ejemplar_id)
);
GO

-- Ejecuta ahora el archivo adjunto: g04/descargas/Carga-BibliotecaLab04.sql
-- Espera a que termine la carga y luego continúa con el siguiente bloque.

USE BibliotecaLab04;
GO
SELECT prestamo_id, socio_id, fecha_devolucion_prevista, estado
FROM dbo.Prestamo
WHERE socio_id=308;
GO

SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO

-- ========================================================================
-- Tipos de índice
-- ========================================================================

CREATE CLUSTERED INDEX IX_Socio_Apellido
ON dbo.Socio(apellido);
GO
SELECT socio_id, nombre, apellido
FROM dbo.Socio
WHERE apellido=N'Apellido 25';
GO

CREATE NONCLUSTERED INDEX IX_Prestamo_Socio
ON dbo.Prestamo(socio_id);
GO
SELECT prestamo_id, socio_id, fecha_devolucion_prevista, estado
FROM dbo.Prestamo
WHERE socio_id=308;
GO

CREATE NONCLUSTERED INDEX IX_Socio_Carrera_Apellido
ON dbo.Socio(carrera, apellido);
GO
SELECT socio_id, carrera, apellido
FROM dbo.Socio
WHERE carrera=N'Psicología' AND apellido=N'Apellido 25';
GO

CREATE UNIQUE NONCLUSTERED INDEX UX_Ejemplar_Codigo
ON dbo.Ejemplar(codigo_inventario);
GO
SELECT ejemplar_id, libro_id, codigo_inventario
FROM dbo.Ejemplar
WHERE codigo_inventario='EJ-000308';
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
GO
CREATE NONCLUSTERED INDEX IX_Prestamo_Vencido_Fecha
ON dbo.Prestamo(fecha_devolucion_prevista)
WHERE estado=N'Vencido';
GO
SELECT prestamo_id, fecha_devolucion_prevista
FROM dbo.Prestamo
WHERE estado=N'Vencido'
  AND fecha_devolucion_prevista >= '20260101'
  AND fecha_devolucion_prevista < '20260201';
GO

DROP INDEX IX_Prestamo_Socio ON dbo.Prestamo;
GO
CREATE NONCLUSTERED INDEX IX_Prestamo_Socio
ON dbo.Prestamo(socio_id)
INCLUDE(fecha_devolucion_prevista, estado);
GO
SELECT prestamo_id, socio_id, fecha_devolucion_prevista, estado
FROM dbo.Prestamo
WHERE socio_id=308;
GO

-- ========================================================================
-- Mantenimiento de índices
-- ========================================================================

SELECT name AS Indice, type_desc AS Tipo
FROM sys.indexes
WHERE object_id=OBJECT_ID(N'dbo.Prestamo');
GO

SELECT i.name AS Indice,
       p.page_count AS Paginas,
       p.avg_fragmentation_in_percent AS Fragmentacion
FROM sys.dm_db_index_physical_stats
     (DB_ID(),OBJECT_ID(N'dbo.Prestamo'),NULL,NULL,'LIMITED') AS p
JOIN sys.indexes AS i
  ON i.object_id=p.object_id AND i.index_id=p.index_id
WHERE i.name=N'IX_Prestamo_Socio'
  AND p.index_level=0;
GO

ALTER INDEX IX_Prestamo_Socio
ON dbo.Prestamo REORGANIZE;
GO

ALTER INDEX IX_Prestamo_Socio
ON dbo.Prestamo REBUILD;
GO

DROP INDEX IX_Socio_Carrera_Apellido ON dbo.Socio;
GO

-- ========================================================================
-- Esquemas
-- ========================================================================

USE BibliotecaLab04;
GO
CREATE SCHEMA Circulacion AUTHORIZATION dbo;
GO

ALTER SCHEMA Circulacion TRANSFER dbo.Prestamo;
GO

ALTER SCHEMA Circulacion TRANSFER dbo.Socio;
GO

SELECT t.name AS Tabla
FROM sys.tables AS t
JOIN sys.schemas AS s ON s.schema_id=t.schema_id
WHERE s.name=N'Circulacion';
GO

SELECT name AS Esquema, USER_NAME(principal_id) AS Propietario
FROM sys.schemas
WHERE name=N'Circulacion';
GO

CREATE ROLE rolAdministracion;
ALTER AUTHORIZATION ON SCHEMA::Circulacion TO rolAdministracion;
GO

ALTER AUTHORIZATION ON SCHEMA::Circulacion TO dbo;
GO

USE master;
GO
CREATE LOGIN loginBiblioteca WITH PASSWORD='Biblioteca2026!';
GO

USE BibliotecaLab04;
GO
CREATE USER usuarioBiblioteca FOR LOGIN loginBiblioteca;
GO

CREATE ROLE rolConsulta;
ALTER ROLE rolConsulta ADD MEMBER usuarioBiblioteca;
GO

GRANT SELECT ON SCHEMA::Circulacion TO rolConsulta;
GO

EXECUTE AS USER='usuarioBiblioteca';
SELECT TOP (5) prestamo_id, socio_id, estado
FROM Circulacion.Prestamo ORDER BY prestamo_id;
REVERT;
GO

REVOKE SELECT ON SCHEMA::Circulacion FROM rolConsulta;
GO

GRANT SELECT ON SCHEMA::Circulacion TO rolConsulta;
GO

CREATE SCHEMA Temporal AUTHORIZATION dbo;
GO
DROP SCHEMA Temporal;
GO

-- ========================================================================
-- Comandos de índices y esquemas
-- ========================================================================

-- ========================================================================
-- Ejercicio práctico
-- ========================================================================

-- ========================================================================
-- Créditos
-- ========================================================================
