-- Laboratorio 5 - Preparación inicial del grupo 9
USE master;
GO
IF DB_ID(N'Lab05_G09') IS NULL EXEC(N'CREATE DATABASE [Lab05_G09]');
GO
ALTER DATABASE [Lab05_G09] SET RECOVERY FULL;
GO
USE [Lab05_G09];
GO
IF OBJECT_ID(N'dbo.PrestamoControl', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.[PrestamoControl] (
        [id_prestamo] INT PRIMARY KEY,
        [ejemplar] NVARCHAR(70) NOT NULL,
        [dias] INT NOT NULL,
        estado NVARCHAR(25) NOT NULL
    );
    INSERT INTO dbo.[PrestamoControl] ([id_prestamo], [ejemplar], [dias], estado) VALUES
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
