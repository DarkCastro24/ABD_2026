-- Laboratorio 5 - Preparación inicial del grupo 1
USE master;
GO
PRINT N'Preparando Lab05_G01';
IF DB_ID(N'Lab05_G01') IS NULL EXEC(N'CREATE DATABASE [Lab05_G01]');
GO
ALTER DATABASE [Lab05_G01] SET RECOVERY FULL;
GO
USE [Lab05_G01];
GO
IF OBJECT_ID(N'dbo.EnvioControl', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.[EnvioControl] (id_envio INT PRIMARY KEY, transportista NVARCHAR(60) NOT NULL, estado NVARCHAR(30) NOT NULL, destino NVARCHAR(60) NOT NULL);
END;
GO
IF NOT EXISTS (SELECT 1 FROM dbo.[EnvioControl])
BEGIN
    INSERT INTO dbo.[EnvioControl] ([id_envio],[transportista],[estado],[destino]) VALUES
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

