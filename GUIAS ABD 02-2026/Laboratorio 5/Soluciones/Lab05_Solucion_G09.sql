-- Laboratorio 5 Grupo 9
-- PowerShell: docker exec sqlserver-2025 mkdir -p /backup/Lab05_G09

USE master;
GO
IF DB_ID(N'Lab05_G09') IS NULL EXEC(N'CREATE DATABASE Lab05_G09');
GO
ALTER DATABASE Lab05_G09 SET RECOVERY FULL;
GO
USE Lab05_G09;
GO
IF OBJECT_ID(N'dbo.PrestamoControl', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.PrestamoControl (
        id_prestamo INT PRIMARY KEY,
        ejemplar NVARCHAR(70) NOT NULL,
        dias INT NOT NULL,
        estado NVARCHAR(25) NOT NULL
    );
    INSERT INTO dbo.PrestamoControl (id_prestamo, ejemplar, dias, estado) VALUES
    (1, N'Atlas escolar', 7, N'Activo'),
    (2, N'Manual de redes', 10, N'Devuelto'),
    (3, N'Guía de SQL', 7, N'Activo'),
    (4, N'Álgebra básica', 12, N'Activo'),
    (5, N'Diseño de datos', 5, N'Devuelto'),
    (6, N'Sistemas operativos', 9, N'Activo');
END;
GO

IF OBJECT_ID(N'dbo.BitacoraAgent', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.BitacoraAgent (
        id_evento INT IDENTITY(1,1) PRIMARY KEY,
        prestamos_activos INT NOT NULL,
        fecha DATETIME2 NOT NULL DEFAULT SYSDATETIME()
    );
END;
GO

USE master;
GO

-- Ejercicio 1 | SSMS: Lab05_G09 > Tareas > Generar scripts > dbo.PrestamoControl > Avanzadas > Esquema y datos. Guarda G09_E1_prestamos.sql y localiza CREATE TABLE e INSERT.
SELECT * FROM Lab05_G09.dbo.PrestamoControl;
GO

-- Ejercicio 2 | SSMS: respaldo completo y recuperación de la base de práctica.
USE master;
SELECT * FROM Lab05_G09.dbo.PrestamoControl ORDER BY id_prestamo;
BACKUP DATABASE Lab05_G09 TO DISK = '/backup/Lab05_G09/G09_E2_full.bak' WITH INIT, CHECKSUM, NAME = N'G09 E2 completo';
RESTORE VERIFYONLY FROM DISK = '/backup/Lab05_G09/G09_E2_full.bak' WITH CHECKSUM;
USE Lab05_G09;
DELETE dbo.PrestamoControl WHERE id_prestamo IN (2,5);
SELECT * FROM Lab05_G09.dbo.PrestamoControl ORDER BY id_prestamo;
USE master;
DROP DATABASE Lab05_G09;
RESTORE DATABASE Lab05_G09 FROM DISK = '/backup/Lab05_G09/G09_E2_full.bak' WITH RECOVERY, CHECKSUM;
SELECT * FROM Lab05_G09.dbo.PrestamoControl ORDER BY id_prestamo;
GO

-- Ejercicio 3 | SSMS: SQL Server Agent. Horario de la instancia.
SELECT servicename,status_desc FROM sys.dm_server_services WHERE servicename LIKE N'SQL Server Agent%';
USE msdb;
IF NOT EXISTS (SELECT 1 FROM dbo.sysoperators WHERE name=N'G09_Operador')
    EXEC dbo.sp_add_operator @name=N'G09_Operador', @email_address=N'g09@laboratorio.local';
EXEC dbo.sp_add_job @job_name=N'G09_Control_Diario';
EXEC dbo.sp_add_jobstep @job_name=N'G09_Control_Diario', @step_name=N'Control diario',
    @subsystem=N'TSQL', @database_name=N'Lab05_G09', @command=N'INSERT INTO dbo.BitacoraAgent (prestamos_activos) VALUES ((SELECT COUNT(*) FROM dbo.PrestamoControl WHERE estado=N''Activo''));';
EXEC dbo.sp_add_jobserver @job_name=N'G09_Control_Diario';
EXEC dbo.sp_add_schedule @schedule_name=N'G09_Horario_Diario', @freq_type=4,
    @freq_interval=1, @active_start_time=203000;
EXEC dbo.sp_attach_schedule @job_name=N'G09_Control_Diario', @schedule_name=N'G09_Horario_Diario';
EXEC dbo.sp_start_job @job_name=N'G09_Control_Diario';
GO
-- Espera a que termine el Job antes de ejecutar este bloque.
USE msdb;
SELECT TOP (1) h.run_status, h.message
FROM dbo.sysjobhistory AS h JOIN dbo.sysjobs AS j ON j.job_id=h.job_id
WHERE j.name=N'G09_Control_Diario' AND h.step_id=0 ORDER BY h.instance_id DESC;
SELECT TOP (1) * FROM Lab05_G09.dbo.BitacoraAgent ORDER BY id_evento DESC;
EXEC dbo.sp_update_job @job_name=N'G09_Control_Diario', @notify_level_email=2, @notify_email_operator_name=N'G09_Operador';
SELECT j.name, j.notify_level_email, o.name AS operador, s.active_start_time
FROM dbo.sysjobs AS j JOIN dbo.sysoperators AS o ON o.id=j.notify_email_operator_id
JOIN dbo.sysjobschedules AS js ON js.job_id=j.job_id
JOIN dbo.sysschedules AS s ON s.schedule_id=js.schedule_id
WHERE j.name=N'G09_Control_Diario';
GO

-- Ejercicio 4 | SSMS: recupera los cambios respaldados y compara el resultado.
USE master;
BACKUP DATABASE Lab05_G09 TO DISK='/backup/Lab05_G09/G09_E4_full.bak' WITH INIT, CHECKSUM;
RESTORE VERIFYONLY FROM DISK='/backup/Lab05_G09/G09_E4_full.bak' WITH CHECKSUM;
USE Lab05_G09;
UPDATE dbo.PrestamoControl SET dias=14 WHERE id_prestamo=3;
UPDATE dbo.PrestamoControl SET estado=N'Devuelto' WHERE id_prestamo=6;
USE master;
BACKUP DATABASE Lab05_G09 TO DISK='/backup/Lab05_G09/G09_E4_diff.bak' WITH DIFFERENTIAL, INIT, CHECKSUM;
RESTORE VERIFYONLY FROM DISK='/backup/Lab05_G09/G09_E4_diff.bak' WITH CHECKSUM;
USE Lab05_G09;
UPDATE dbo.PrestamoControl SET dias=30 WHERE id_prestamo=3;
SELECT * FROM Lab05_G09.dbo.PrestamoControl ORDER BY id_prestamo;
USE master;
DROP DATABASE Lab05_G09;
RESTORE DATABASE Lab05_G09 FROM DISK='/backup/Lab05_G09/G09_E4_full.bak' WITH NORECOVERY, CHECKSUM;
RESTORE DATABASE Lab05_G09 FROM DISK='/backup/Lab05_G09/G09_E4_diff.bak' WITH RECOVERY, CHECKSUM;
SELECT * FROM Lab05_G09.dbo.PrestamoControl ORDER BY id_prestamo;
GO
