/*
===============================================================================
 APUNTES DE CLASE - ADMINISTRACIÓN DE BASES DE DATOS
 Clases 04 y 05: Funciones ventana, CTE, CTE recursivas, PIVOT y UNPIVOT
===============================================================================

 Estos apuntes reúnen los ejemplos guiados y los ejercicios trabajados en clase.
 La idea es ejecutar cada bloque por separado y revisar cómo cambia el resultado.

 Bases utilizadas:
   - pubs: ventas de libros, editoriales, autores y tiendas.
   - Northwind: clientes, pedidos, empleados y detalle de ventas.

 Nota personal:
   - OVER() permite calcular sobre otras filas sin perder el detalle.
   - PARTITION BY reinicia el cálculo por grupo.
   - ORDER BY define el orden usado por rankings, acumulados y LAG/LEAD.
   - Los nombres y algunos valores pueden variar según la versión restaurada.
===============================================================================
*/


/*#############################################################################
  CLASE 04 - FUNCIONES VENTANA
  Base principal utilizada durante la clase: pubs
#############################################################################*/


/*-----------------------------------------------------------------------------
  EJEMPLO 04.1 - El problema que existía antes de las funciones ventana
  Base de datos: pubs
  Función: comparar un ranking con subconsulta frente a RANK() OVER().
  Apunte: la diapositiva usaba una tabla Employees conceptual; aquí se adaptó
          el mismo patrón a titles para que el ejemplo sí sea ejecutable.
-----------------------------------------------------------------------------*/
USE pubs;
GO

-- Forma antigua: una subconsulta correlacionada cuenta cuántos precios son mayores.
SELECT
    t1.title_id,
    t1.title,
    t1.price,
    1 + (
        SELECT COUNT(*)
        FROM titles AS t2
        WHERE t2.price > t1.price
    ) AS ranking_con_subconsulta
FROM titles AS t1
WHERE t1.price IS NOT NULL
ORDER BY t1.price DESC;

-- Forma actual: la función ventana expresa directamente la intención.
SELECT
    title_id,
    title,
    price,
    RANK() OVER (ORDER BY price DESC) AS ranking_con_ventana
FROM titles
WHERE price IS NOT NULL
ORDER BY ranking_con_ventana, title;
GO


/*-----------------------------------------------------------------------------
  EJERCICIO 04.2 - Agregación básica de libros vendidos
  Base de datos: pubs
  Función: obtener la cantidad total de copias vendidas por título.
  Apunte: este es el punto de partida antes de agregar las ventanas.
-----------------------------------------------------------------------------*/
USE pubs;
GO

SELECT
    t.title_id,
    t.title,
    SUM(s.qty) AS copiasVendidas
FROM titles AS t
JOIN sales AS s
    ON t.title_id = s.title_id
GROUP BY t.title_id, t.title
ORDER BY copiasVendidas DESC;
GO


/*-----------------------------------------------------------------------------
  EJERCICIO 04.3 - Venta total generada por cada libro
  Base de datos: pubs
  Función: agregar el ingreso estimado usando cantidad por precio.
  Apunte: ISNULL evita que un precio NULL vuelva NULL toda la multiplicación.
-----------------------------------------------------------------------------*/
USE pubs;
GO

SELECT
    t.title_id,
    t.title,
    SUM(s.qty) AS copiasVendidas,
    SUM(s.qty * ISNULL(t.price, 0)) AS totalVendido
FROM titles AS t
JOIN sales AS s
    ON t.title_id = s.title_id
GROUP BY t.title_id, t.title
ORDER BY totalVendido DESC;
GO


/*-----------------------------------------------------------------------------
  EJERCICIO 04.4 - Comparación de ROW_NUMBER, RANK y DENSE_RANK
  Base de datos: pubs
  Función: clasificar los libros por el ingreso total generado.
  Apunte:
    - ROW_NUMBER siempre genera números diferentes.
    - RANK comparte posición en empates y deja saltos.
    - DENSE_RANK comparte posición, pero no deja saltos.
-----------------------------------------------------------------------------*/
USE pubs;
GO

