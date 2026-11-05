-- Laboratorio 5 | Ciclo 02-2026 | Versión 1
-- Autor: Diego Eduardo Castro Quintanilla
-- Fuente: G05.md. Regenerado por scripts/build-guide.cjs.
-- Ejemplos informativos: ejecuta por bloques en el orden de la guía sobre una base nueva.
-- Los comandos marcados con [PowerShell] se ejecutan en PowerShell, no en SSMS.
-- Antes de empezar, crea la carpeta /backup/NotasLab05 en el contenedor (sección Preparar el entorno).
-- La secuencia incluye un DROP DATABASE para simular la falla: no la ejecutes sobre una base real.
-- Desactiva Ctrl+M en la prueba de permisos. La limpieza final está comentada.
-- Las tablas de referencia de comandos no se ejecutan de nuevo.

-- ========================================================================
-- Introducción
-- ========================================================================

-- ========================================================================
-- Objetivos de recuperación
-- ========================================================================

-- ========================================================================
-- Tipos de respaldo
-- ========================================================================

SELECT name AS Base, recovery_model_desc AS Modelo
FROM sys.databases
ORDER BY name;
GO

-- ========================================================================
-- Preparar el entorno
-- ========================================================================

-- [PowerShell] docker ps --filter "name=sqlserver-2025"

-- [PowerShell] docker exec sqlserver-2025 mkdir -p /backup/NotasLab05
-- [PowerShell] docker exec sqlserver-2025 ls -ld /backup/NotasLab05

USE master;
GO
CREATE DATABASE NotasLab05;
GO
ALTER DATABASE NotasLab05 SET RECOVERY FULL;
GO
USE NotasLab05;
GO
CREATE TABLE dbo.Calificacion (
    calificacion_id INT NOT NULL,
    carnet CHAR(8) NOT NULL,
    estudiante NVARCHAR(60) NOT NULL,
    materia NVARCHAR(60) NOT NULL,
    nota DECIMAL(4,2) NOT NULL,
    CONSTRAINT PK_Calificacion PRIMARY KEY (calificacion_id)
);
INSERT INTO dbo.Calificacion (calificacion_id, carnet, estudiante, materia, nota)
VALUES (1, '00010126', N'Ana Martínez', N'Bases de Datos', 8.50),
       (2, '00020226', N'Luis Hernández', N'Bases de Datos', 6.75),
       (3, '00030326', N'María López', N'Redes de Computadoras', 9.25),
       (4, '00040426', N'Carlos Rivas', N'Redes de Computadoras', 7.00),
       (5, '00050526', N'Sofía Pérez', N'Programación', 8.00),
       (6, '00060626', N'Jorge Ramírez', N'Programación', 5.50);
GO
SELECT calificacion_id, estudiante, materia, nota
FROM dbo.Calificacion
ORDER BY calificacion_id;
GO

-- ========================================================================
-- Respaldos físicos
-- ========================================================================

USE master;
GO
BACKUP DATABASE NotasLab05
TO DISK = '/backup/NotasLab05/NotasLab05_full.bak'
WITH FORMAT, INIT,
NAME = 'Respaldo completo NotasLab05',
DESCRIPTION = 'Copia completa de seguridad de la base NotasLab05';
GO

-- [PowerShell] docker exec sqlserver-2025 ls -l /backup/NotasLab05

USE NotasLab05;
GO
INSERT INTO dbo.Calificacion (calificacion_id, carnet, estudiante, materia, nota)
VALUES (7, '00070726', N'Valeria Castillo', N'Bases de Datos', 9.00),
       (8, '00080826', N'Mario Flores', N'Redes de Computadoras', 6.25);
GO

BACKUP DATABASE NotasLab05
TO DISK = '/backup/NotasLab05/NotasLab05_diff.bak'
WITH DIFFERENTIAL, INIT,
NAME = 'Respaldo diferencial NotasLab05';
GO

INSERT INTO dbo.Calificacion (calificacion_id, carnet, estudiante, materia, nota)
VALUES (9, '00090926', N'Lucía Morales', N'Programación', 8.75);
UPDATE dbo.Calificacion
SET nota = 7.25
WHERE calificacion_id = 2;
GO

BACKUP LOG NotasLab05
TO DISK = '/backup/NotasLab05/NotasLab05_log.trn'
WITH INIT,
NAME = 'Respaldo del log NotasLab05';
GO

INSERT INTO dbo.Calificacion (calificacion_id, carnet, estudiante, materia, nota)
VALUES (10, '00101026', N'Andrés Guzmán', N'Bases de Datos', 7.50);
GO
SELECT COUNT(*) AS Calificaciones
FROM dbo.Calificacion;
GO

SELECT bs.name AS Respaldo,
       bs.type AS Tipo,
       bs.backup_finish_date AS Fin,
       bmf.physical_device_name AS Archivo
FROM msdb.dbo.backupset AS bs
JOIN msdb.dbo.backupmediafamily AS bmf
  ON bmf.media_set_id = bs.media_set_id
WHERE bs.database_name = N'NotasLab05'
ORDER BY bs.backup_set_id;
GO

RESTORE VERIFYONLY
FROM DISK = '/backup/NotasLab05/NotasLab05_full.bak';
GO

-- ========================================================================
-- Restauración
-- ========================================================================

USE master;
GO
DROP DATABASE NotasLab05;
GO

RESTORE DATABASE NotasLab05
FROM DISK = '/backup/NotasLab05/NotasLab05_full.bak'
WITH NORECOVERY;
GO
SELECT name, state_desc
FROM sys.databases
WHERE name = N'NotasLab05';
GO

