-- Laboratorio 5 Grupo 1
-- PowerShell: docker exec sqlserver-2025 mkdir -p /backup/Lab05_G01

USE master;
GO
IF DB_ID(N'Lab05_G01') IS NULL EXEC(N'CREATE DATABASE Lab05_G01');
GO
ALTER DATABASE Lab05_G01 SET RECOVERY FULL;
GO
USE Lab05_G01;
GO
IF OBJECT_ID(N'dbo.EnvioControl', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.EnvioControl (id_envio INT PRIMARY KEY, transportista NVARCHAR(60) NOT NULL, estado NVARCHAR(30) NOT NULL, destino NVARCHAR(60) NOT NULL);
END;
GO
IF NOT EXISTS (SELECT 1 FROM dbo.EnvioControl)
BEGIN
    INSERT INTO dbo.EnvioControl (id_envio,transportista,estado,destino) VALUES
    (1, N'Express Central', N'Pendiente', N'Santa Ana'),
    (2, N'Ruta Norte', N'En tránsito', N'Chalatenango'),
    (3, N'Express Central', N'Entregado', N'San Salvador'),
    (4, N'Logística Azul', N'Pendiente', N'La Libertad'),
    (5, N'Ruta Norte', N'Entregado', N'Sonsonate'),
    (6, N'Logística Azul', N'En tránsito', N'Usulután');
END;
GO
USE master;
GO

-- Ejercicio 1 | SSMS: Northwind > Tareas > Generar scripts > dbo.Shippers > Avanzadas > Esquema y datos. Guarda G01_E1_Shippers.sql y localiza CREATE TABLE e INSERT.
SELECT * FROM Northwind.dbo.Shippers;
GO

-- Ejercicio 2 | SSMS: respaldo completo y recuperación de la base de práctica.
USE master;
SELECT * FROM Lab05_G01.dbo.EnvioControl ORDER BY id_envio;
BACKUP DATABASE Lab05_G01 TO DISK = '/backup/Lab05_G01/G01_E2_full.bak' WITH INIT, CHECKSUM, NAME = N'G01 E2 completo';
RESTORE VERIFYONLY FROM DISK = '/backup/Lab05_G01/G01_E2_full.bak' WITH CHECKSUM;
USE Lab05_G01;
DELETE dbo.EnvioControl WHERE id_envio IN (1,2);
SELECT * FROM Lab05_G01.dbo.EnvioControl ORDER BY id_envio;
USE master;
DROP DATABASE Lab05_G01;
RESTORE DATABASE Lab05_G01 FROM DISK = '/backup/Lab05_G01/G01_E2_full.bak' WITH RECOVERY, CHECKSUM;
SELECT * FROM Lab05_G01.dbo.EnvioControl ORDER BY id_envio;
GO

-- Ejercicio 3 | SSMS: SQL Server Agent. Horario de la instancia.
SELECT servicename,status_desc FROM sys.dm_server_services WHERE servicename LIKE N'SQL Server Agent%';
USE msdb;
IF NOT EXISTS (SELECT 1 FROM dbo.sysoperators WHERE name=N'G01_Operador')
    EXEC dbo.sp_add_operator @name=N'G01_Operador', @email_address=N'g01@laboratorio.local';
EXEC dbo.sp_add_job @job_name=N'G01_Respaldo_Diario';
EXEC dbo.sp_add_jobstep @job_name=N'G01_Respaldo_Diario', @step_name=N'Control diario',
    @subsystem=N'TSQL', @database_name=N'Lab05_G01', @command=N'BACKUP DATABASE Lab05_G01 TO DISK=''/backup/Lab05_G01/G01_E3_job.bak'' WITH INIT, CHECKSUM, COMPRESSION;';
EXEC dbo.sp_add_jobserver @job_name=N'G01_Respaldo_Diario';
EXEC dbo.sp_add_schedule @schedule_name=N'G01_Horario_Diario', @freq_type=4,
    @freq_interval=1, @active_start_time=220000;
EXEC dbo.sp_attach_schedule @job_name=N'G01_Respaldo_Diario', @schedule_name=N'G01_Horario_Diario';
EXEC dbo.sp_start_job @job_name=N'G01_Respaldo_Diario';
GO
-- Espera a que termine el Job antes de ejecutar este bloque.
USE msdb;
SELECT TOP (1) h.run_status, h.message
FROM dbo.sysjobhistory AS h JOIN dbo.sysjobs AS j ON j.job_id=h.job_id
WHERE j.name=N'G01_Respaldo_Diario' AND h.step_id=0 ORDER BY h.instance_id DESC;
RESTORE VERIFYONLY FROM DISK='/backup/Lab05_G01/G01_E3_job.bak' WITH CHECKSUM;
EXEC dbo.sp_update_job @job_name=N'G01_Respaldo_Diario', @notify_level_email=2, @notify_email_operator_name=N'G01_Operador';
SELECT j.name, j.notify_level_email, o.name AS operador, s.active_start_time
FROM dbo.sysjobs AS j JOIN dbo.sysoperators AS o ON o.id=j.notify_email_operator_id
JOIN dbo.sysjobschedules AS js ON js.job_id=j.job_id
JOIN dbo.sysschedules AS s ON s.schedule_id=js.schedule_id
WHERE j.name=N'G01_Respaldo_Diario';
GO

-- Ejercicio 4 | SSMS: recupera los cambios respaldados y compara el resultado.
USE master;
BACKUP DATABASE Lab05_G01 TO DISK='/backup/Lab05_G01/G01_E4_full.bak' WITH INIT, CHECKSUM;
RESTORE VERIFYONLY FROM DISK='/backup/Lab05_G01/G01_E4_full.bak' WITH CHECKSUM;
USE Lab05_G01;
INSERT dbo.EnvioControl VALUES (7,N'Ruta Centro',N'Pendiente',N'San Vicente'),(8,N'Logística Verde',N'Entregado',N'Morazán');
USE master;
BACKUP DATABASE Lab05_G01 TO DISK='/backup/Lab05_G01/G01_E4_diff.bak' WITH DIFFERENTIAL, INIT, CHECKSUM;
RESTORE VERIFYONLY FROM DISK='/backup/Lab05_G01/G01_E4_diff.bak' WITH CHECKSUM;
USE Lab05_G01;
INSERT dbo.EnvioControl VALUES (9,N'Ruta Este',N'Pendiente',N'La Unión');
SELECT * FROM Lab05_G01.dbo.EnvioControl ORDER BY id_envio;
USE master;
DROP DATABASE Lab05_G01;
RESTORE DATABASE Lab05_G01 FROM DISK='/backup/Lab05_G01/G01_E4_full.bak' WITH NORECOVERY, CHECKSUM;
RESTORE DATABASE Lab05_G01 FROM DISK='/backup/Lab05_G01/G01_E4_diff.bak' WITH RECOVERY, CHECKSUM;
SELECT * FROM Lab05_G01.dbo.EnvioControl ORDER BY id_envio;
GO