SELECT
    t.title_id,
    t.title,
    SUM(s.qty) AS copiasVendidas,
    SUM(s.qty * ISNULL(t.price, 0)) AS totalVendido,
    ROW_NUMBER() OVER (
        ORDER BY SUM(s.qty * ISNULL(t.price, 0)) DESC
    ) AS rankingConsecutivo,
    RANK() OVER (
        ORDER BY SUM(s.qty * ISNULL(t.price, 0)) DESC
    ) AS rankingConSaltos,
    DENSE_RANK() OVER (
        ORDER BY SUM(s.qty * ISNULL(t.price, 0)) DESC
    ) AS rankingSinSaltos
FROM titles AS t
JOIN sales AS s
    ON t.title_id = s.title_id
GROUP BY t.title_id, t.title
ORDER BY rankingConSaltos, t.title;
GO


/*-----------------------------------------------------------------------------
  EJERCICIO 04.5 - Ranking general de ventas por editorial
  Base de datos: pubs
  Función: comparar editoriales por copias e ingreso total.
-----------------------------------------------------------------------------*/
USE pubs;
GO

SELECT
    p.pub_id,
    p.pub_name,
    SUM(s.qty) AS copiasVendidas,
    SUM(s.qty * ISNULL(t.price, 0)) AS totalVendido,
    RANK() OVER (
        ORDER BY SUM(s.qty * ISNULL(t.price, 0)) DESC
    ) AS rankingEditorial
FROM publishers AS p
JOIN titles AS t
    ON p.pub_id = t.pub_id
JOIN sales AS s
    ON t.title_id = s.title_id
GROUP BY p.pub_id, p.pub_name
ORDER BY rankingEditorial, p.pub_name;
GO


/*-----------------------------------------------------------------------------
  EJERCICIO 04.6 - Ranking de libros dentro de cada editorial
  Base de datos: pubs
  Función: reiniciar el ranking por editorial usando PARTITION BY.
  Apunte: SUM(SUM(...)) OVER calcula el ingreso completo de la editorial
          después de que GROUP BY obtuvo el total de cada libro.
-----------------------------------------------------------------------------*/
USE pubs;
GO

SELECT
    p.pub_id,
    p.pub_name,
    t.title_id,
    t.title,
    SUM(s.qty) AS copiasVendidas,
    SUM(s.qty * ISNULL(t.price, 0)) AS totalVendido,
    RANK() OVER (
        PARTITION BY p.pub_id
        ORDER BY SUM(s.qty) DESC
    ) AS rankingLibroEditorial,
    SUM(SUM(s.qty * ISNULL(t.price, 0))) OVER (
        PARTITION BY p.pub_id
    ) AS ingresoEditorial
FROM publishers AS p
JOIN titles AS t
    ON p.pub_id = t.pub_id
JOIN sales AS s
    ON t.title_id = s.title_id
GROUP BY p.pub_id, p.pub_name, t.title_id, t.title
ORDER BY p.pub_name, rankingLibroEditorial, t.title;
GO


/*-----------------------------------------------------------------------------
  RETO 04.7 - Top 3 de libros por editorial
  Base de datos: pubs
  Función: calcular el ranking en un CTE y filtrarlo en la consulta externa.
  Apunte: una función ventana no se puede filtrar directamente en WHERE.
-----------------------------------------------------------------------------*/
USE pubs;
GO

;WITH LibrosPorEditorial AS (
    SELECT
        p.pub_id,
        p.pub_name,
        t.title_id,
        t.title,
        SUM(s.qty) AS copiasVendidas,
        SUM(s.qty * ISNULL(t.price, 0)) AS totalVendido,
        RANK() OVER (
            PARTITION BY p.pub_id
            ORDER BY SUM(s.qty) DESC
        ) AS posicion,
        SUM(SUM(s.qty * ISNULL(t.price, 0))) OVER (
            PARTITION BY p.pub_id
        ) AS ingresoEditorial
    FROM publishers AS p
    JOIN titles AS t
        ON p.pub_id = t.pub_id
    JOIN sales AS s
        ON t.title_id = s.title_id
    GROUP BY p.pub_id, p.pub_name, t.title_id, t.title
)
SELECT
    pub_id,
    pub_name,
    title_id,
    title,
    copiasVendidas,
    totalVendido,
    posicion,
    ingresoEditorial
