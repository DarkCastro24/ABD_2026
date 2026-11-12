-- Laboratorio 5 Grupo 6 | Set G02
-- PowerShell: docker exec sqlserver-2025 mkdir -p /backup/Lab05_G02

USE master;
GO
IF DB_ID(N'Lab05_G02') IS NULL EXEC(N'CREATE DATABASE Lab05_G02');
GO
ALTER DATABASE Lab05_G02 SET RECOVERY FULL;
GO
USE Lab05_G02;
GO
IF OBJECT_ID(N'dbo.RevisionEditorial', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.RevisionEditorial (id_revision INT PRIMARY KEY, titulo NVARCHAR(80) NOT NULL, estado NVARCHAR(30) NOT NULL, responsable NVARCHAR(60) NOT NULL);
END;
GO
IF NOT EXISTS (SELECT 1 FROM dbo.RevisionEditorial)
BEGIN
    INSERT INTO dbo.RevisionEditorial (id_revision,titulo,estado,responsable) VALUES
    (1, N'Atlas de Datos', N'En revisión', N'Marta'),
    (2, N'Bases Aplicadas', N'Aprobado', N'Diego'),
    (3, N'SQL para Todos', N'Pendiente', N'Lucía'),
    (4, N'Gestión de Libros', N'En revisión', N'Iván'),
    (5, N'Relatos Digitales', N'Pendiente', N'Sara'),
    (6, N'Catálogo Técnico', N'Aprobado', N'Mario');
END;
GO
USE master;
GO

-- Ejercicio 1 | SSMS. Consulta la tabla de origen. Si pubs no está disponible, el set permite escoger los ejercicios 2 y 4.
SELECT * FROM pubs.dbo.authors;
GO
-- PowerShell: docker exec -it sqlserver-2025 /opt/mssql-tools18/bin/bcp pubs.dbo.authors out /backup/Lab05_G02/G02_E1_authors.dat -n -S localhost -U sa -u
-- PowerShell: docker exec sqlserver-2025 ls -l /backup/Lab05_G02/G02_E1_authors.dat

-- Ejercicio 2 | SSMS: respaldo completo y recuperación de la base de práctica.
USE master;
SELECT * FROM Lab05_G02.dbo.RevisionEditorial ORDER BY id_revision;
BACKUP DATABASE Lab05_G02 TO DISK = '/backup/Lab05_G02/G02_E2_full.bak' WITH INIT, CHECKSUM, NAME = N'G02 E2 completo';
RESTORE VERIFYONLY FROM DISK = '/backup/Lab05_G02/G02_E2_full.bak' WITH CHECKSUM;
USE Lab05_G02;
DELETE dbo.RevisionEditorial WHERE id_revision=3;
SELECT * FROM Lab05_G02.dbo.RevisionEditorial ORDER BY id_revision;
USE master;
DROP DATABASE Lab05_G02;
RESTORE DATABASE Lab05_G02 FROM DISK = '/backup/Lab05_G02/G02_E2_full.bak' WITH RECOVERY, CHECKSUM;
SELECT * FROM Lab05_G02.dbo.RevisionEditorial ORDER BY id_revision;
GO

-- Ejercicio 3 | SSMS: SQL Server Agent. Horario de la instancia.
SELECT servicename,status_desc FROM sys.dm_server_services WHERE servicename LIKE N'SQL Server Agent%';
USE msdb;
IF NOT EXISTS (SELECT 1 FROM dbo.sysoperators WHERE name=N'G02_Operador')
    EXEC dbo.sp_add_operator @name=N'G02_Operador', @email_address=N'g02@laboratorio.local';
EXEC dbo.sp_add_job @job_name=N'G02_Respaldo_Diario';
EXEC dbo.sp_add_jobstep @job_name=N'G02_Respaldo_Diario', @step_name=N'Control diario',
    @subsystem=N'TSQL', @database_name=N'Lab05_G02', @command=N'BACKUP DATABASE Lab05_G02 TO DISK=''/backup/Lab05_G02/G02_E3_job.bak'' WITH INIT, CHECKSUM, COMPRESSION;';
EXEC dbo.sp_add_jobserver @job_name=N'G02_Respaldo_Diario';
EXEC dbo.sp_add_schedule @schedule_name=N'G02_Horario_Diario', @freq_type=4,
    @freq_interval=1, @active_start_time=210000;
EXEC dbo.sp_attach_schedule @job_name=N'G02_Respaldo_Diario', @schedule_name=N'G02_Horario_Diario';
EXEC dbo.sp_start_job @job_name=N'G02_Respaldo_Diario';
GO
-- Espera a que termine el Job antes de ejecutar este bloque.
USE msdb;
SELECT TOP (1) h.run_status, h.message
FROM dbo.sysjobhistory AS h JOIN dbo.sysjobs AS j ON j.job_id=h.job_id
WHERE j.name=N'G02_Respaldo_Diario' AND h.step_id=0 ORDER BY h.instance_id DESC;
RESTORE VERIFYONLY FROM DISK='/backup/Lab05_G02/G02_E3_job.bak' WITH CHECKSUM;
EXEC dbo.sp_update_job @job_name=N'G02_Respaldo_Diario', @notify_level_email=2, @notify_email_operator_name=N'G02_Operador';
SELECT j.name, j.notify_level_email, o.name AS operador, s.active_start_time
FROM dbo.sysjobs AS j JOIN dbo.sysoperators AS o ON o.id=j.notify_email_operator_id
JOIN dbo.sysjobschedules AS js ON js.job_id=j.job_id
JOIN dbo.sysschedules AS s ON s.schedule_id=js.schedule_id
WHERE j.name=N'G02_Respaldo_Diario';
GO

-- Ejercicio 4 | SSMS: recupera los cambios respaldados y compara el resultado.
USE master;
BACKUP DATABASE Lab05_G02 TO DISK='/backup/Lab05_G02/G02_E4_full.bak' WITH INIT, CHECKSUM;
RESTORE VERIFYONLY FROM DISK='/backup/Lab05_G02/G02_E4_full.bak' WITH CHECKSUM;
USE Lab05_G02;
INSERT dbo.RevisionEditorial VALUES (7,N'Manual de respaldos',N'Pendiente',N'Laura');
USE master;
BACKUP LOG Lab05_G02 TO DISK='/backup/Lab05_G02/G02_E4_log.trn' WITH INIT, CHECKSUM;
RESTORE VERIFYONLY FROM DISK='/backup/Lab05_G02/G02_E4_log.trn' WITH CHECKSUM;
USE Lab05_G02;
INSERT dbo.RevisionEditorial VALUES (8,N'Diccionario SQL',N'Pendiente',N'Andrés');
SELECT * FROM Lab05_G02.dbo.RevisionEditorial ORDER BY id_revision;
USE master;
DROP DATABASE Lab05_G02;
RESTORE DATABASE Lab05_G02 FROM DISK='/backup/Lab05_G02/G02_E4_full.bak' WITH NORECOVERY, CHECKSUM;
RESTORE LOG Lab05_G02 FROM DISK='/backup/Lab05_G02/G02_E4_log.trn' WITH RECOVERY, CHECKSUM;
SELECT * FROM Lab05_G02.dbo.RevisionEditorial ORDER BY id_revision;
GO
