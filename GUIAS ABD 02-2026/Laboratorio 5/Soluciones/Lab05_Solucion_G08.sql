-- Laboratorio 5 Grupo 8
-- PowerShell: docker exec sqlserver-2025 mkdir -p /backup/Lab05_G08

USE master;
GO
IF DB_ID(N'Lab05_G08') IS NULL EXEC(N'CREATE DATABASE Lab05_G08');
GO
ALTER DATABASE Lab05_G08 SET RECOVERY FULL;
GO
USE Lab05_G08;
GO
IF OBJECT_ID(N'dbo.MantenimientoControl', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.MantenimientoControl (id_actividad INT PRIMARY KEY, equipo NVARCHAR(60) NOT NULL, actividad NVARCHAR(80) NOT NULL, estado NVARCHAR(25) NOT NULL);
END;
GO
IF NOT EXISTS (SELECT 1 FROM dbo.MantenimientoControl)
BEGIN
    INSERT INTO dbo.MantenimientoControl (id_actividad,equipo,actividad,estado) VALUES
    (1, N'Equipo A', N'Inspección', N'Finalizada'),
    (2, N'Equipo B', N'Lubricación', N'Pendiente'),
    (3, N'Equipo C', N'Cambio de filtro', N'En proceso'),
    (4, N'Equipo D', N'Revisión', N'Finalizada'),
    (5, N'Equipo E', N'Limpieza', N'Pendiente'),
    (6, N'Equipo F', N'Inspección', N'En proceso');
END;
GO

IF OBJECT_ID(N'dbo.InventarioAux', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.InventarioAux (
        id_repuesto INT PRIMARY KEY, nombre NVARCHAR(60) NOT NULL,
        unidades INT NOT NULL
    );
END;
GO
IF NOT EXISTS (SELECT 1 FROM dbo.InventarioAux)
BEGIN
    INSERT INTO dbo.InventarioAux VALUES
    (1,N'Filtro',8), (2,N'Correa',5),
    (3,N'Lubricante',12), (4,N'Tornillos',40);
END;
GO
USE master;
GO

-- Ejercicio 1 | SSMS. Consulta la tabla de origen.
SELECT * FROM Lab05_G08.dbo.InventarioAux;
GO
-- PowerShell: docker exec -it sqlserver-2025 /opt/mssql-tools18/bin/bcp Lab05_G08.dbo.InventarioAux out /backup/Lab05_G08/G08_E1_repuestos.dat -n -S localhost -U sa -u
-- PowerShell: docker exec sqlserver-2025 ls -l /backup/Lab05_G08/G08_E1_repuestos.dat

-- Ejercicio 2 | SSMS: respaldo completo y recuperación de la base de práctica.
USE master;
SELECT * FROM Lab05_G08.dbo.MantenimientoControl ORDER BY id_actividad;
BACKUP DATABASE Lab05_G08 TO DISK = '/backup/Lab05_G08/G08_E2_full.bak' WITH INIT, CHECKSUM, NAME = N'G08 E2 completo';
RESTORE VERIFYONLY FROM DISK = '/backup/Lab05_G08/G08_E2_full.bak' WITH CHECKSUM;
USE Lab05_G08;
DELETE dbo.MantenimientoControl WHERE id_actividad IN (2,5);
SELECT * FROM Lab05_G08.dbo.MantenimientoControl ORDER BY id_actividad;
USE master;
DROP DATABASE Lab05_G08;
RESTORE DATABASE Lab05_G08 FROM DISK = '/backup/Lab05_G08/G08_E2_full.bak' WITH RECOVERY, CHECKSUM;
SELECT * FROM Lab05_G08.dbo.MantenimientoControl ORDER BY id_actividad;
GO

-- Ejercicio 3 | SSMS: SQL Server Agent. Horario de la instancia.
SELECT servicename,status_desc FROM sys.dm_server_services WHERE servicename LIKE N'SQL Server Agent%';
USE msdb;
IF NOT EXISTS (SELECT 1 FROM dbo.sysoperators WHERE name=N'G08_Operador')
    EXEC dbo.sp_add_operator @name=N'G08_Operador', @email_address=N'g08@laboratorio.local';
EXEC dbo.sp_add_job @job_name=N'G08_Respaldo_Diario';
EXEC dbo.sp_add_jobstep @job_name=N'G08_Respaldo_Diario', @step_name=N'Control diario',
    @subsystem=N'TSQL', @database_name=N'Lab05_G08', @command=N'BACKUP DATABASE Lab05_G08 TO DISK=''/backup/Lab05_G08/G08_E3_job.bak'' WITH INIT, CHECKSUM, COMPRESSION;';
EXEC dbo.sp_add_jobserver @job_name=N'G08_Respaldo_Diario';
EXEC dbo.sp_add_schedule @schedule_name=N'G08_Horario_Diario', @freq_type=4,
    @freq_interval=1, @active_start_time=180000;
EXEC dbo.sp_attach_schedule @job_name=N'G08_Respaldo_Diario', @schedule_name=N'G08_Horario_Diario';
EXEC dbo.sp_start_job @job_name=N'G08_Respaldo_Diario';
GO
-- Espera a que termine el Job antes de ejecutar este bloque.
USE msdb;
SELECT TOP (1) h.run_status, h.message
FROM dbo.sysjobhistory AS h JOIN dbo.sysjobs AS j ON j.job_id=h.job_id
WHERE j.name=N'G08_Respaldo_Diario' AND h.step_id=0 ORDER BY h.instance_id DESC;
RESTORE VERIFYONLY FROM DISK='/backup/Lab05_G08/G08_E3_job.bak' WITH CHECKSUM;
EXEC dbo.sp_update_job @job_name=N'G08_Respaldo_Diario', @notify_level_email=2, @notify_email_operator_name=N'G08_Operador';
SELECT j.name, j.notify_level_email, o.name AS operador, s.active_start_time
FROM dbo.sysjobs AS j JOIN dbo.sysoperators AS o ON o.id=j.notify_email_operator_id
JOIN dbo.sysjobschedules AS js ON js.job_id=j.job_id
JOIN dbo.sysschedules AS s ON s.schedule_id=js.schedule_id
WHERE j.name=N'G08_Respaldo_Diario';
GO

-- Ejercicio 4 | SSMS: recupera los cambios respaldados y compara el resultado.
USE master;
BACKUP DATABASE Lab05_G08 TO DISK='/backup/Lab05_G08/G08_E4_full.bak' WITH INIT, CHECKSUM;
RESTORE VERIFYONLY FROM DISK='/backup/Lab05_G08/G08_E4_full.bak' WITH CHECKSUM;
USE Lab05_G08;
INSERT dbo.MantenimientoControl VALUES (7,N'Equipo G',N'Ajuste',N'Pendiente');
UPDATE dbo.MantenimientoControl SET estado=N'Finalizada' WHERE id_actividad=2;
USE master;
BACKUP DATABASE Lab05_G08 TO DISK='/backup/Lab05_G08/G08_E4_diff.bak' WITH DIFFERENTIAL, INIT, CHECKSUM;
RESTORE VERIFYONLY FROM DISK='/backup/Lab05_G08/G08_E4_diff.bak' WITH CHECKSUM;
USE Lab05_G08;
INSERT dbo.MantenimientoControl VALUES (8,N'Equipo H',N'Revisión',N'Pendiente');
SELECT * FROM Lab05_G08.dbo.MantenimientoControl ORDER BY id_actividad;
USE master;
DROP DATABASE Lab05_G08;
RESTORE DATABASE Lab05_G08 FROM DISK='/backup/Lab05_G08/G08_E4_full.bak' WITH NORECOVERY, CHECKSUM;
RESTORE DATABASE Lab05_G08 FROM DISK='/backup/Lab05_G08/G08_E4_diff.bak' WITH RECOVERY, CHECKSUM;
SELECT * FROM Lab05_G08.dbo.MantenimientoControl ORDER BY id_actividad;
GO
