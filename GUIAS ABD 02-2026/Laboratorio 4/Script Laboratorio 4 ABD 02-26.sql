-- Laboratorio 4 | Ciclo 02-2026 | Versión 1
-- Autor: Diego Eduardo Castro Quintanilla
-- Socios y préstamos ficticios de una biblioteca universitaria.
-- Entorno: contenedor Docker sqlserver-2025 (SSMS: localhost,1434, login sa).
-- Antes de medir, activa en SSMS Incluir plan de ejecución real (Ctrl + M).
-- Ejecuta cada bloque en orden y una sola vez, siguiendo la guía.

-- 1. Creación de la base de datos
USE master;
GO

CREATE DATABASE BibliotecaLab04;
GO

USE BibliotecaLab04;
GO

-- Datos ficticios de socios y préstamos de la biblioteca.
CREATE TABLE dbo.Socio (
    socio_id INT NOT NULL,
    nombre NVARCHAR(50) NOT NULL,
    apellido NVARCHAR(50) NOT NULL,
    carrera NVARCHAR(50) NOT NULL,
    CONSTRAINT PK_Socio PRIMARY KEY (socio_id)
);

CREATE TABLE dbo.Prestamo (
    prestamo_id INT NOT NULL,
    socio_id INT NOT NULL,
    ejemplar_id INT NOT NULL,
    fecha_prestamo DATE NOT NULL,
    fecha_devolucion_prevista DATE NOT NULL,
    estado NVARCHAR(20) NOT NULL,
    observaciones NVARCHAR(200) NOT NULL,
    CONSTRAINT PK_Prestamo PRIMARY KEY (prestamo_id),
    CONSTRAINT FK_Prestamo_Socio FOREIGN KEY (socio_id)
        REFERENCES dbo.Socio (socio_id)
);
GO

-- 2 000 socios generados con una CTE recursiva.
WITH Numeros AS (
    SELECT 1 AS n
    UNION ALL
    SELECT n + 1 FROM Numeros WHERE n < 2000
)
INSERT INTO dbo.Socio (socio_id, nombre, apellido, carrera)
SELECT n,
       CONCAT(N'Socio ', n),
       CONCAT(N'Apellido ', n % 400 + 1),
       CASE n % 4 WHEN 0 THEN N'Ingeniería Informática'
                  WHEN 1 THEN N'Administración de Empresas'
                  WHEN 2 THEN N'Psicología'
                  ELSE N'Arquitectura' END
FROM Numeros
OPTION (MAXRECURSION 0);
GO

-- 60 000 préstamos repartidos entre 2022 y 2026.
WITH Numeros AS (
    SELECT 1 AS n
    UNION ALL
    SELECT n + 1 FROM Numeros WHERE n < 60000
)
INSERT INTO dbo.Prestamo
    (prestamo_id, socio_id, ejemplar_id, fecha_prestamo,
     fecha_devolucion_prevista, estado, observaciones)
SELECT n,
       n % 2000 + 1,
       n % 5000 + 1,
       DATEADD(DAY, n % 1826, '2022-01-01'),
       DATEADD(DAY, n % 1826 + 15, '2022-01-01'),
       CASE WHEN n % 9 < 6 THEN N'Devuelto'
            WHEN n % 9 < 8 THEN N'Activo'
            ELSE N'Vencido' END,
       N'Préstamo registrado en el mostrador de la biblioteca central para consulta en sala o estudio en casa.'
FROM Numeros
OPTION (MAXRECURSION 0);
GO

-- Índices que ya existen: los creó la PRIMARY KEY de cada tabla.
SELECT OBJECT_NAME(object_id) AS Tabla,
       name AS Indice,
       type_desc AS Tipo
FROM sys.indexes
WHERE object_id IN (OBJECT_ID(N'dbo.Socio'), OBJECT_ID(N'dbo.Prestamo'))
ORDER BY Tabla;
GO

-- 2. Medir una búsqueda sin índice
-- Las lecturas lógicas aparecen en la pestaña Mensajes.
USE BibliotecaLab04;
GO

SET STATISTICS IO ON;
GO

-- Préstamos del socio 308, todavía sin un índice sobre socio_id.
SELECT prestamo_id, socio_id,
       fecha_devolucion_prevista, estado
FROM dbo.Prestamo
WHERE socio_id = 308;
GO

-- 3. Crear un índice no agrupado
-- Índice simple sobre la columna del filtro.
CREATE NONCLUSTERED INDEX IX_Prestamo_Socio
ON dbo.Prestamo (socio_id);
GO

SELECT prestamo_id, socio_id,
       fecha_devolucion_prevista, estado
FROM dbo.Prestamo
WHERE socio_id = 308;
GO

