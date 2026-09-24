/* ============================================================
   LABORATORIO - GRUPO G5
   JUEVES 9:00 a. m. - 11:00 a. m.
   ============================================================ */


-- Ejercicio 1. MÁXIMO POR CARGO
-- Utiliza HumanResources.Employee para listar a los empleados y añadir una
-- columna que muestre la cantidad máxima de horas de enfermedad
-- (SickLeaveHours) permitidas, agrupadas por su cargo
-- (PARTITION BY JobTitle).
-----------------------------------------------------

-- Tabla a utilizar:
--   HumanResources.Employee.
-------------------------

-- Comandos requeridos:
--   SELECT, FROM, MAX(), OVER(), PARTITION BY y ORDER BY.
---------------------------------------------

-- Solución:
SELECT
    BusinessEntityID,
    JobTitle,
    SickLeaveHours,
    MAX(SickLeaveHours) OVER (
        PARTITION BY JobTitle
    ) AS MaximoHorasEnfermedadPorCargo
FROM HumanResources.Employee
ORDER BY JobTitle, BusinessEntityID;
GO



-- Ejercicio 2. RENDIMIENTO DE VENTAS
-- Compara el subtotal de cada orden de venta con el total acumulado histórico
-- específico del vendedor que la gestionó (PARTITION BY SalesPersonID).
-----------------------------------------------------

-- Tabla a utilizar:
--   Sales.SalesOrderHeader.
-------------------------

-- Comandos requeridos:
--   SELECT, FROM, SUM(), OVER(), PARTITION BY, ORDER BY,
--   ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW, WHERE e IS NOT NULL.
---------------------------------------------

-- Solución:
SELECT
    SalesOrderID,
    SalesPersonID,
    OrderDate,
    SubTotal,
    SUM(SubTotal) OVER (
        PARTITION BY SalesPersonID
        ORDER BY OrderDate, SalesOrderID
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS AcumuladoHistoricoVendedor
FROM Sales.SalesOrderHeader
WHERE SalesPersonID IS NOT NULL
ORDER BY SalesPersonID, OrderDate, SalesOrderID;
GO



-- Ejercicio 3. SUMA RODANTE DE COMPRAS
-- En Purchasing.PurchaseOrderHeader, calcula la suma móvil del subtotal de
-- los últimos 5 pedidos realizados a cada proveedor (VendorID), utilizando
-- el marco ROWS BETWEEN 4 PRECEDING AND CURRENT ROW.
-----------------------------------------------------

-- Tabla a utilizar:
--   Purchasing.PurchaseOrderHeader.
-------------------------

-- Comandos requeridos:
--   SELECT, FROM, SUM(), OVER(), PARTITION BY, ORDER BY y
--   ROWS BETWEEN 4 PRECEDING AND CURRENT ROW.
---------------------------------------------

-- Solución:
SELECT
    VendorID,
    PurchaseOrderID,
    OrderDate,
    SubTotal,
    SUM(SubTotal) OVER (
        PARTITION BY VendorID
        ORDER BY OrderDate, PurchaseOrderID
        ROWS BETWEEN 4 PRECEDING AND CURRENT ROW
    ) AS SumaUltimos5Pedidos
FROM Purchasing.PurchaseOrderHeader
ORDER BY VendorID, OrderDate, PurchaseOrderID;
GO



-- Ejercicio 4. SALARIO POR DEPARTAMENTO
-- Realiza un JOIN entre empleados y HumanResources.Department para mostrar
-- el salario de cada persona junto al salario promedio particionado por su
-- departamento. Muestra únicamente el departamento actual y el registro
-- salarial más reciente de cada empleado.
-----------------------------------------------------

-- Tablas a utilizar:
--   HumanResources.Employee.
--   HumanResources.EmployeeDepartmentHistory.
--   HumanResources.Department.
--   HumanResources.EmployeePayHistory.
-------------------------

-- Comandos requeridos:
--   SELECT, FROM, INNER JOIN, ON, AVG(), MAX(), OVER(), PARTITION BY,
--   WHERE, subconsulta correlacionada, IS NULL y ORDER BY.
---------------------------------------------

-- Solución:
SELECT
    e.BusinessEntityID,
    d.Name AS DepartmentName,
    eph.Rate AS SalarioActual,
    AVG(eph.Rate) OVER (
        PARTITION BY d.DepartmentID
    ) AS SalarioPromedioDepto
FROM HumanResources.Employee AS e
INNER JOIN HumanResources.EmployeeDepartmentHistory AS edh
    ON e.BusinessEntityID = edh.BusinessEntityID
    AND edh.EndDate IS NULL
INNER JOIN HumanResources.Department AS d
    ON edh.DepartmentID = d.DepartmentID
INNER JOIN HumanResources.EmployeePayHistory AS eph
    ON e.BusinessEntityID = eph.BusinessEntityID
WHERE eph.RateChangeDate = (
    SELECT MAX(eph2.RateChangeDate)
    FROM HumanResources.EmployeePayHistory AS eph2
    WHERE eph2.BusinessEntityID = e.BusinessEntityID
)
ORDER BY d.Name, e.BusinessEntityID;
GO



-- Ejercicio 5. PROMEDIO POR AÑO
-- Consulta Sales.SalesOrderHeader, muestra la fecha de la orden y calcula el
-- promedio del TotalDue particionando directamente por el año de la orden
-- (PARTITION BY YEAR(OrderDate)).
-----------------------------------------------------

-- Tabla a utilizar:
--   Sales.SalesOrderHeader.
-------------------------

-- Comandos requeridos:
--   SELECT, FROM, AVG(), OVER(), PARTITION BY, YEAR() y ORDER BY.
---------------------------------------------

-- Solución:
SELECT
    SalesOrderID,
    OrderDate,
    TotalDue,
    AVG(TotalDue) OVER (
        PARTITION BY YEAR(OrderDate)
    ) AS PromedioTotalDuePorAnio
FROM Sales.SalesOrderHeader
ORDER BY OrderDate, SalesOrderID;
GO