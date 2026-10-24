INSERT INTO [BibliotecaLab04].[dbo].[Socio] (socio_id,nombre,apellido,carrera)
SELECT n,CONCAT(N'Socio ',n),CONCAT(N'Apellido ',(n-1)%200+1),
       CASE (n-1)/200
            WHEN 0 THEN N'Ingeniería Informática'
            WHEN 1 THEN N'Administración de Empresas'
            WHEN 2 THEN N'Psicología'
            WHEN 3 THEN N'Arquitectura'
            ELSE N'Derecho' END
FROM (
    SELECT 1+a.d+10*b.d+100*c.d+1000*d.d+10000*e.d AS n
    FROM (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) AS a(d)
    CROSS JOIN (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) AS b(d)
    CROSS JOIN (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) AS c(d)
    CROSS JOIN (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) AS d(d)
    CROSS JOIN (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) AS e(d)
) AS numeros
WHERE n<=1000;

INSERT INTO [BibliotecaLab04].[dbo].[Libro] (libro_id,titulo,categoria)
SELECT n,CONCAT(N'Libro de práctica ',n),
       CASE n%4 WHEN 0 THEN N'Ingeniería'
                WHEN 1 THEN N'Ciencias'
                WHEN 2 THEN N'Humanidades'
                ELSE N'Ciencias Sociales' END
FROM (
    SELECT 1+a.d+10*b.d+100*c.d+1000*d.d+10000*e.d AS n
    FROM (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) AS a(d)
    CROSS JOIN (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) AS b(d)
    CROSS JOIN (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) AS c(d)
    CROSS JOIN (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) AS d(d)
    CROSS JOIN (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) AS e(d)
) AS numeros
WHERE n<=500;

INSERT INTO [BibliotecaLab04].[dbo].[Ejemplar] (ejemplar_id,libro_id,codigo_inventario)
SELECT n,(n-1)%500+1,CONCAT('EJ-',RIGHT(CONCAT('000000',n),6))
FROM (
    SELECT 1+a.d+10*b.d+100*c.d+1000*d.d+10000*e.d AS n
    FROM (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) AS a(d)
    CROSS JOIN (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) AS b(d)
    CROSS JOIN (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) AS c(d)
    CROSS JOIN (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) AS d(d)
    CROSS JOIN (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) AS e(d)
) AS numeros
WHERE n<=3500;

INSERT INTO [BibliotecaLab04].[dbo].[Prestamo]
    (prestamo_id,socio_id,ejemplar_id,fecha_prestamo,
     fecha_devolucion_prevista,estado,observaciones)
SELECT n,(n-1)%1000+1,
       ((n-1)*37+(n-1)/1000)%3500+1,
       DATEADD(DAY,(n*37)%2191,CONVERT(DATE,'20210101')),
       DATEADD(DAY,(n*37)%2191+15,CONVERT(DATE,'20210101')),
       CASE ((n-1)/1000+(n-1)%20)%20
            WHEN 0 THEN N'Vencido' WHEN 1 THEN N'Vencido'
            WHEN 2 THEN N'Vencido' WHEN 3 THEN N'Activo'
            WHEN 4 THEN N'Activo' WHEN 5 THEN N'Activo'
            WHEN 6 THEN N'Activo' WHEN 7 THEN N'Activo'
            ELSE N'Devuelto' END,
       CONCAT('Prestamo ',n,'. Registro de biblioteca.')
FROM (
    SELECT 1+a.d+10*b.d+100*c.d+1000*d.d+10000*e.d AS n
    FROM (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) AS a(d)
    CROSS JOIN (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) AS b(d)
    CROSS JOIN (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) AS c(d)
    CROSS JOIN (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) AS d(d)
    CROSS JOIN (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) AS e(d)
) AS numeros
WHERE n<=45000;
