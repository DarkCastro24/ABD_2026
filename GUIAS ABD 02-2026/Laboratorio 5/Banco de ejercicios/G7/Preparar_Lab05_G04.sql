-- Laboratorio 5 - Preparación inicial del grupo 4
USE master;
GO
PRINT N'Preparando Lab05_G04';
IF DB_ID(N'Lab05_G04') IS NULL EXEC(N'CREATE DATABASE [Lab05_G04]');
GO
ALTER DATABASE [Lab05_G04] SET RECOVERY FULL;
GO
USE [Lab05_G04];
GO
IF OBJECT_ID(N'dbo.InventarioControl', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.[InventarioControl] (id_movimiento INT PRIMARY KEY, producto NVARCHAR(70) NOT NULL, cantidad INT NOT NULL, tipo NVARCHAR(25) NOT NULL);
END;
GO
IF NOT EXISTS (SELECT 1 FROM dbo.[InventarioControl])
BEGIN
    INSERT INTO dbo.[InventarioControl] ([id_movimiento],[producto],[cantidad],[tipo]) VALUES
    (1, N'Casco urbano', 15, N'Entrada'),
    (2, N'Guantes MTB', 7, N'Salida'),
    (3, N'Luz trasera', 22, N'Entrada'),
    (4, N'Cadena', 4, N'Salida'),
    (5, N'Bomba de aire', 12, N'Entrada'),
    (6, N'Candado', 5, N'Salida');
END;
GO

IF OBJECT_ID(N'dbo.CategoriaProducto', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.CategoriaProducto (
        categoria_id INT PRIMARY KEY, nombre NVARCHAR(50) NOT NULL,
        descripcion NVARCHAR(90) NOT NULL
    );
END;
GO
IF NOT EXISTS (SELECT 1 FROM dbo.CategoriaProducto)
BEGIN
    INSERT INTO dbo.CategoriaProducto VALUES
    (1,N'Accesorios',N'Accesorios de bicicleta'),
    (2,N'Seguridad',N'Articulos de proteccion'),
    (3,N'Repuestos',N'Piezas de mantenimiento'),
    (4,N'Herramientas',N'Equipo para servicio tecnico');
END;
GO
USE master;
GO