FROM LibrosPorEditorial
WHERE posicion <= 3
ORDER BY pub_name, posicion, title;
GO


/*-----------------------------------------------------------------------------
  RETO 04.8 - Editorial con mayor ingreso
  Base de datos: pubs
  Función: resumir el ingreso por editorial y conservar empates con TOP WITH TIES.
-----------------------------------------------------------------------------*/
USE pubs;
GO

;WITH IngresosEditorial AS (
    SELECT
        p.pub_id,
        p.pub_name,
        SUM(s.qty * ISNULL(t.price, 0)) AS ingresoEditorial
    FROM publishers AS p
    JOIN titles AS t
        ON p.pub_id = t.pub_id
    JOIN sales AS s
        ON t.title_id = s.title_id
    GROUP BY p.pub_id, p.pub_name
)
SELECT TOP (1) WITH TIES
    pub_id,
    pub_name,
    ingresoEditorial
FROM IngresosEditorial
ORDER BY ingresoEditorial DESC;
GO


/*-----------------------------------------------------------------------------
  EJERCICIO 04.9 - Promedio de regalías por autor
  Base de datos: pubs
  Función: promediar regalías y crear un ranking sin saltos.
-----------------------------------------------------------------------------*/
USE pubs;
GO

SELECT
    a.au_id,
    a.au_fname,
    a.au_lname,
    AVG(CAST(t.royalty AS decimal(10, 2))) AS promedioRegalia,
    DENSE_RANK() OVER (
        ORDER BY AVG(CAST(t.royalty AS decimal(10, 2))) DESC
    ) AS ranking
FROM authors AS a
JOIN titleauthor AS ta
    ON a.au_id = ta.au_id
JOIN titles AS t
    ON ta.title_id = t.title_id
GROUP BY a.au_id, a.au_fname, a.au_lname
ORDER BY ranking, a.au_lname, a.au_fname;
GO


/*-----------------------------------------------------------------------------
  EJERCICIO 04.10 - Desempeño por tienda
  Base de datos: pubs
  Función: contar pedidos, sumar copias e ingresos y clasificar las tiendas.
-----------------------------------------------------------------------------*/
USE pubs;
GO

SELECT
    st.stor_id,
    st.stor_name,
    COUNT(DISTINCT s.ord_num) AS numeroPedidos,
    SUM(s.qty) AS copias,
    SUM(s.qty * ISNULL(t.price, 0)) AS ventaTotal,
    RANK() OVER (
        ORDER BY SUM(s.qty * ISNULL(t.price, 0)) DESC
    ) AS ranking
FROM stores AS st
JOIN sales AS s
    ON st.stor_id = s.stor_id
JOIN titles AS t
    ON s.title_id = t.title_id
GROUP BY st.stor_id, st.stor_name
ORDER BY ranking, st.stor_name;
GO


/*-----------------------------------------------------------------------------
  EJERCICIO 04.11 - Evolución de ventas por trimestre
  Base de datos: pubs
  Función: combinar CTE, SUM acumulado, LAG y diferencia entre periodos.
  Apunte: ROWS BETWEEN hace explícito que el acumulado inicia en la primera fila.
-----------------------------------------------------------------------------*/
USE pubs;
GO

