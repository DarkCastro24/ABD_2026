/* ============================================================
   LABORATORIO - GRUPO G9
   ============================================================ */


-- Ejercicio 1. TASA DE CAMBIO BASE
-- Muestra las tasas de cambio de moneda desde Sales.CurrencyRate y adjunta
-- la tasa promedio global registrada en el sistema.
-----------------------------------------------------

-- Tabla a utilizar:
--   Sales.CurrencyRate.
-------------------------

-- Comandos requeridos:
--   SELECT, FROM, AVG(), OVER() y ORDER BY.
---------------------------------------------

-- Solución:
SELECT
    CurrencyRateID,
    CurrencyRateDate,
    FromCurrencyCode,
    ToCurrencyCode,
    AverageRate,
    AVG(AverageRate) OVER () AS TasaPromedioGlobal
FROM Sales.CurrencyRate
ORDER BY CurrencyRateDate, CurrencyRateID;
GO



-- Ejercicio 2. ACUMULADO DE VENTAS
-- Calcula el total acumulado del subtotal de ventas
-- (Sales.SalesOrderHeader), ordenado por la fecha de la orden y reiniciando
-- el cálculo para cada cliente
-- (PARTITION BY CustomerID ORDER BY OrderDate).
-----------------------------------------------------

-- Tabla a utilizar:
--   Sales.SalesOrderHeader.
-------------------------

-- Comandos requeridos:
--   SELECT, FROM, SUM(), OVER(), PARTITION BY, ORDER BY y
--   ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW.
---------------------------------------------

-- Solución:
SELECT
    CustomerID,
    SalesOrderID,
    OrderDate,
    SubTotal,
    SUM(SubTotal) OVER (
        PARTITION BY CustomerID
        ORDER BY OrderDate, SalesOrderID
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS AcumuladoVentasCliente
FROM Sales.SalesOrderHeader
ORDER BY CustomerID, OrderDate, SalesOrderID;
GO



-- Ejercicio 3. PROMEDIO DE COSTOS
-- Analiza el historial de costos (Production.ProductCostHistory), calculando
-- un promedio móvil del costo estándar, particionado por el ID del producto
-- y ordenado cronológicamente por la fecha de inicio (StartDate).
-----------------------------------------------------

-- Tabla a utilizar:
--   Production.ProductCostHistory.
-------------------------

-- Comandos requeridos:
--   SELECT, FROM, AVG(), OVER(), PARTITION BY, ORDER BY y
--   ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW.
---------------------------------------------

-- Solución:
SELECT
    ProductID,
    StartDate,
    StandardCost,
    AVG(StandardCost) OVER (
        PARTITION BY ProductID
        ORDER BY StartDate
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS PromedioAcumuladoCosto
FROM Production.ProductCostHistory
ORDER BY ProductID, StartDate;
GO



-- Ejercicio 4. VOLUMEN GLOBAL
-- Muestra el detalle de las órdenes (Sales.SalesOrderDetail) y añade una
-- columna con la suma total global de las cantidades solicitadas (OrderQty).
-----------------------------------------------------

-- Tabla a utilizar:
--   Sales.SalesOrderDetail.
-------------------------

-- Comandos requeridos:
--   SELECT, FROM, SUM(), OVER() y ORDER BY.
---------------------------------------------

-- Solución:
SELECT
    SalesOrderID,
    SalesOrderDetailID,
    ProductID,
    OrderQty,
    SUM(OrderQty) OVER () AS CantidadTotalGlobal
FROM Sales.SalesOrderDetail
ORDER BY SalesOrderID, SalesOrderDetailID;
GO



-- Ejercicio 5. RANGO PORCENTUAL
-- Calcula el rango porcentual de los empleados basándote en su tarifa
-- salarial base dentro de HumanResources.EmployeePayHistory. Esto indicará
-- en qué percentil salarial se encuentra cada empleado.
-----------------------------------------------------

-- Tabla a utilizar:
--   HumanResources.EmployeePayHistory.
-------------------------

-- Comandos requeridos:
--   SELECT, FROM, PERCENT_RANK(), OVER() y ORDER BY.
---------------------------------------------

-- Solución:
SELECT
    BusinessEntityID,
    RateChangeDate,
    Rate,
    PERCENT_RANK() OVER (
        ORDER BY Rate
    ) AS RangoPorcentual
FROM HumanResources.EmployeePayHistory
ORDER BY Rate, BusinessEntityID, RateChangeDate;
GO