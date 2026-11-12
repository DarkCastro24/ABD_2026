-- Laboratorio 5 | Ciclo 02-2026 | Versión 2
-- Autor: Diego Eduardo Castro Quintanilla
-- Fuente: G05.md. Regenerado por scripts/build-guide.cjs.
-- Ejecuta SOLO el bloque del paso actual, en el orden de la guía. No ejecutes todo el archivo.
-- Los comandos marcados con [PowerShell] se ejecutan en PowerShell, no en SSMS.
-- Antes de empezar, prepara /backup/NotasLab05 y comprueba que NotasLab05 no exista.
-- La secuencia incluye un DROP DATABASE para simular la falla: no la ejecutes sobre una base real.
-- La limpieza final está comentada.

-- ========================================================================
-- Introducción
-- ========================================================================

-- ========================================================================
-- RPO y RTO
-- ========================================================================

-- ========================================================================
-- Tipos de respaldo
-- ========================================================================

-- ========================================================================
-- Preparar el entorno
-- ========================================================================

-- Comprobar el contenedor
-- Lee la explicación y la comprobación de esta actividad en la guía.

-- [PowerShell] docker ps --filter "name=sqlserver-2025" --format "table {{.Names}}	{{.Status}}"

-- Crear la carpeta de respaldos
-- Lee la explicación y la comprobación de esta actividad en la guía.

-- [PowerShell] docker exec sqlserver-2025 mkdir -p /backup/NotasLab05
-- [PowerShell] docker exec sqlserver-2025 ls -d /backup/NotasLab05

-- Crear la base en FULL
-- Lee la explicación y la comprobación de esta actividad en la guía.

USE master;
IF DB_ID(N'NotasLab05') IS NOT NULL
    THROW 50001, N'NotasLab05 ya existe. Revisa el entorno antes de continuar.', 1;
EXEC(N'CREATE DATABASE NotasLab05');
EXEC(N'ALTER DATABASE NotasLab05 SET RECOVERY FULL');
SELECT name, recovery_model_desc, state_desc
FROM sys.databases WHERE name = N'NotasLab05';

-- Crear la tabla y los datos iniciales
-- Lee la explicación y la comprobación de esta actividad en la guía.

USE NotasLab05;
CREATE TABLE dbo.Calificacion (
    calificacion_id INT PRIMARY KEY,
    estudiante NVARCHAR(60) NOT NULL,
    nota DECIMAL(4,2) NOT NULL
);
INSERT INTO dbo.Calificacion VALUES
(1, N'Ana Martínez', 8.50), (2, N'Luis Hernández', 6.75),
(3, N'María López', 9.25), (4, N'Carlos Rivas', 7.00),
(5, N'Sofía Pérez', 8.00), (6, N'Jorge Ramírez', 5.50);
SELECT * FROM dbo.Calificacion ORDER BY calificacion_id;

-- ========================================================================
-- Crear respaldos
-- ========================================================================

-- Tomar el respaldo completo
-- Lee la explicación y la comprobación de esta actividad en la guía.

USE master;
BACKUP DATABASE NotasLab05
TO DISK = '/backup/NotasLab05/NotasLab05_full.bak'
WITH INIT, CHECKSUM, NAME = 'Completo NotasLab05';

-- Agregar las calificaciones 7 y 8
-- Lee la explicación y la comprobación de esta actividad en la guía.

USE NotasLab05;
INSERT INTO dbo.Calificacion VALUES
(7, N'Valeria Castillo', 9.00), (8, N'Mario Flores', 6.25);
SELECT COUNT(*) AS total_filas FROM dbo.Calificacion;

-- Tomar el respaldo diferencial
-- Lee la explicación y la comprobación de esta actividad en la guía.

USE master;
BACKUP DATABASE NotasLab05
TO DISK = '/backup/NotasLab05/NotasLab05_diff.bak'
WITH DIFFERENTIAL, INIT, CHECKSUM, NAME = 'Diferencial NotasLab05';

-- Agregar la calificación 9 y corregir una nota
-- Lee la explicación y la comprobación de esta actividad en la guía.

USE NotasLab05;
INSERT INTO dbo.Calificacion VALUES (9, N'Lucía Morales', 8.75);
UPDATE dbo.Calificacion SET nota = 7.25 WHERE calificacion_id = 2;
SELECT COUNT(*) AS total_filas,
       (SELECT nota FROM dbo.Calificacion WHERE calificacion_id = 2) AS nota_2
FROM dbo.Calificacion;

-- Respaldar el registro de transacciones
-- Lee la explicación y la comprobación de esta actividad en la guía.

USE master;
BACKUP LOG NotasLab05
TO DISK = '/backup/NotasLab05/NotasLab05_log.trn'
WITH INIT, CHECKSUM, NAME = 'Log NotasLab05';

-- Agregar un dato que quedará sin respaldo
-- Lee la explicación y la comprobación de esta actividad en la guía.