RESTORE DATABASE NotasLab05
FROM DISK = '/backup/NotasLab05/NotasLab05_diff.bak'
WITH NORECOVERY;
GO

RESTORE LOG NotasLab05
FROM DISK = '/backup/NotasLab05/NotasLab05_log.trn'
WITH RECOVERY;
GO
SELECT name, state_desc
FROM sys.databases
WHERE name = N'NotasLab05';
GO

USE NotasLab05;
GO
SELECT calificacion_id, estudiante, materia, nota
FROM dbo.Calificacion
ORDER BY calificacion_id;
GO

-- ========================================================================
-- Respaldos lógicos
-- ========================================================================

-- [PowerShell] docker exec sqlserver-2025 /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Admin123!" -C -d NotasLab05 -Q "SET NOCOUNT ON; SELECT calificacion_id, carnet, estudiante, materia, nota FROM dbo.Calificacion ORDER BY calificacion_id;" -o /backup/NotasLab05/calificaciones.csv -s"," -W
-- [PowerShell] docker exec sqlserver-2025 cat /backup/NotasLab05/calificaciones.csv

-- [PowerShell] docker exec sqlserver-2025 /opt/mssql-tools18/bin/bcp NotasLab05.dbo.Calificacion out /backup/NotasLab05/calificacion.dat -n -S localhost -U sa -P "Admin123!" -u

USE NotasLab05;
GO
DELETE FROM dbo.Calificacion;
GO
SELECT COUNT(*) AS Calificaciones
FROM dbo.Calificacion;
GO

-- [PowerShell] docker exec sqlserver-2025 /opt/mssql-tools18/bin/bcp NotasLab05.dbo.Calificacion in /backup/NotasLab05/calificacion.dat -n -S localhost -U sa -P "Admin123!" -u

SELECT COUNT(*) AS Calificaciones
FROM dbo.Calificacion;
GO

-- ========================================================================
-- Delegar y programar respaldos
-- ========================================================================

USE master;
GO
CREATE LOGIN loginRespaldo WITH PASSWORD = 'Respaldo2026!';
GO
USE NotasLab05;
GO
CREATE USER usuarioRespaldo FOR LOGIN loginRespaldo;
ALTER ROLE db_backupoperator ADD MEMBER usuarioRespaldo;
GO

EXECUTE AS USER = 'usuarioRespaldo';
GO
BACKUP DATABASE NotasLab05
TO DISK = '/backup/NotasLab05/NotasLab05_operador.bak'
WITH INIT,
NAME = 'Respaldo del operador NotasLab05';
GO
SELECT calificacion_id, nota
FROM dbo.Calificacion;
GO
REVERT;
GO

USE msdb;
GO
EXEC dbo.sp_add_job
     @job_name = N'Respaldo diario NotasLab05';
EXEC dbo.sp_add_jobstep
     @job_name = N'Respaldo diario NotasLab05',
     @step_name = N'Respaldo completo',
     @subsystem = N'TSQL',
     @database_name = N'master',
     @command = N'BACKUP DATABASE NotasLab05
TO DISK = ''/backup/NotasLab05/NotasLab05_job.bak''
WITH INIT, COMPRESSION;';
EXEC dbo.sp_add_schedule
     @schedule_name = N'Diario 10 p. m.',
     @freq_type = 4,
     @freq_interval = 1,
     @active_start_time = 220000;
EXEC dbo.sp_attach_schedule
     @job_name = N'Respaldo diario NotasLab05',
     @schedule_name = N'Diario 10 p. m.';
EXEC dbo.sp_add_jobserver
     @job_name = N'Respaldo diario NotasLab05';
GO

EXEC msdb.dbo.sp_start_job
     @job_name = N'Respaldo diario NotasLab05';
GO

SELECT h.step_name AS Paso,
       h.run_status AS Estado,
       h.run_date AS Fecha,
       h.run_time AS Hora,
       h.message AS Mensaje
FROM msdb.dbo.sysjobhistory AS h
JOIN msdb.dbo.sysjobs AS j ON j.job_id = h.job_id
WHERE j.name = N'Respaldo diario NotasLab05'
ORDER BY h.instance_id;
GO

SELECT bmf.physical_device_name AS Archivo,
       bs.backup_size / 1024 AS TamanoKB,
       bs.compressed_backup_size / 1024 AS ComprimidoKB
FROM msdb.dbo.backupset AS bs
JOIN msdb.dbo.backupmediafamily AS bmf
  ON bmf.media_set_id = bs.media_set_id
WHERE bs.database_name = N'NotasLab05' AND bs.type = 'D'
ORDER BY bs.backup_set_id;
GO

-- -- LIMPIEZA OPCIONAL
-- USE msdb;
-- GO
-- EXEC dbo.sp_delete_job
--      @job_name = N'Respaldo diario NotasLab05',
--      @delete_unused_schedule = 1;
-- EXEC dbo.sp_delete_database_backuphistory
--      @database_name = N'NotasLab05';
-- GO
-- USE master;
-- GO
-- DROP DATABASE NotasLab05;
-- DROP LOGIN loginRespaldo;
-- GO

-- [PowerShell] docker exec sqlserver-2025 rm -rf /backup/NotasLab05

-- ========================================================================
-- Comandos de copias de seguridad
-- ========================================================================

-- ========================================================================
-- Ejercicio práctico
-- ========================================================================

-- ========================================================================
-- Créditos
-- ========================================================================
