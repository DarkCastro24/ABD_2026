-- Laboratorio 5 Grupo 3
-- PowerShell: docker exec sqlserver-2025 mkdir -p /backup/Lab05_G03

USE master;
GO
IF DB_ID(N'Lab05_G03') IS NULL EXEC(N'CREATE DATABASE Lab05_G03');
GO
ALTER DATABASE Lab05_G03 SET RECOVERY FULL;
GO
USE Lab05_G03;
GO
IF OBJECT_ID(N'dbo.JugadorControl', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.JugadorControl (id_jugador INT PRIMARY KEY, alias NVARCHAR(60) NOT NULL, puntuacion INT NOT NULL, nivel INT NOT NULL);
END;
GO
IF NOT EXISTS (SELECT 1 FROM dbo.JugadorControl)
BEGIN
    INSERT INTO dbo.JugadorControl (id_jugador,alias,puntuacion,nivel) VALUES
    (1, N'Nebula', 420, 8),
    (2, N'Pixel', 310, 6),
    (3, N'Cometa', 590, 10),
    (4, N'Orion', 280, 5),
    (5, N'Lince', 450, 9),
    (6, N'Nexus', 350, 7);
END;
GO

IF OBJECT_ID(N'dbo.BitacoraAgent', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.BitacoraAgent (
        id_evento INT IDENTITY(1,1) PRIMARY KEY,
        detalle NVARCHAR(100) NOT NULL,
        fecha DATETIME2 NOT NULL DEFAULT SYSDATETIME()
    );
END;
GO
USE master;
GO

-- Ejercicio 1 | SSMS
USE Lab05_G03;
SELECT id_jugador, alias, puntuacion FROM dbo.JugadorControl ORDER BY id_jugador;
GO
-- PowerShell: docker exec -it sqlserver-2025 /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -C -d Lab05_G03 -Q "SET NOCOUNT ON; SELECT id_jugador, alias, puntuacion FROM dbo.JugadorControl ORDER BY id_jugador;" -s "," -W -h -1 -o /backup/Lab05_G03/G03_E1_jugadores.txt
-- PowerShell: docker exec sqlserver-2025 cat /backup/Lab05_G03/G03_E1_jugadores.txt

-- Ejercicio 2 | SSMS: respaldo completo y recuperación de la base de práctica.
USE master;
SELECT * FROM Lab05_G03.dbo.JugadorControl ORDER BY id_jugador;
BACKUP DATABASE Lab05_G03 TO DISK = '/backup/Lab05_G03/G03_E2_full.bak' WITH INIT, CHECKSUM, NAME = N'G03 E2 completo';
RESTORE VERIFYONLY FROM DISK = '/backup/Lab05_G03/G03_E2_full.bak' WITH CHECKSUM;
USE Lab05_G03;
UPDATE dbo.JugadorControl SET puntuacion=9999 WHERE id_jugador=1;
SELECT * FROM Lab05_G03.dbo.JugadorControl ORDER BY id_jugador;
USE master;
DROP DATABASE Lab05_G03;
RESTORE DATABASE Lab05_G03 FROM DISK = '/backup/Lab05_G03/G03_E2_full.bak' WITH RECOVERY, CHECKSUM;
SELECT * FROM Lab05_G03.dbo.JugadorControl ORDER BY id_jugador;
GO

-- Ejercicio 3 | SSMS: SQL Server Agent. Horario de la instancia.
SELECT servicename,status_desc FROM sys.dm_server_services WHERE servicename LIKE N'SQL Server Agent%';
USE msdb;
IF NOT EXISTS (SELECT 1 FROM dbo.sysoperators WHERE name=N'G03_Operador')
    EXEC dbo.sp_add_operator @name=N'G03_Operador', @email_address=N'g03@laboratorio.local';
EXEC dbo.sp_add_job @job_name=N'G03_Registro_Diario';
EXEC dbo.sp_add_jobstep @job_name=N'G03_Registro_Diario', @step_name=N'Control diario',
    @subsystem=N'TSQL', @database_name=N'Lab05_G03', @command=N'INSERT INTO dbo.BitacoraAgent (detalle) VALUES (N''Control diario de sesiones'');';
EXEC dbo.sp_add_jobserver @job_name=N'G03_Registro_Diario';
EXEC dbo.sp_add_schedule @schedule_name=N'G03_Horario_Diario', @freq_type=4,
    @freq_interval=1, @active_start_time=200000;
EXEC dbo.sp_attach_schedule @job_name=N'G03_Registro_Diario', @schedule_name=N'G03_Horario_Diario';
EXEC dbo.sp_start_job @job_name=N'G03_Registro_Diario';
GO
-- Espera a que termine el Job antes de ejecutar este bloque.
USE msdb;
SELECT TOP (1) h.run_status, h.message
FROM dbo.sysjobhistory AS h JOIN dbo.sysjobs AS j ON j.job_id=h.job_id
WHERE j.name=N'G03_Registro_Diario' AND h.step_id=0 ORDER BY h.instance_id DESC;
SELECT TOP (1) * FROM Lab05_G03.dbo.BitacoraAgent ORDER BY id_evento DESC;
EXEC dbo.sp_update_job @job_name=N'G03_Registro_Diario', @notify_level_email=2, @notify_email_operator_name=N'G03_Operador';
SELECT j.name, j.notify_level_email, o.name AS operador, s.active_start_time
FROM dbo.sysjobs AS j JOIN dbo.sysoperators AS o ON o.id=j.notify_email_operator_id
JOIN dbo.sysjobschedules AS js ON js.job_id=j.job_id
JOIN dbo.sysschedules AS s ON s.schedule_id=js.schedule_id
WHERE j.name=N'G03_Registro_Diario';
GO

-- Ejercicio 4 | SSMS: recupera los cambios respaldados y compara el resultado.
USE master;
BACKUP DATABASE Lab05_G03 TO DISK='/backup/Lab05_G03/G03_E4_full.bak' WITH INIT, CHECKSUM;
RESTORE VERIFYONLY FROM DISK='/backup/Lab05_G03/G03_E4_full.bak' WITH CHECKSUM;
USE Lab05_G03;
UPDATE dbo.JugadorControl SET puntuacion=500 WHERE id_jugador=2;
UPDATE dbo.JugadorControl SET puntuacion=380 WHERE id_jugador=4;
USE master;
BACKUP DATABASE Lab05_G03 TO DISK='/backup/Lab05_G03/G03_E4_diff.bak' WITH DIFFERENTIAL, INIT, CHECKSUM;
RESTORE VERIFYONLY FROM DISK='/backup/Lab05_G03/G03_E4_diff.bak' WITH CHECKSUM;
USE Lab05_G03;
UPDATE dbo.JugadorControl SET puntuacion=9999 WHERE id_jugador=2;
SELECT * FROM Lab05_G03.dbo.JugadorControl ORDER BY id_jugador;
USE master;
DROP DATABASE Lab05_G03;
RESTORE DATABASE Lab05_G03 FROM DISK='/backup/Lab05_G03/G03_E4_full.bak' WITH NORECOVERY, CHECKSUM;
RESTORE DATABASE Lab05_G03 FROM DISK='/backup/Lab05_G03/G03_E4_diff.bak' WITH RECOVERY, CHECKSUM;
SELECT * FROM Lab05_G03.dbo.JugadorControl ORDER BY id_jugador;
GO
