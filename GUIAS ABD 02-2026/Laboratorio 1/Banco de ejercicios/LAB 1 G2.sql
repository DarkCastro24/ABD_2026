/* ============================================================
   LABORATORIO - GRUPO G2
   ============================================================ */
-- 1. EJERCICIO #30 - Conteo por Pedido
-- En la tabla Sales.SalesOrderDetail, muestra el ID del pedido,
-- el producto y el número total de artículos diferentes incluidos
-- en esa misma orden (COUNT() OVER (PARTITION BY SalesOrderID)).


-- 2. EJERCICIO #39 - Ranking de Cuotas por Territorio
-- Utiliza la tabla Sales.SalesPerson para clasificar a los vendedores
-- mediante RANK() según su cuota de ventas (SalesQuota), reiniciando
-- la clasificación para cada territorio (PARTITION BY TerritoryID).


-- 3. EJERCICIO #16 - Promedio de Peso
-- Lista únicamente los productos que tienen un peso registrado
-- (Weight IS NOT NULL) y muestra el peso promedio global de ese
-- subconjunto.


-- 4. EJERCICIO #38 - Primera Compra del Cliente (FIRST_VALUE)
-- Para cada cliente en Sales.SalesOrderHeader, muestra el total de su
-- orden actual y, en otra columna, el total de su primera orden histórica
-- utilizando FIRST_VALUE() ordenado por OrderDate.


-- 5. EJERCICIO #3 - Paginación de Órdenes
-- Asigna un número de fila secuencial a todas las órdenes de venta
-- (Sales.SalesOrderHeader) ordenadas desde la más antigua a la más
-- reciente utilizando ROW_NUMBER().
