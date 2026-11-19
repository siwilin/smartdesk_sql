--DEFINIMOS EL CONTEXTO
USE WAREHOUSE RABBIT_WH;
USE DATABASE UCM;
USE SCHEMA SMART_DESK;

------------------------------------------------------------
-- 1) Ventas y beneficio por categoría (Adabs Entertainment, 2020)
------------------------------------------------------------
-- Objetivo: Desglosar ventas, unidades y beneficio por categoría para Adabs Entertainment en 2020.
-- Espero ver qué categorías aportan más ingresos/beneficio y si el mix de ingresos (producto vs servicios) cambia por categoría.

SELECT 
CATEGORY            AS "Categoría",
SUM(MAINTENANCE)    AS "Mantenimiento",
SUM(PRODUCT)        AS "Producto",
SUM(PARTS)          AS "Partes",
SUM(SUPPORT)        AS "Soporte",
SUM(TOTAL)          AS "Total Ventas",
SUM(UNITS_SOLD)     AS "Unidades Vendidas",
SUM(PROFIT)         AS "Beneficio Total"
FROM SALES
WHERE ACCOUNT = 'Adabs Entertainment'
AND YEAR = 2020
GROUP BY CATEGORY
ORDER BY "Total Ventas" DESC;

------------------------------------------------------------
-- 2) Rendimiento promedio por país (APAC y EMEA)
------------------------------------------------------------
-- Objetivo: Comparar el rendimiento promedio (ingreso, unidades y beneficio) por país en APAC y EMEA.
-- Espero identificar países benchmark (top) y países con menor rendimiento para priorizar esfuerzos comerciales.
-- Redondeo para mejorar legibilidad del output (moneda a 2 decimales; unidades a entero).

SELECT
a.REGION                     AS "Región",
a.COUNTRY                    AS "País",
ROUND(AVG(s.TOTAL),2)        AS "Ingreso Promedio",
ROUND(AVG(s.UNITS_SOLD),0)   AS "Unidades Vendidas Promedio",
ROUND(AVG(s.PROFIT),2)       AS "Beneficio Promedio"
FROM SALES s
JOIN ACCOUNTS a
ON s.ACCOUNT=a.ACCOUNT
WHERE a.REGION IN ('APAC','EMEA')
GROUP BY a.REGION, a.COUNTRY
ORDER BY a.REGION, "Ingreso Promedio" DESC;

------------------------------------------------------------
-- 3) Beneficio total por industria (cuentas en etapa Commit y Forecast > 500.000)
------------------------------------------------------------
-- Objetivo: Medir el beneficio total por industria en cuentas con oportunidades 'Commit' y Forecast > 500k.
-- Espero ver industrias prioritarias (beneficio > 1M => 'Alto') para asignación de recursos comerciales.

SELECT
a.INDUSTRY,
SUM(s.PROFIT)       AS TOTAL_PROFIT,
CASE WHEN SUM(s.PROFIT) > 1000000 THEN 'Alto'
                                    ELSE 'Normal'
                    END AS BENEFIT_CATEGORY
FROM SALES s
JOIN ACCOUNTS a
ON s.ACCOUNT = a.ACCOUNT
WHERE s.ACCOUNT IN (SELECT DISTINCT f.ACCOUNT
                    FROM FORECASTS f
                    WHERE f.PREDICTION_CATEGORY = 'Commit'
                    AND f.FORECAST > 500000)
GROUP BY a.INDUSTRY
ORDER BY TOTAL_PROFIT DESC;

------------------------------------------------------------
-- 4) Beneficio real 2021 vs Forecast 2022 + antigüedad de oportunidades por categoría
------------------------------------------------------------
-- Objetivo: Comparar beneficio real 2021 vs forecast 2022 por categoría e identificar oportunidad más reciente/antigua.
-- Espero detectar categorías con mayor proyección 2022 y señales de ciclo de venta lento (edades máximas altas).
-- Se utiliza FULL OUTER JOIN para no perder categorías presentes únicamente en 2021 (beneficio real) o en 2022 (forecast).
-- COALESCE permite tratar los valores faltantes como 0 y mantener comparabilidad.

WITH VENTAS_2021 AS (SELECT 
                    CATEGORY,
                    YEAR,
                    SUM(PROFIT) AS PROFIT_2021
                    FROM SALES
                    WHERE YEAR = 2021
                    GROUP BY CATEGORY, YEAR),