-- Versión cubriente: socio_id es la clave; el resto viaja en INCLUDE.
DROP INDEX IX_Prestamo_Socio ON dbo.Prestamo;
GO

CREATE NONCLUSTERED INDEX IX_Prestamo_Socio
ON dbo.Prestamo (socio_id)
INCLUDE (fecha_devolucion_prevista, estado);
GO

SELECT prestamo_id, socio_id,
       fecha_devolucion_prevista, estado
FROM dbo.Prestamo
WHERE socio_id = 308;
GO

-- 4. Revisar la fragmentación y dar mantenimiento
-- Fragmentación de los índices de la base actual.
SELECT OBJECT_NAME(ips.object_id) AS Tabla,
       i.name AS Indice,
       ips.index_type_desc AS Tipo,
       ips.avg_fragmentation_in_percent AS Fragmentacion
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') AS ips
JOIN sys.indexes AS i
  ON ips.object_id = i.object_id AND ips.index_id = i.index_id
WHERE ips.database_id = DB_ID();
GO

-- Fragmentación menor de 30 %: reorganizar.
ALTER INDEX IX_Prestamo_Socio ON dbo.Prestamo REORGANIZE;
GO

-- Fragmentación mayor de 30 %: reconstruir (aquí, todos los índices de la tabla).
ALTER INDEX ALL ON dbo.Prestamo REBUILD;
GO

-- 5. Crear la cuenta, el rol y el esquema
USE master;
GO

-- Login de práctica para el personal de circulación.
CREATE LOGIN loginBiblioteca WITH PASSWORD = 'Biblioteca2026!';
GO

USE BibliotecaLab04;
GO

-- Usuario de la base y rol que recibirá los permisos.
CREATE USER usuarioBiblioteca FOR LOGIN loginBiblioteca;
CREATE ROLE rolConsulta;
ALTER ROLE rolConsulta ADD MEMBER usuarioBiblioteca;
GO

-- El esquema agrupa las tablas del área de circulación.
CREATE SCHEMA Circulacion AUTHORIZATION dbo;
GO

-- Mueve la tabla de préstamos al nuevo esquema.
ALTER SCHEMA Circulacion TRANSFER dbo.Prestamo;
GO

-- Un solo permiso cubre todas las tablas del esquema.
GRANT SELECT ON SCHEMA::Circulacion TO rolConsulta;
GO

-- 6. Verificar la organización
USE BibliotecaLab04;
GO

-- Esquemas y sus propietarios.
SELECT name AS Esquema,
       USER_NAME(principal_id) AS Propietario
FROM sys.schemas
WHERE name IN (N'dbo', N'Circulacion');

-- Objetos de cada esquema (solo los creados en la práctica).
SELECT s.name AS Esquema,
       o.name AS Objeto,
       o.type_desc AS Tipo
FROM sys.objects AS o
JOIN sys.schemas AS s ON o.schema_id = s.schema_id
WHERE o.is_ms_shipped = 0
ORDER BY s.name, o.name;

-- Índices de la tabla después de la transferencia.
SELECT name AS Indice,
       type_desc AS Tipo
FROM sys.indexes
WHERE object_id = OBJECT_ID(N'Circulacion.Prestamo');
GO

-- 7. Probar los permisos del esquema
-- Desactiva antes Incluir plan de ejecución real (Ctrl + M); si no, aparece el error 262.
-- La segunda consulta debe terminar con el error 229.
USE BibliotecaLab04;
GO

-- Cambia el contexto al usuario de consulta.
EXECUTE AS USER = 'usuarioBiblioteca';

-- Permitida: el rol tiene SELECT sobre el esquema Circulacion.
SELECT TOP (5) prestamo_id, socio_id, fecha_prestamo, estado
FROM Circulacion.Prestamo
ORDER BY prestamo_id;

-- No permitida: dbo.Socio está fuera del esquema autorizado.
SELECT TOP (5) socio_id, nombre, apellido
FROM dbo.Socio;
GO

-- Regresa al contexto original (en su propio lote).
REVERT;
GO

SELECT USER_NAME() AS UsuarioActual;
GO

-- Ejercicio guiado: resuelve las cinco tareas de la guía y conserva las evidencias.

-- 8. Limpieza (opcional): solo para repetir la práctica después de entregar.
-- Está comentada para que no se ejecute por accidente con el resto del script.
-- Para usarla, selecciona las líneas y quita los comentarios (Ctrl+K, Ctrl+U en SSMS).
--
-- USE master;
-- GO
--
-- DROP DATABASE BibliotecaLab04;
-- GO
--
-- DROP LOGIN loginBiblioteca;
-- GO
