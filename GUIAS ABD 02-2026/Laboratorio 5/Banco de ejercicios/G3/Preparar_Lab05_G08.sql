-- Laboratorio 5 - Preparación inicial del grupo 8
USE master;
GO
PRINT N'Preparando Lab05_G08';
IF DB_ID(N'Lab05_G08') IS NULL EXEC(N'CREATE DATABASE [Lab05_G08]');
GO
ALTER DATABASE [Lab05_G08] SET RECOVERY FULL;
GO
USE [Lab05_G08];
GO
IF OBJECT_ID(N'dbo.MantenimientoControl', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.[MantenimientoControl] (id_actividad INT PRIMARY KEY, equipo NVARCHAR(60) NOT NULL, actividad NVARCHAR(80) NOT NULL, estado NVARCHAR(25) NOT NULL);
END;
GO
IF NOT EXISTS (SELECT 1 FROM dbo.[MantenimientoControl])
BEGIN
    INSERT INTO dbo.[MantenimientoControl] ([id_actividad],[equipo],[actividad],[estado]) VALUES
    (1, N'Equipo A', N'Inspección', N'Finalizada'),
    (2, N'Equipo B', N'Lubricación', N'Pendiente'),
    (3, N'Equipo C', N'Cambio de filtro', N'En proceso'),
    (4, N'Equipo D', N'Revisión', N'Finalizada'),
    (5, N'Equipo E', N'Limpieza', N'Pendiente'),
    (6, N'Equipo F', N'Inspección', N'En proceso');
END;
GO

IF OBJECT_ID(N'dbo.InventarioAux', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.InventarioAux (
        id_repuesto INT PRIMARY KEY, nombre NVARCHAR(60) NOT NULL,
        unidades INT NOT NULL
    );
END;
GO
IF NOT EXISTS (SELECT 1 FROM dbo.InventarioAux)
BEGIN
    INSERT INTO dbo.InventarioAux VALUES
    (1,N'Filtro',8), (2,N'Correa',5),
    (3,N'Lubricante',12), (4,N'Tornillos',40);
END;
GO
USE master;
GO

