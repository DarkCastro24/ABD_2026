-- Laboratorio 5 - Preparación inicial del grupo 5
USE master;
GO
IF DB_ID(N'Lab05_G05') IS NULL EXEC(N'CREATE DATABASE [Lab05_G05]');
GO
ALTER DATABASE [Lab05_G05] SET RECOVERY FULL;
GO
USE [Lab05_G05];
GO
IF OBJECT_ID(N'dbo.InscripcionControl', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.[InscripcionControl] (
        [id_inscripcion] INT PRIMARY KEY,
        [actividad] NVARCHAR(70) NOT NULL,
        [cupos] INT NOT NULL,
        estado NVARCHAR(25) NOT NULL
    );
    INSERT INTO dbo.[InscripcionControl] ([id_inscripcion], [actividad], [cupos], estado) VALUES
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