;WITH VentasTrimestrales AS (
    SELECT
        DATEPART(YEAR, s.ord_date) AS anio,
        DATEPART(QUARTER, s.ord_date) AS trimestre,
        SUM(s.qty * ISNULL(t.price, 0)) AS ventas
    FROM sales AS s
    JOIN titles AS t
        ON s.title_id = t.title_id
    GROUP BY
        DATEPART(YEAR, s.ord_date),
        DATEPART(QUARTER, s.ord_date)
),
Comparacion AS (
    SELECT
        anio,
        trimestre,
        ventas,
        SUM(ventas) OVER (
            PARTITION BY anio
            ORDER BY trimestre
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS acumulado,
        LAG(ventas) OVER (
            ORDER BY anio, trimestre
        ) AS ventaTrimestreAnterior
    FROM VentasTrimestrales
)
SELECT
    anio,
    trimestre,
    ventas,
    acumulado,
    ventaTrimestreAnterior,
    ventas - ventaTrimestreAnterior AS diferencia
FROM Comparacion
ORDER BY anio, trimestre;
GO


/*-----------------------------------------------------------------------------
  APUNTE 04.12 - FIRST_VALUE, LAST_VALUE y aporte porcentual
  Base de datos: pubs
  Función: practicar los otros usos mencionados en la tabla introductoria.
  Apunte: LAST_VALUE necesita terminar el marco en UNBOUNDED FOLLOWING para
          devolver el último valor de toda la partición y no solo el actual.
-----------------------------------------------------------------------------*/
USE pubs;
GO

;WITH VentasLibros AS (
    SELECT
        p.pub_id,
        p.pub_name,
        t.title_id,
        t.title,
        SUM(s.qty * ISNULL(t.price, 0)) AS totalVendido
    FROM publishers AS p
    JOIN titles AS t
        ON p.pub_id = t.pub_id
    JOIN sales AS s
        ON t.title_id = s.title_id
    GROUP BY p.pub_id, p.pub_name, t.title_id, t.title
)
SELECT
    pub_name,
    title,
    totalVendido,
    FIRST_VALUE(title) OVER (
        PARTITION BY pub_id
        ORDER BY totalVendido DESC, title
    ) AS libroConMayorIngreso,
    LAST_VALUE(title) OVER (
        PARTITION BY pub_id
        ORDER BY totalVendido DESC, title
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS libroConMenorIngreso,
    CAST(
        100.0 * totalVendido /
        NULLIF(SUM(totalVendido) OVER (PARTITION BY pub_id), 0)
        AS decimal(6, 2)
    ) AS porcentajeEditorial
FROM VentasLibros
ORDER BY pub_name, totalVendido DESC;
GO


/*#############################################################################
  CLASE 05 - CTE, CTE RECURSIVAS, PIVOT Y UNPIVOT
  Bases utilizadas durante la clase: Northwind y pubs
#############################################################################*/


/*-----------------------------------------------------------------------------
  EJEMPLO 05.1 - CTE básico de ventas altas
  Base de datos: Northwind
  Función: dar nombre a un resultado temporal y filtrar con HAVING.
  Apunte: en la diapositiva aparecía Orders.Total como ejemplo conceptual.
          Se adaptó al modelo real de Northwind usando [Order Details].
-----------------------------------------------------------------------------*/
USE Northwind;
GO

;WITH VentasAltas AS (
    SELECT
        o.CustomerID,
        SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)) AS Monto
    FROM Orders AS o
    JOIN [Order Details] AS od
        ON o.OrderID = od.OrderID
    GROUP BY o.CustomerID
    HAVING SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)) > 5000
)
SELECT
    CustomerID,
    Monto
FROM VentasAltas
ORDER BY Monto DESC;
GO


/*-----------------------------------------------------------------------------
  EJEMPLO 05.2 - Clientes frecuentes
  Base de datos: Northwind
  Función: contar pedidos por cliente y conservar quienes tienen más de cinco.
-----------------------------------------------------------------------------*/
USE Northwind;
GO

;WITH ClientesFrecuentes AS (
    SELECT
        c.CustomerID,
        c.CompanyName,
        COUNT(o.OrderID) AS TotalPedidos
    FROM Customers AS c
    JOIN Orders AS o
        ON c.CustomerID = o.CustomerID
    GROUP BY c.CustomerID, c.CompanyName
    HAVING COUNT(o.OrderID) > 5
)
SELECT
    CustomerID,
    CompanyName,
    TotalPedidos
FROM ClientesFrecuentes
ORDER BY TotalPedidos DESC, CompanyName;
GO


/*-----------------------------------------------------------------------------
  EJEMPLO 05.3 - Múltiples CTE: ventas por empleado contra promedio general
  Base de datos: Northwind
  Función: construir un segundo CTE a partir del primero.
  Apunte: CROSS JOIN repite el único promedio general junto a cada empleado.
-----------------------------------------------------------------------------*/
USE Northwind;
GO

