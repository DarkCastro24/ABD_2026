-- Laboratorio 5 | Ciclo 02-2026 | Versión 1
-- Autor: Diego Eduardo Castro Quintanilla
-- Fuente: G05.md. Regenerado por scripts/build-guide.cjs.
-- Ejemplos informativos: ejecuta por bloques en el orden de la guía sobre una base nueva.
-- Los comandos marcados con [PowerShell] se ejecutan en PowerShell, no en SSMS.
-- Antes de empezar, crea la carpeta /backup/NotasLab05 en el contenedor (sección Preparar el entorno).
-- La secuencia incluye un DROP DATABASE para simular la falla: no la ejecutes sobre una base real.
-- La limpieza final está comentada.

-- ========================================================================
-- Introducción
-- ========================================================================

-- ========================================================================
-- Objetivos de recuperación
-- ========================================================================

-- ========================================================================
-- Tipos de respaldo
-- ========================================================================

-- ========================================================================
-- Respaldar y restaurar
-- ========================================================================

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
    calificacion_id INT PRIMARY KEY,
    estudiante NVARCHAR(60) NOT NULL,
    nota DECIMAL(4,2) NOT NULL
);
INSERT INTO dbo.Calificacion (calificacion_id, estudiante, nota)
VALUES (1, N'Ana Martínez', 8.50), (2, N'Luis Hernández', 6.75),
       (3, N'María López', 9.25), (4, N'Carlos Rivas', 7.00),
       (5, N'Sofía Pérez', 8.00), (6, N'Jorge Ramírez', 5.50);
GO

-- Respaldo completo: calificaciones 1 a 6.
BACKUP DATABASE NotasLab05
TO DISK = '/backup/NotasLab05/NotasLab05_full.bak'
WITH FORMAT, INIT, NAME = 'Respaldo completo NotasLab05';

INSERT INTO dbo.Calificacion (calificacion_id, estudiante, nota)
VALUES (7, N'Valeria Castillo', 9.00), (8, N'Mario Flores', 6.25);

-- Respaldo diferencial: cambios desde el completo.
BACKUP DATABASE NotasLab05
TO DISK = '/backup/NotasLab05/NotasLab05_diff.bak'
WITH DIFFERENTIAL, INIT, NAME = 'Respaldo diferencial NotasLab05';

INSERT INTO dbo.Calificacion (calificacion_id, estudiante, nota)
VALUES (9, N'Lucía Morales', 8.75);
UPDATE dbo.Calificacion SET nota = 7.25 WHERE calificacion_id = 2;

-- Respaldo del log: transacciones registradas.
BACKUP LOG NotasLab05
TO DISK = '/backup/NotasLab05/NotasLab05_log.trn'
WITH INIT, NAME = 'Respaldo del log NotasLab05';

-- Cambio posterior al último respaldo.
INSERT INTO dbo.Calificacion (calificacion_id, estudiante, nota)
VALUES (10, N'Andrés Guzmán', 7.50);

-- Comprueba que el respaldo completo esté completo y sea legible.
RESTORE VERIFYONLY
FROM DISK = '/backup/NotasLab05/NotasLab05_full.bak';
GO

USE master;
GO
DROP DATABASE NotasLab05;
GO
RESTORE DATABASE NotasLab05
FROM DISK = '/backup/NotasLab05/NotasLab05_full.bak' WITH NORECOVERY;
RESTORE DATABASE NotasLab05
FROM DISK = '/backup/NotasLab05/NotasLab05_diff.bak' WITH NORECOVERY;
RESTORE LOG NotasLab05
FROM DISK = '/backup/NotasLab05/NotasLab05_log.trn' WITH RECOVERY;
GO
SELECT calificacion_id, estudiante, nota
FROM NotasLab05.dbo.Calificacion
ORDER BY calificacion_id;
GO

-- ========================================================================
-- Respaldos lógicos
-- ========================================================================

-- [PowerShell] docker exec sqlserver-2025 /opt/mssql-tools18/bin/bcp NotasLab05.dbo.Calificacion out /backup/NotasLab05/calificacion.dat -n -S localhost -U sa -P "Admin123!" -u

DELETE FROM NotasLab05.dbo.Calificacion;
GO

-- [PowerShell] docker exec sqlserver-2025 /opt/mssql-tools18/bin/bcp NotasLab05.dbo.Calificacion in /backup/NotasLab05/calificacion.dat -n -S localhost -U sa -P "Admin123!" -u

-- ========================================================================
-- Programar con SQL Agent
-- ========================================================================

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

EXEC msdb.dbo.sp_start_job @job_name = N'Respaldo diario NotasLab05';
GO

SELECT h.step_name, h.run_status, h.message
FROM msdb.dbo.sysjobhistory AS h
JOIN msdb.dbo.sysjobs AS j ON j.job_id = h.job_id
WHERE j.name = N'Respaldo diario NotasLab05';
GO

-- -- LIMPIEZA OPCIONAL
-- EXEC msdb.dbo.sp_delete_job
--      @job_name = N'Respaldo diario NotasLab05',
--      @delete_unused_schedule = 1;
-- EXEC msdb.dbo.sp_delete_database_backuphistory
--      @database_name = N'NotasLab05';
-- GO
-- USE master;
-- GO
-- DROP DATABASE NotasLab05;
-- GO

-- [PowerShell] docker exec sqlserver-2025 rm -rf /backup/NotasLab05

-- ========================================================================
-- Ejercicio práctico
-- ========================================================================

-- ========================================================================
-- Créditos
-- ========================================================================
