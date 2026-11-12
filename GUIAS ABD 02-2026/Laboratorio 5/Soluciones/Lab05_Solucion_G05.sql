-- Laboratorio 5 Grupo 5
-- PowerShell: docker exec sqlserver-2025 mkdir -p /backup/Lab05_G05

USE master;
GO
IF DB_ID(N'Lab05_G05') IS NULL EXEC(N'CREATE DATABASE Lab05_G05');
GO
ALTER DATABASE Lab05_G05 SET RECOVERY FULL;
GO
USE Lab05_G05;
GO
IF OBJECT_ID(N'dbo.InscripcionControl', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.InscripcionControl (
        id_inscripcion INT PRIMARY KEY,
        actividad NVARCHAR(70) NOT NULL,
        cupos INT NOT NULL,
        estado NVARCHAR(25) NOT NULL
    );
    INSERT INTO dbo.InscripcionControl (id_inscripcion, actividad, cupos, estado) VALUES
    (1, N'Dibujo técnico', 12, N'Confirmada'),
    (2, N'Fotografía', 20, N'Confirmada'),
    (3, N'Diseño editorial', 16, N'Pendiente'),
    (4, N'Ilustración', 18, N'Confirmada'),
    (5, N'Tipografía', 14, N'Pendiente'),
    (6, N'Animación', 24, N'Confirmada');
END;
GO

USE master;
GO

-- Ejercicio 1 | SSMS
USE Lab05_G05;
SELECT id_inscripcion, cupos FROM dbo.InscripcionControl WHERE estado = N'Confirmada' ORDER BY id_inscripcion;
GO

docker exec sqlserver-2025 mkdir -p /backup/Lab05_G05
docker exec sqlserver-2025 ls -ld /backup/Lab05_G05


-- PowerShell: docker exec -it sqlserver-2025 /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -C -d Lab05_G05 -Q "SET NOCOUNT ON; SELECT id_inscripcion, cupos FROM dbo.InscripcionControl WHERE estado = 'Confirmada' ORDER BY id_inscripcion;" -s "," -W -h -1 -o /backup/Lab05_G05/G05_E1_confirmadas.csv
-- PowerShell: docker exec sqlserver-2025 cat /backup/Lab05_G05/G05_E1_confirmadas.csv

-- Ejercicio 2 | SSMS: respaldo completo y recuperación de la base de práctica.
USE master;
SELECT * FROM Lab05_G05.dbo.InscripcionControl ORDER BY id_inscripcion;
BACKUP DATABASE Lab05_G05 TO DISK = '/backup/Lab05_G05/G05_E2_full.bak' WITH INIT, CHECKSUM, NAME = N'G05 E2 completo';
RESTORE VERIFYONLY FROM DISK = '/backup/Lab05_G05/G05_E2_full.bak' WITH CHECKSUM;
USE Lab05_G05;
UPDATE dbo.InscripcionControl SET cupos=99 WHERE id_inscripcion=4;
SELECT * FROM Lab05_G05.dbo.InscripcionControl ORDER BY id_inscripcion;
USE master;
DROP DATABASE Lab05_G05;
RESTORE DATABASE Lab05_G05 FROM DISK = '/backup/Lab05_G05/G05_E2_full.bak' WITH RECOVERY, CHECKSUM;
SELECT * FROM Lab05_G05.dbo.InscripcionControl ORDER BY id_inscripcion;
GO

-- Ejercicio 3 | SSMS: SQL Server Agent. Horario de la instancia.
SELECT servicename,status_desc FROM sys.dm_server_services WHERE servicename LIKE N'SQL Server Agent%';
USE msdb;
IF NOT EXISTS (SELECT 1 FROM dbo.sysoperators WHERE name=N'G05_Operador')
    EXEC dbo.sp_add_operator @name=N'G05_Operador', @email_address=N'g05@laboratorio.local';
EXEC dbo.sp_add_job @job_name=N'G05_Respaldo_Inscripciones';
EXEC dbo.sp_add_jobstep @job_name=N'G05_Respaldo_Inscripciones', @step_name=N'Control diario',
    @subsystem=N'TSQL', @database_name=N'Lab05_G05', @command=N'BACKUP DATABASE Lab05_G05 TO DISK=''/backup/Lab05_G05/G05_E3_job.bak'' WITH INIT, CHECKSUM, COMPRESSION;';
EXEC dbo.sp_add_jobserver @job_name=N'G05_Respaldo_Inscripciones';
EXEC dbo.sp_add_schedule @schedule_name=N'G05_Horario_Diario', @freq_type=4,
    @freq_interval=1, @active_start_time=213000;
EXEC dbo.sp_attach_schedule @job_name=N'G05_Respaldo_Inscripciones', @schedule_name=N'G05_Horario_Diario';
EXEC dbo.sp_start_job @job_name=N'G05_Respaldo_Inscripciones';
GO
-- Espera a que termine el Job antes de ejecutar este bloque.
USE msdb;
SELECT TOP (1) h.run_status, h.message
FROM dbo.sysjobhistory AS h JOIN dbo.sysjobs AS j ON j.job_id=h.job_id
WHERE j.name=N'G05_Respaldo_Inscripciones' AND h.step_id=0 ORDER BY h.instance_id DESC;
RESTORE VERIFYONLY FROM DISK='/backup/Lab05_G05/G05_E3_job.bak' WITH CHECKSUM;
EXEC dbo.sp_update_job @job_name=N'G05_Respaldo_Inscripciones', @notify_level_email=2, @notify_email_operator_name=N'G05_Operador';
SELECT j.name, j.notify_level_email, o.name AS operador, s.active_start_time
FROM dbo.sysjobs AS j JOIN dbo.sysoperators AS o ON o.id=j.notify_email_operator_id
JOIN dbo.sysjobschedules AS js ON js.job_id=j.job_id
JOIN dbo.sysschedules AS s ON s.schedule_id=js.schedule_id
WHERE j.name=N'G05_Respaldo_Inscripciones';
GO

-- Ejercicio 4 | SSMS: recupera los cambios respaldados y compara el resultado.
USE master;
BACKUP DATABASE Lab05_G05 TO DISK='/backup/Lab05_G05/G05_E4_full.bak' WITH INIT, CHECKSUM;
RESTORE VERIFYONLY FROM DISK='/backup/Lab05_G05/G05_E4_full.bak' WITH CHECKSUM;
USE Lab05_G05;
INSERT dbo.InscripcionControl VALUES (7,N'Grabado',15,N'Confirmada'),(8,N'Cerámica',10,N'Pendiente');
USE master;
BACKUP DATABASE Lab05_G05 TO DISK='/backup/Lab05_G05/G05_E4_diff.bak' WITH DIFFERENTIAL, INIT, CHECKSUM;
RESTORE VERIFYONLY FROM DISK='/backup/Lab05_G05/G05_E4_diff.bak' WITH CHECKSUM;
USE Lab05_G05;
INSERT dbo.InscripcionControl VALUES (9,N'Pintura',19,N'Confirmada');
UPDATE dbo.InscripcionControl SET cupos=26 WHERE id_inscripcion=2;
USE master;
BACKUP LOG Lab05_G05 TO DISK='/backup/Lab05_G05/G05_E4_log.trn' WITH INIT, CHECKSUM;
RESTORE VERIFYONLY FROM DISK='/backup/Lab05_G05/G05_E4_log.trn' WITH CHECKSUM;
USE Lab05_G05;
INSERT dbo.InscripcionControl VALUES (10,N'Escultura',8,N'Pendiente');
SELECT * FROM Lab05_G05.dbo.InscripcionControl ORDER BY id_inscripcion;
USE master;
DROP DATABASE Lab05_G05;
RESTORE DATABASE Lab05_G05 FROM DISK='/backup/Lab05_G05/G05_E4_full.bak' WITH NORECOVERY, CHECKSUM;
RESTORE DATABASE Lab05_G05 FROM DISK='/backup/Lab05_G05/G05_E4_diff.bak' WITH NORECOVERY, CHECKSUM;
RESTORE LOG Lab05_G05 FROM DISK='/backup/Lab05_G05/G05_E4_log.trn' WITH RECOVERY, CHECKSUM;
SELECT * FROM Lab05_G05.dbo.InscripcionControl ORDER BY id_inscripcion;
GO
