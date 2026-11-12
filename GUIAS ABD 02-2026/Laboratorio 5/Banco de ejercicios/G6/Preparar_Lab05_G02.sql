-- Laboratorio 5 - Preparación inicial del grupo 2
USE master;
GO
PRINT N'Preparando Lab05_G02';
IF DB_ID(N'Lab05_G02') IS NULL EXEC(N'CREATE DATABASE [Lab05_G02]');
GO
ALTER DATABASE [Lab05_G02] SET RECOVERY FULL;
GO
USE [Lab05_G02];
GO
IF OBJECT_ID(N'dbo.RevisionEditorial', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.[RevisionEditorial] (id_revision INT PRIMARY KEY, titulo NVARCHAR(80) NOT NULL, estado NVARCHAR(30) NOT NULL, responsable NVARCHAR(60) NOT NULL);
END;
GO
IF NOT EXISTS (SELECT 1 FROM dbo.[RevisionEditorial])
BEGIN
    INSERT INTO dbo.[RevisionEditorial] ([id_revision],[titulo],[estado],[responsable]) VALUES
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

