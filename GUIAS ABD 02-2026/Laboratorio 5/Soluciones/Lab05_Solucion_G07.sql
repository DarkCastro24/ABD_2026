-- Laboratorio 5 Grupo 7 | Set G04
-- PowerShell: docker exec sqlserver-2025 mkdir -p /backup/Lab05_G04

USE master;
GO
IF DB_ID(N'Lab05_G04') IS NULL EXEC(N'CREATE DATABASE Lab05_G04');
GO
ALTER DATABASE Lab05_G04 SET RECOVERY FULL;
GO
USE Lab05_G04;
GO
IF OBJECT_ID(N'dbo.InventarioControl', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.InventarioControl (id_movimiento INT PRIMARY KEY, producto NVARCHAR(70) NOT NULL, cantidad INT NOT NULL, tipo NVARCHAR(25) NOT NULL);
END;
GO
IF NOT EXISTS (SELECT 1 FROM dbo.InventarioControl)
BEGIN
    INSERT INTO dbo.InventarioControl (id_movimiento,producto,cantidad,tipo) VALUES
    (1, N'Casco urbano', 15, N'Entrada'),
    (2, N'Guantes MTB', 7, N'Salida'),
    (3, N'Luz trasera', 22, N'Entrada'),
    (4, N'Cadena', 4, N'Salida'),
    (5, N'Bomba de aire', 12, N'Entrada'),
    (6, N'Candado', 5, N'Salida');
END;
GO

IF OBJECT_ID(N'dbo.CategoriaProducto', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.CategoriaProducto (
        categoria_id INT PRIMARY KEY, nombre NVARCHAR(50) NOT NULL,
        descripcion NVARCHAR(90) NOT NULL
    );
END;
GO
IF NOT EXISTS (SELECT 1 FROM dbo.CategoriaProducto)
BEGIN
    INSERT INTO dbo.CategoriaProducto VALUES
    (1,N'Accesorios',N'Accesorios de bicicleta'),
    (2,N'Seguridad',N'Articulos de proteccion'),
    (3,N'Repuestos',N'Piezas de mantenimiento'),
    (4,N'Herramientas',N'Equipo para servicio tecnico');
END;
GO
USE master;
GO

-- Ejercicio 1 | SSMS: Lab05_G04 > Tareas > Generar scripts > dbo.CategoriaProducto > Avanzadas > Esquema y datos. Guarda G04_E1_categorias.sql y localiza CREATE TABLE e INSERT.
SELECT * FROM Lab05_G04.dbo.CategoriaProducto;
GO

-- Ejercicio 2 | SSMS: respaldo completo y recuperación de la base de práctica.
USE master;
SELECT * FROM Lab05_G04.dbo.InventarioControl ORDER BY id_movimiento;
BACKUP DATABASE Lab05_G04 TO DISK = '/backup/Lab05_G04/G04_E2_full.bak' WITH INIT, CHECKSUM, NAME = N'G04 E2 completo';
RESTORE VERIFYONLY FROM DISK = '/backup/Lab05_G04/G04_E2_full.bak' WITH CHECKSUM;
USE Lab05_G04;
DELETE dbo.InventarioControl WHERE id_movimiento IN (1,2);
SELECT * FROM Lab05_G04.dbo.InventarioControl ORDER BY id_movimiento;
USE master;
DROP DATABASE Lab05_G04;
RESTORE DATABASE Lab05_G04 FROM DISK = '/backup/Lab05_G04/G04_E2_full.bak' WITH RECOVERY, CHECKSUM;
SELECT * FROM Lab05_G04.dbo.InventarioControl ORDER BY id_movimiento;
GO

-- Ejercicio 3 | SSMS: SQL Server Agent. Horario de la instancia.
SELECT servicename,status_desc FROM sys.dm_server_services WHERE servicename LIKE N'SQL Server Agent%';
USE msdb;
IF NOT EXISTS (SELECT 1 FROM dbo.sysoperators WHERE name=N'G04_Operador')
    EXEC dbo.sp_add_operator @name=N'G04_Operador', @email_address=N'g04@laboratorio.local';
EXEC dbo.sp_add_job @job_name=N'G04_Respaldo_Diario';
EXEC dbo.sp_add_jobstep @job_name=N'G04_Respaldo_Diario', @step_name=N'Control diario',
    @subsystem=N'TSQL', @database_name=N'Lab05_G04', @command=N'BACKUP DATABASE Lab05_G04 TO DISK=''/backup/Lab05_G04/G04_E3_job.bak'' WITH INIT, CHECKSUM, COMPRESSION;';
EXEC dbo.sp_add_jobserver @job_name=N'G04_Respaldo_Diario';
EXEC dbo.sp_add_schedule @schedule_name=N'G04_Horario_Diario', @freq_type=4,
    @freq_interval=1, @active_start_time=220000;
EXEC dbo.sp_attach_schedule @job_name=N'G04_Respaldo_Diario', @schedule_name=N'G04_Horario_Diario';
EXEC dbo.sp_start_job @job_name=N'G04_Respaldo_Diario';
GO
-- Espera a que termine el Job antes de ejecutar este bloque.
USE msdb;
SELECT TOP (1) h.run_status, h.message
FROM dbo.sysjobhistory AS h JOIN dbo.sysjobs AS j ON j.job_id=h.job_id
WHERE j.name=N'G04_Respaldo_Diario' AND h.step_id=0 ORDER BY h.instance_id DESC;
RESTORE VERIFYONLY FROM DISK='/backup/Lab05_G04/G04_E3_job.bak' WITH CHECKSUM;
EXEC dbo.sp_update_job @job_name=N'G04_Respaldo_Diario', @notify_level_email=2, @notify_email_operator_name=N'G04_Operador';
SELECT j.name, j.notify_level_email, o.name AS operador, s.active_start_time
FROM dbo.sysjobs AS j JOIN dbo.sysoperators AS o ON o.id=j.notify_email_operator_id
JOIN dbo.sysjobschedules AS js ON js.job_id=j.job_id
JOIN dbo.sysschedules AS s ON s.schedule_id=js.schedule_id
WHERE j.name=N'G04_Respaldo_Diario';
GO

-- Ejercicio 4 | SSMS: recupera los cambios respaldados y compara el resultado.
USE master;
BACKUP DATABASE Lab05_G04 TO DISK='/backup/Lab05_G04/G04_E4_full.bak' WITH INIT, CHECKSUM;
RESTORE VERIFYONLY FROM DISK='/backup/Lab05_G04/G04_E4_full.bak' WITH CHECKSUM;
USE Lab05_G04;
INSERT dbo.InventarioControl VALUES (7,N'Llave Allen',11,N'Entrada');
USE master;
BACKUP LOG Lab05_G04 TO DISK='/backup/Lab05_G04/G04_E4_log.trn' WITH INIT, CHECKSUM;
RESTORE VERIFYONLY FROM DISK='/backup/Lab05_G04/G04_E4_log.trn' WITH CHECKSUM;
USE Lab05_G04;
INSERT dbo.InventarioControl VALUES (8,N'Pedal',3,N'Salida');
SELECT * FROM Lab05_G04.dbo.InventarioControl ORDER BY id_movimiento;
USE master;
DROP DATABASE Lab05_G04;
RESTORE DATABASE Lab05_G04 FROM DISK='/backup/Lab05_G04/G04_E4_full.bak' WITH NORECOVERY, CHECKSUM;
RESTORE LOG Lab05_G04 FROM DISK='/backup/Lab05_G04/G04_E4_log.trn' WITH RECOVERY, CHECKSUM;
SELECT * FROM Lab05_G04.dbo.InventarioControl ORDER BY id_movimiento;
GO