PROYECCION_2022 AS (SELECT 
                    CATEGORY,
                    YEAR,
                    SUM(FORECAST)           AS FORECAST_2022,
                    MIN(OPPORTUNITY_AGE)    AS OPORTUNIDAD_MAS_RECIENTE,
                    MAX(OPPORTUNITY_AGE)    AS OPORTUNIDAD_MAS_ANTIGUA
                    FROM FORECASTS
                    WHERE YEAR = 2022
                    GROUP BY CATEGORY, YEAR)
SELECT
COALESCE(s.CATEGORY, f.CATEGORY)    AS CATEGORIA,
COALESCE(s.PROFIT_2021, 0)          AS BENEFICIO_TOTAL_2021,
COALESCE(f.FORECAST_2022, 0)        AS PRONOSTICO_TOTAL_2022,
f.OPORTUNIDAD_MAS_RECIENTE,
f.OPORTUNIDAD_MAS_ANTIGUA
FROM VENTAS_2021 s
FULL OUTER JOIN PROYECCION_2022 f
    ON s.CATEGORY = f.CATEGORY
    AND s.YEAR = 2021
    AND f.YEAR = 2022
ORDER BY BENEFICIO_TOTAL_2021 DESC;

-------------------------------------------------------------
-- CASO PRÁCTICO (Opción 1): Crecimiento por región (2020 vs 2021)
------------------------------------------------------------

-- Validación rápida: ¿hay datos en 2020 y 2021?
-- Objetivo: Validar que existen registros en 2020 y 2021 para hacer comparación interanual.
-- Espero ver conteos en ambos años; si difieren mucho, interpretar crecimiento con cautela.

SELECT
YEAR,
COUNT(*) AS N_FILAS
FROM SALES
WHERE YEAR IN (2020, 2021)
GROUP BY YEAR
ORDER BY YEAR;

-- Distribución de ventas y beneficio por región y año
-- Objetivo: Analizar la evolución del volumen de negocio por región antes de calcular crecimientos, identificando patrones generales y posibles anomalías.
-- Espero observar regiones con aumento, estabilidad o contracción entre 2020 y 2021, lo que permitirá contextualizar los resultados de crecimiento posteriores.

SELECT
a.REGION,
s.YEAR,
SUM(s.TOTAL)        AS TOTAL_VENTAS,
SUM(s.PROFIT)       AS BENEFICIO_TOTAL,
SUM(s.UNITS_SOLD)   AS UNIDADES_TOTALES
FROM SALES s
JOIN ACCOUNTS a
ON s.ACCOUNT = a.ACCOUNT
WHERE s.YEAR IN (2020, 2021)
GROUP BY a.REGION, s.YEAR
ORDER BY a.REGION, s.YEAR;

-- Crecimiento absoluto y porcentual por región (ventas y beneficio)
-- Objetivo: Calcular el crecimiento interanual por región tanto en términos absolutos como relativos para responder directamente a la pregunta de negocio.
-- Espero identificar la región con mayor crecimiento en ventas y beneficio, así como evaluar si dicho crecimiento es equilibrado o desalineado.
-- Se agregan las métricas con SUM (y no AVG) porque la pregunta de negocio se centra en el crecimiento total por región y no en la eficiencia media.
-- Se utiliza una estructura tipo pivot con CASE WHEN para alinear 2020 y 2021 en columnas y facilitar el cálculo directo de variaciones absolutas y porcentuales.


WITH TOTALES_REGIONALES AS (SELECT
                        a.REGION,
                        s.YEAR,
                        SUM(s.TOTAL)  AS TOTAL_VENTAS,
                        SUM(s.PROFIT) AS BENEFICIO_TOTAL
                        FROM SALES s
                        JOIN ACCOUNTS a
                        ON s.ACCOUNT = a.ACCOUNT
                        WHERE s.YEAR IN (2020, 2021)
                        GROUP BY a.REGION, s.YEAR),
COMPARATIVA_REGION_2020_2021 AS (SELECT
                                REGION,
                                MAX(CASE WHEN YEAR = 2020 THEN TOTAL_VENTAS END)    AS VENTAS_2020,
                                MAX(CASE WHEN YEAR = 2021 THEN TOTAL_VENTAS END)    AS VENTAS_2021,
                                MAX(CASE WHEN YEAR = 2020 THEN BENEFICIO_TOTAL END) AS BENEFICIO_2020,
                                MAX(CASE WHEN YEAR = 2021 THEN BENEFICIO_TOTAL END) AS BENEFICIO_2021
                                FROM TOTALES_REGIONALES
                                GROUP BY REGION)
