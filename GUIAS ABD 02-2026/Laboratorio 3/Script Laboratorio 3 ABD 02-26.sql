-- Laboratorio 3 | Ciclo 02-2026 | Versión 1
-- Autor: Diego Eduardo Castro Quintanilla
-- Reservas ficticias de salas de cómputo universitarias.
-- Requiere C:\AuditLogs\ReservasLab03\ en el servidor y permisos de escritura del servicio.
-- Ejecuta cada bloque en orden y una sola vez, siguiendo la guía.

-- 1. Creación de la base de datos
USE master;
GO

CREATE DATABASE ReservasLab03;
GO

USE ReservasLab03;
GO

-- Datos ficticios de reservas de salas de cómputo.
CREATE TABLE dbo.ReservasLaboratorio (
    IdReserva INT PRIMARY KEY,
    Sala NVARCHAR(50) NOT NULL,
    FechaReserva DATE NOT NULL,
    Turno NVARCHAR(20) NOT NULL,
    Estado NVARCHAR(20) NOT NULL
);

INSERT INTO dbo.ReservasLaboratorio
    (IdReserva, Sala, FechaReserva, Turno, Estado)
VALUES (1, N'Sala de cómputo A', '2026-10-06', N'Mañana', N'Pendiente'),
       (2, N'Sala de cómputo B', '2026-10-06', N'Tarde', N'Confirmada'),
       (999, N'Sala de cómputo A', '2026-10-06', N'Mañana', N'Registro de prueba');
GO

-- 2. Creación y activación de la auditoría
USE master;
GO

-- El objeto de servidor define dónde quedarán los eventos.
CREATE SERVER AUDIT AuditoriaReservas
TO FILE (
    FILEPATH = N'C:\AuditLogs\ReservasLab03\',
    MAXSIZE = 10 MB,
    MAX_FILES = 5
)
WITH (QUEUE_DELAY = 1000, ON_FAILURE = CONTINUE);
GO

ALTER SERVER AUDIT AuditoriaReservas WITH (STATE = ON);
GO

USE ReservasLab03;
GO

-- La especificación elige las acciones sobre la tabla.
CREATE DATABASE AUDIT SPECIFICATION AuditoriaReservasDB
FOR SERVER AUDIT AuditoriaReservas
ADD (SELECT, INSERT, DELETE ON OBJECT::dbo.ReservasLaboratorio BY public)
WITH (STATE = ON);
GO

-- 3. Generar acciones
USE ReservasLab03;
GO

-- Revisa las reservas antes de modificar la copia de trabajo.
SELECT IdReserva, Sala, FechaReserva, Turno, Estado
FROM dbo.ReservasLaboratorio
ORDER BY IdReserva;

-- Registra una nueva reserva.
INSERT INTO dbo.ReservasLaboratorio
    (IdReserva, Sala, FechaReserva, Turno, Estado)
VALUES (3, N'Sala de cómputo C', '2026-10-07', N'Mañana', N'Pendiente');

-- Retira únicamente el registro de prueba.
DELETE FROM dbo.ReservasLaboratorio
WHERE IdReserva = 999;

-- Comprueba el estado final de las reservas.
SELECT IdReserva, Sala, FechaReserva, Turno, Estado
FROM dbo.ReservasLaboratorio
ORDER BY IdReserva;
GO

-- 4. Consultar eventos
USE master;
GO

SELECT event_time, action_id, succeeded,
       server_principal_name, database_name,
       schema_name, object_name, statement
FROM sys.fn_get_audit_file(
    N'C:\AuditLogs\ReservasLab03\*.sqlaudit', DEFAULT, DEFAULT)
WHERE database_name = N'ReservasLab03'
  AND schema_name = N'dbo'
  AND object_name = N'ReservasLaboratorio'
ORDER BY event_time DESC;
GO

-- Ejercicio guiado: resuelve las cinco tareas de la guía y conserva las evidencias.