;WITH VentasPorEmpleado AS (
    SELECT
        e.EmployeeID,
        e.FirstName + ' ' + e.LastName AS Empleado,
        SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)) AS TotalVendido
    FROM Employees AS e
    JOIN Orders AS o
        ON e.EmployeeID = o.EmployeeID
    JOIN [Order Details] AS od
        ON o.OrderID = od.OrderID
    GROUP BY e.EmployeeID, e.FirstName, e.LastName
),
PromedioGeneral AS (
    SELECT AVG(TotalVendido) AS Promedio
    FROM VentasPorEmpleado
)
SELECT
    v.Empleado,
    v.TotalVendido,
    p.Promedio,
    v.TotalVendido - p.Promedio AS Diferencia
FROM VentasPorEmpleado AS v
CROSS JOIN PromedioGeneral AS p
ORDER BY v.TotalVendido DESC;
GO


/*-----------------------------------------------------------------------------
  RETO 05.4 - Autores con más de un título publicado
  Base de datos: pubs
  Función: usar un CTE, HAVING y el promedio de royaltyper.
-----------------------------------------------------------------------------*/
USE pubs;
GO

;WITH AutoresConVariosTitulos AS (
    SELECT
        a.au_id,
        a.au_lname,
        a.au_fname,
        COUNT(ta.title_id) AS cantidadTitulos,
        AVG(CAST(ta.royaltyper AS decimal(10, 2))) AS regaliaPromedio
    FROM authors AS a
    JOIN titleauthor AS ta
        ON a.au_id = ta.au_id
    GROUP BY a.au_id, a.au_lname, a.au_fname
    HAVING COUNT(ta.title_id) > 1
)
SELECT
    au_id,
    au_lname,
    au_fname,
    cantidadTitulos,
    regaliaPromedio
FROM AutoresConVariosTitulos
ORDER BY cantidadTitulos DESC, au_lname, au_fname;
GO


/*-----------------------------------------------------------------------------
  EJEMPLO 05.5 - Organigrama con una CTE recursiva
  Base de datos: Northwind
  Función: recorrer Employees.ReportsTo desde el jefe hasta los subordinados.
  Apunte: el primer SELECT es el ancla; el segundo es el miembro recursivo.
-----------------------------------------------------------------------------*/
USE Northwind;
GO

;WITH Jerarquia AS (
    -- Miembro ancla: empleado que no reporta a otra persona.
    SELECT
        EmployeeID,
        FirstName + ' ' + LastName AS Nombre,
        ReportsTo,
        0 AS Nivel,
        CAST(FirstName + ' ' + LastName AS varchar(500)) AS Ruta
    FROM Employees
    WHERE ReportsTo IS NULL

    UNION ALL

    -- Miembro recursivo: empleados que reportan al nivel anterior.
    SELECT
        e.EmployeeID,
        e.FirstName + ' ' + e.LastName,
        e.ReportsTo,
        j.Nivel + 1,
        CAST(j.Ruta + ' > ' + e.FirstName + ' ' + e.LastName AS varchar(500))
    FROM Employees AS e
    JOIN Jerarquia AS j
        ON e.ReportsTo = j.EmployeeID
)
SELECT
    REPLICATE('    ', Nivel) + Nombre AS Organigrama,
    Nivel,
    Ruta
FROM Jerarquia
ORDER BY Ruta
OPTION (MAXRECURSION 100);
GO


/*-----------------------------------------------------------------------------
  EJEMPLO 05.6 - Generar una secuencia de meses
  Base de datos: Northwind
  Función: producir todos los meses entre el primer y el último pedido.
  Apunte: se usa el primer día de cada mes para que la secuencia sea estable.
-----------------------------------------------------------------------------*/
USE Northwind;
GO

;WITH Limites AS (
    SELECT
        DATEFROMPARTS(YEAR(MIN(OrderDate)), MONTH(MIN(OrderDate)), 1) AS PrimerMes,
        DATEFROMPARTS(YEAR(MAX(OrderDate)), MONTH(MAX(OrderDate)), 1) AS UltimoMes
    FROM Orders
),
MesesReporte AS (
    SELECT PrimerMes AS Fecha
    FROM Limites

    UNION ALL

    SELECT DATEADD(MONTH, 1, m.Fecha)
    FROM MesesReporte AS m
    CROSS JOIN Limites AS l
    WHERE m.Fecha < l.UltimoMes
)
SELECT FORMAT(Fecha, 'yyyy-MM') AS Periodo
FROM MesesReporte
ORDER BY Fecha
OPTION (MAXRECURSION 200);
GO