SELECT
REGION,
VENTAS_2020,
VENTAS_2021,
(VENTAS_2021 - VENTAS_2020)                                                     AS CRECIMIENTO_VENTAS,
ROUND((VENTAS_2021 - VENTAS_2020) / NULLIF(VENTAS_2020, 0) * 100, 2)            AS CRECIMIENTO_VENTAS_PCT,
BENEFICIO_2020,
BENEFICIO_2021,
(BENEFICIO_2021 - BENEFICIO_2020)                                               AS CRECIMIENTO_BENEFICIO,
ROUND((BENEFICIO_2021 - BENEFICIO_2020) / NULLIF(BENEFICIO_2020, 0) * 100, 2)   AS CRECIMIENTO_BENEFICIO_PCT
FROM COMPARATIVA_REGION_2020_2021
ORDER BY CRECIMIENTO_BENEFICIO DESC;

-- Análisis de la composición del crecimiento: producto vs servicios
-- Objetivo: Determinar si el crecimiento regional proviene principalmente de la venta de producto o de los servicios asociados (mantenimiento, soporte y partes).
-- Espero identificar regiones donde el crecimiento esté impulsado por ingresos recurrentes, lo que indicaría un modelo más sostenible, frente a regiones dependientes del producto.
-- Se agrupan mantenimiento, soporte y partes bajo la métrica "SERVICIOS" para analizar el peso del ingreso recurrente frente a la venta de producto, alineando el análisis con una perspectiva estratégica y de sostenibilidad.
-- LATAM no dispone de base 2020, por lo que los porcentajes aparecerán como NULL. NULLIF evita divisiones por cero en regiones sin base en 2020, devolviendo NULL en los porcentajes para una interpretación correcta.

WITH REGIONAL AS (SELECT
                a.REGION,
                s.YEAR,
                SUM(s.PRODUCT)                              AS PRODUCTO,
                SUM(s.MAINTENANCE + s.SUPPORT + s.PARTS)    AS SERVICIOS,
                SUM(s.TOTAL)                                AS TOTAL_VENTAS
                FROM SALES s
                JOIN ACCOUNTS a
                ON s.ACCOUNT = a.ACCOUNT
                WHERE s.YEAR IN (2020, 2021)
                GROUP BY a.REGION, s.YEAR),
PRODUCTO_SERVICIOS_REGION_2020_2021 AS (SELECT
                                        REGION,
                                        MAX(CASE WHEN YEAR = 2020 THEN PRODUCTO END)        AS PRODUCTO_2020,
                                        MAX(CASE WHEN YEAR = 2021 THEN PRODUCTO END)        AS PRODUCTO_2021,
                                        MAX(CASE WHEN YEAR = 2020 THEN SERVICIOS END)       AS SERVICIOS_2020,
                                        MAX(CASE WHEN YEAR = 2021 THEN SERVICIOS END)       AS SERVICIOS_2021,
                                        MAX(CASE WHEN YEAR = 2020 THEN TOTAL_VENTAS END)    AS TOTAL_2020,
                                        MAX(CASE WHEN YEAR = 2021 THEN TOTAL_VENTAS END)    AS TOTAL_2021
                                        FROM REGIONAL
                                        GROUP BY REGION)
SELECT
REGION,
PRODUCTO_2020,
PRODUCTO_2021,
(PRODUCTO_2021 - PRODUCTO_2020)                                                 AS DELTA_PRODUCTO,
ROUND((PRODUCTO_2021 - PRODUCTO_2020) / NULLIF(PRODUCTO_2020, 0) * 100, 2)      AS CREC_PRODUCTO_PCT,
SERVICIOS_2020,
SERVICIOS_2021,
(SERVICIOS_2021 - SERVICIOS_2020)                                               AS DELTA_SERVICIOS,
ROUND((SERVICIOS_2021 - SERVICIOS_2020) / NULLIF(SERVICIOS_2020, 0) * 100, 2)   AS CREC_SERVICIOS_PCT,
TOTAL_2020,
TOTAL_2021,
(TOTAL_2021 - TOTAL_2020)                                                       AS DELTA_TOTAL,
ROUND((TOTAL_2021 - TOTAL_2020) / NULLIF(TOTAL_2020, 0) * 100, 2)               AS CREC_TOTAL_PCT
FROM PRODUCTO_SERVICIOS_REGION_2020_2021
ORDER BY CREC_TOTAL_PCT DESC;

-- Nota: El análisis se basa en datos agregados por región y año.
-- No se controla por número de clientes ni ticket medio, por lo que los resultados reflejan crecimiento total y no eficiencia comercial.