USE NotasLab05;
INSERT INTO dbo.Calificacion VALUES (10, N'Andrés Guzmán', 7.50);
SELECT COUNT(*) AS total_filas FROM dbo.Calificacion;

-- Revisar los archivos creados
-- Lee la explicación y la comprobación de esta actividad en la guía.

-- [PowerShell] docker exec sqlserver-2025 ls -1 /backup/NotasLab05

-- Verificar que los respaldos son legibles
-- Lee la explicación y la comprobación de esta actividad en la guía.

USE master;
RESTORE VERIFYONLY FROM DISK = '/backup/NotasLab05/NotasLab05_full.bak' WITH CHECKSUM;
RESTORE VERIFYONLY FROM DISK = '/backup/NotasLab05/NotasLab05_diff.bak' WITH CHECKSUM;
RESTORE VERIFYONLY FROM DISK = '/backup/NotasLab05/NotasLab05_log.trn' WITH CHECKSUM;

-- ========================================================================
-- Restaurar la base
-- ========================================================================

-- Simular la pérdida de la base
-- Lee la explicación y la comprobación de esta actividad en la guía.

USE master;
DROP DATABASE NotasLab05;
SELECT DB_ID(N'NotasLab05') AS base_existente;

-- Restaurar el completo
-- Lee la explicación y la comprobación de esta actividad en la guía.

USE master;
RESTORE DATABASE NotasLab05
FROM DISK = '/backup/NotasLab05/NotasLab05_full.bak'
WITH NORECOVERY;
SELECT name, state_desc FROM sys.databases WHERE name = N'NotasLab05';

-- Restaurar el diferencial
-- Lee la explicación y la comprobación de esta actividad en la guía.

USE master;
RESTORE DATABASE NotasLab05
FROM DISK = '/backup/NotasLab05/NotasLab05_diff.bak'
WITH NORECOVERY;
SELECT name, state_desc FROM sys.databases WHERE name = N'NotasLab05';

-- Restaurar el log
-- Lee la explicación y la comprobación de esta actividad en la guía.

USE master;
RESTORE LOG NotasLab05
FROM DISK = '/backup/NotasLab05/NotasLab05_log.trn'
WITH RECOVERY;
SELECT name, state_desc FROM sys.databases WHERE name = N'NotasLab05';

-- Comprobar los datos recuperados
-- Lee la explicación y la comprobación de esta actividad en la guía.

USE NotasLab05;
SELECT calificacion_id, estudiante, nota
FROM dbo.Calificacion ORDER BY calificacion_id;

-- ========================================================================
-- Respaldos lógicos
-- ========================================================================

-- Exportar las nueve calificaciones
-- Lee la explicación y la comprobación de esta actividad en la guía.

-- [PowerShell] docker exec -it sqlserver-2025 /opt/mssql-tools18/bin/bcp NotasLab05.dbo.Calificacion out /backup/NotasLab05/calificacion.dat -n -S localhost -U sa -u

-- Vaciar la tabla de práctica
-- Lee la explicación y la comprobación de esta actividad en la guía.

USE NotasLab05;
DELETE FROM dbo.Calificacion;
SELECT COUNT(*) AS total_filas FROM dbo.Calificacion;

-- Importar las calificaciones
-- Lee la explicación y la comprobación de esta actividad en la guía.

-- [PowerShell] docker exec -it sqlserver-2025 /opt/mssql-tools18/bin/bcp NotasLab05.dbo.Calificacion in /backup/NotasLab05/calificacion.dat -n -S localhost -U sa -u

-- Comprobar la tabla importada
-- Lee la explicación y la comprobación de esta actividad en la guía.

USE NotasLab05;
SELECT COUNT(*) AS total_filas,
       (SELECT nota FROM dbo.Calificacion WHERE calificacion_id = 2) AS nota_2
FROM dbo.Calificacion;

-- Exportar una consulta con sqlcmd
-- Lee la explicación y la comprobación de esta actividad en la guía.

-- [PowerShell] docker exec -it sqlserver-2025 /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -C -d NotasLab05 -Q "SET NOCOUNT ON; SELECT calificacion_id, nota FROM dbo.Calificacion ORDER BY calificacion_id;" -s "," -W -h -1 -o /backup/NotasLab05/notas.csv

-- Leer el archivo exportado
-- Lee la explicación y la comprobación de esta actividad en la guía.

-- [PowerShell] docker exec sqlserver-2025 cat /backup/NotasLab05/notas.csv

-- ========================================================================
-- Respaldo automático
-- ========================================================================

-- Comprobar Agent y el horario del servidor
-- Lee la explicación y la comprobación de esta actividad en la guía.

USE master;
SELECT servicename, status_desc,
       DATEPART(TZOFFSET, SYSDATETIMEOFFSET()) AS desfase_utc_minutos
FROM sys.dm_server_services
WHERE servicename LIKE N'SQL Server Agent%';

-- Crear el trabajo y su acción
-- Lee la explicación y la comprobación de esta actividad en la guía.

USE msdb;
IF EXISTS (SELECT 1 FROM dbo.sysjobs WHERE name = N'Respaldo diario NotasLab05')
    THROW 50002, N'El job ya existe. No lo crees otra vez.', 1;