/*-----------------------------------------------------------------------------
  RETO 05.7 - Meses sin ventas
  Base de datos: pubs
  Función: generar meses con recursividad y unirlos a las ventas con LEFT JOIN.
  Apunte: si un mes no existe en sales, ISNULL lo muestra con cero copias.
-----------------------------------------------------------------------------*/
USE pubs;
GO

;WITH Limites AS (
    SELECT
        DATEFROMPARTS(YEAR(MIN(ord_date)), MONTH(MIN(ord_date)), 1) AS PrimerMes,
        DATEFROMPARTS(YEAR(MAX(ord_date)), MONTH(MAX(ord_date)), 1) AS UltimoMes
    FROM sales
),
Meses AS (
    SELECT PrimerMes AS Fecha
    FROM Limites

    UNION ALL

    SELECT DATEADD(MONTH, 1, m.Fecha)
    FROM Meses AS m
    CROSS JOIN Limites AS l
    WHERE m.Fecha < l.UltimoMes
),
VentasPorMes AS (
    SELECT
        DATEFROMPARTS(YEAR(ord_date), MONTH(ord_date), 1) AS Fecha,
        SUM(qty) AS copiasVendidas
    FROM sales
    GROUP BY DATEFROMPARTS(YEAR(ord_date), MONTH(ord_date), 1)
)
SELECT
    FORMAT(m.Fecha, 'yyyy-MM') AS Periodo,
    ISNULL(v.copiasVendidas, 0) AS copiasVendidas
FROM Meses AS m
LEFT JOIN VentasPorMes AS v
    ON m.Fecha = v.Fecha
ORDER BY m.Fecha
OPTION (MAXRECURSION 200);
GO


/*-----------------------------------------------------------------------------
  EJEMPLO 05.8 - PIVOT pequeño con los datos de la explicación
  Base de datos: ninguna específica; usa una variable de tabla temporal.
  Función: convertir los años almacenados en filas a columnas.
-----------------------------------------------------------------------------*/
DECLARE @VentasEjemplo TABLE (
    Empleado varchar(50),
    Anio int,
    Total decimal(10, 2)
);

INSERT INTO @VentasEjemplo (Empleado, Anio, Total)
VALUES
    ('Ana', 2023, 500.00),
    ('Ana', 2024, 700.00),
    ('Luis', 2023, 300.00);

SELECT
    Empleado,
    [2023],
    [2024]
FROM @VentasEjemplo
PIVOT (
    SUM(Total)
    FOR Anio IN ([2023], [2024])
) AS Pivote
ORDER BY Empleado;
GO


/*-----------------------------------------------------------------------------
  EJEMPLO 05.9 - Ventas por empleado y año con PIVOT
  Base de datos: Northwind
  Función: crear las columnas 1996, 1997 y 1998 a partir de OrderDate.
  Apunte: la lista IN es estática; si se necesitan otros años hay que agregarlos.
-----------------------------------------------------------------------------*/
USE Northwind;
GO

SELECT
    Empleado,
    [1996],
    [1997],
    [1998]
FROM (
    SELECT
        e.FirstName + ' ' + e.LastName AS Empleado,
        YEAR(o.OrderDate) AS Anio,
        od.UnitPrice * od.Quantity * (1 - od.Discount) AS Monto
    FROM Employees AS e
    JOIN Orders AS o
        ON e.EmployeeID = o.EmployeeID
    JOIN [Order Details] AS od
        ON o.OrderID = od.OrderID
) AS Origen
PIVOT (
    SUM(Monto)
    FOR Anio IN ([1996], [1997], [1998])
) AS Pivote
ORDER BY Empleado;
GO


