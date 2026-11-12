-- Laboratorio 5 - Preparación inicial del grupo 3
USE master;
GO
PRINT N'Preparando Lab05_G03';
IF DB_ID(N'Lab05_G03') IS NULL EXEC(N'CREATE DATABASE [Lab05_G03]');
GO
ALTER DATABASE [Lab05_G03] SET RECOVERY FULL;
GO
USE [Lab05_G03];
GO
IF OBJECT_ID(N'dbo.JugadorControl', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.[JugadorControl] (id_jugador INT PRIMARY KEY, alias NVARCHAR(60) NOT NULL, puntuacion INT NOT NULL, nivel INT NOT NULL);
END;
GO
IF NOT EXISTS (SELECT 1 FROM dbo.[JugadorControl])
BEGIN
    INSERT INTO dbo.[JugadorControl] ([id_jugador],[alias],[puntuacion],[nivel]) VALUES
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