EXEC dbo.sp_add_job @job_name = N'Respaldo diario NotasLab05';
EXEC dbo.sp_add_jobstep
    @job_name = N'Respaldo diario NotasLab05',
    @step_name = N'Respaldo completo',
    @subsystem = N'TSQL', @database_name = N'master',
    @command = N'BACKUP DATABASE NotasLab05
TO DISK = ''/backup/NotasLab05/NotasLab05_job.bak''
WITH INIT, CHECKSUM, COMPRESSION;';
EXEC dbo.sp_add_jobserver @job_name = N'Respaldo diario NotasLab05';
SELECT name, enabled FROM dbo.sysjobs WHERE name = N'Respaldo diario NotasLab05';

-- Asignar la programación diaria
-- Lee la explicación y la comprobación de esta actividad en la guía.

USE msdb;
EXEC dbo.sp_add_schedule
    @schedule_name = N'NotasLab05_diario_22h_SV',
    @freq_type = 4, @freq_interval = 1,
    @active_start_time = 040000;
EXEC dbo.sp_attach_schedule
    @job_name = N'Respaldo diario NotasLab05',
    @schedule_name = N'NotasLab05_diario_22h_SV';
SELECT name, freq_type, freq_interval, active_start_time
FROM dbo.sysschedules WHERE name = N'NotasLab05_diario_22h_SV';

-- Ejecutar el job ahora
-- Lee la explicación y la comprobación de esta actividad en la guía.

EXEC msdb.dbo.sp_start_job @job_name = N'Respaldo diario NotasLab05';

-- Comprobar el resultado del job
-- Lee la explicación y la comprobación de esta actividad en la guía.

SELECT TOP (1) j.name AS trabajo, h.run_status,
       CASE h.run_status WHEN 1 THEN N'Correcto'
            WHEN 0 THEN N'Falló' ELSE N'Revisar historial' END AS resultado
FROM msdb.dbo.sysjobhistory AS h
JOIN msdb.dbo.sysjobs AS j ON j.job_id = h.job_id
WHERE j.name = N'Respaldo diario NotasLab05' AND h.step_id = 0
ORDER BY h.instance_id DESC;

-- ========================================================================
-- Notificaciones
-- ========================================================================

-- Consultar los perfiles de correo
-- Lee la explicación y la comprobación de esta actividad en la guía.

SELECT name AS perfil FROM msdb.dbo.sysmail_profile ORDER BY name;

-- Asociar el operador al job
-- Lee la explicación y la comprobación de esta actividad en la guía.

USE msdb;
IF NOT EXISTS (SELECT 1 FROM dbo.sysoperators WHERE name = N'operador_NotasLab05')
    EXEC dbo.sp_add_operator
        @name = N'operador_NotasLab05',
        @email_address = N'operador@notaslab05.local';
EXEC dbo.sp_update_job
    @job_name = N'Respaldo diario NotasLab05',
    @notify_level_email = 2,
    @notify_email_operator_name = N'operador_NotasLab05';
SELECT j.name AS trabajo, j.notify_level_email, o.name AS operador
FROM dbo.sysjobs AS j
JOIN dbo.sysoperators AS o ON o.id = j.notify_email_operator_id
WHERE j.name = N'Respaldo diario NotasLab05';

-- ========================================================================
-- Limpieza
-- ========================================================================

-- Eliminar los objetos del ejemplo
-- Lee la explicación y la comprobación de esta actividad en la guía.

-- -- LIMPIEZA OPCIONAL
-- USE msdb;
-- IF EXISTS (SELECT 1 FROM dbo.sysjobs WHERE name = N'Respaldo diario NotasLab05')
--     EXEC dbo.sp_delete_job @job_name = N'Respaldo diario NotasLab05', @delete_unused_schedule = 1;
-- IF EXISTS (SELECT 1 FROM dbo.sysoperators WHERE name = N'operador_NotasLab05')
--     EXEC dbo.sp_delete_operator @name = N'operador_NotasLab05';
-- EXEC dbo.sp_delete_database_backuphistory @database_name = N'NotasLab05';
-- USE master;
-- IF DB_ID(N'NotasLab05') IS NOT NULL DROP DATABASE NotasLab05;
-- SELECT DB_ID(N'NotasLab05') AS base_existente;

-- Eliminar los archivos del ejemplo
-- Lee la explicación y la comprobación de esta actividad en la guía.

-- [PowerShell] docker exec sqlserver-2025 rm -f /backup/NotasLab05/NotasLab05_full.bak /backup/NotasLab05/NotasLab05_diff.bak /backup/NotasLab05/NotasLab05_log.trn /backup/NotasLab05/NotasLab05_job.bak /backup/NotasLab05/calificacion.dat /backup/NotasLab05/notas.csv
-- [PowerShell] docker exec sqlserver-2025 rmdir /backup/NotasLab05

-- ========================================================================
-- Créditos
-- ========================================================================