/*-----------------------------------------------------------------------------
  EJEMPLO 05.10 - UNPIVOT del reporte de ventas por empleado
  Base de datos: Northwind
  Función: regresar las columnas de años al formato Empleado, Anio, Monto.
  Apunte: el PIVOT se conserva en un CTE para usarlo inmediatamente en UNPIVOT.
-----------------------------------------------------------------------------*/
USE Northwind;
GO

;WITH VentasBase AS (
    SELECT
        e.FirstName + ' ' + e.LastName AS Empleado,
        YEAR(o.OrderDate) AS Anio,
        od.UnitPrice * od.Quantity * (1 - od.Discount) AS Monto
    FROM Employees AS e
    JOIN Orders AS o
        ON e.EmployeeID = o.EmployeeID
    JOIN [Order Details] AS od
        ON o.OrderID = od.OrderID
),
VentasPivote AS (
    SELECT
        Empleado,
        [1996],
        [1997],
        [1998]
    FROM VentasBase
    PIVOT (
        SUM(Monto)
        FOR Anio IN ([1996], [1997], [1998])
    ) AS p
)
SELECT
    Empleado,
    Anio,
    Monto
FROM VentasPivote
UNPIVOT (
    Monto FOR Anio IN ([1996], [1997], [1998])
) AS u
ORDER BY Empleado, Anio;
GO


/*-----------------------------------------------------------------------------
  RETO 05.11 - PIVOT y UNPIVOT de ventas por tienda y tipo de libro
  Base de datos: pubs
  Función:
    1. Crear un reporte cruzado de qty por tienda y tipo.
    2. Regresar el reporte a formato largo.
    3. Calcular el total vendido por tienda desde el resultado normalizado.
  Apunte: si la versión de pubs contiene otros tipos, se deben añadir al IN.
-----------------------------------------------------------------------------*/
USE pubs;
GO

IF OBJECT_ID('tempdb..#VentasPorTipo') IS NOT NULL
    DROP TABLE #VentasPorTipo;

;WITH VentasTipo AS (
    SELECT
        s.stor_id,
        LTRIM(RTRIM(t.type)) AS tipo,
        s.qty
    FROM sales AS s
    JOIN titles AS t
        ON s.title_id = t.title_id
)
SELECT
    stor_id,
    [business],
    [mod_cook],
    [popular_comp],
    [psychology],
    [trad_cook],
    [UNDECIDED]
INTO #VentasPorTipo
FROM VentasTipo
PIVOT (
    SUM(qty)
    FOR tipo IN (
        [business],
        [mod_cook],
        [popular_comp],
        [psychology],
        [trad_cook],
        [UNDECIDED]
    )
) AS p;

-- Paso 1: resultado ancho del PIVOT.
SELECT *
FROM #VentasPorTipo
ORDER BY stor_id;

-- Paso 2: regreso a formato largo con UNPIVOT.
SELECT
    stor_id,
    tipo,
    qty
FROM #VentasPorTipo
UNPIVOT (
    qty FOR tipo IN (
        [business],
        [mod_cook],
        [popular_comp],
        [psychology],
        [trad_cook],
        [UNDECIDED]
    )
) AS u
ORDER BY stor_id, tipo;

-- Paso 3: total vendido por tienda desde el resultado normalizado.
SELECT
    stor_id,
    SUM(qty) AS totalCopiasVendidas
FROM #VentasPorTipo
UNPIVOT (
    qty FOR tipo IN (
        [business],
        [mod_cook],
        [popular_comp],
        [psychology],
        [trad_cook],
        [UNDECIDED]
    )
) AS u
GROUP BY stor_id
ORDER BY totalCopiasVendidas DESC;

DROP TABLE #VentasPorTipo;
GO


/*
===============================================================================
 FIN DE LOS APUNTES

 Checklist rápido que me queda de las dos clases:
   [x] Agregaciones y rankings con OVER().
   [x] PARTITION BY para reiniciar cálculos por grupo.
   [x] SUM acumulado, LAG y diferencia entre periodos.
   [x] CTE sencillo y múltiples CTE.
   [x] CTE recursiva para jerarquías y secuencias.
   [x] PIVOT para pasar filas a columnas.
   [x] UNPIVOT para regresar columnas a filas.
===============================================================================
*/
