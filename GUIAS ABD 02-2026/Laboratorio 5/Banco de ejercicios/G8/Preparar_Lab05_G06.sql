-- Laboratorio 5 - Preparación inicial del grupo 6
USE master;
GO
PRINT N'Preparando Lab05_G06';
IF DB_ID(N'Lab05_G06') IS NULL EXEC(N'CREATE DATABASE [Lab05_G06]');
GO
ALTER DATABASE [Lab05_G06] SET RECOVERY FULL;
GO
USE [Lab05_G06];
GO
IF OBJECT_ID(N'dbo.RegaliaControl', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.[RegaliaControl] (id_pago INT PRIMARY KEY, autor NVARCHAR(60) NOT NULL, monto DECIMAL(10,2) NOT NULL, estado NVARCHAR(25) NOT NULL);
END;
GO
IF NOT EXISTS (SELECT 1 FROM dbo.[RegaliaControl])
BEGIN
    INSERT INTO dbo.[RegaliaControl] ([id_pago],[autor],[monto],[estado]) VALUES
    (1, N'Alma Torres', 125.50, N'Pendiente'),
    (2, N'Carlos León', 240.00, N'Pagado'),
    (3, N'Miriam Rivas', 78.90, N'Pendiente'),
    (4, N'Edgar Luna', 153.20, N'Pagado'),
    (5, N'Julia Ríos', 98.00, N'Pendiente'),
    (6, N'Luis Mesa', 180.75, N'Pagado');
END;
GO
USE master;
GO

