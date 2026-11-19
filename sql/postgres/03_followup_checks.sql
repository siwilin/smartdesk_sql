-- Smart Desk - follow-up checks after the first execution
-- Run in DBeaver connected to the smart_desk database.

-- 1. Actual prediction_category values.
SELECT prediction_category, COUNT(*) AS row_count
FROM public.forecasts
GROUP BY prediction_category
ORDER BY prediction_category;

-- 2. Fractional units sold.
SELECT COUNT(*) AS fractional_units_rows,
       MIN(units_sold) AS min_units,
       MAX(units_sold) AS max_units
FROM public.sales
WHERE units_sold IS NOT NULL
  AND units_sold <> trunc(units_sold);

-- 3. Locate the row whose component sum differs from total.
SELECT *,
       total - (COALESCE(product, 0) + COALESCE(maintenance, 0)
                + COALESCE(parts, 0) + COALESCE(support, 0)) AS difference
FROM public.sales
WHERE total <> (COALESCE(product, 0) + COALESCE(maintenance, 0)
                + COALESCE(parts, 0) + COALESCE(support, 0));

-- 4. Regional growth composition: product versus associated services.
-- Associated services = maintenance + support + parts.
-- This does not imply contractual recurrence.
WITH regional AS (
    SELECT a.region, s.year,
           SUM(s.product) AS product,
           SUM(COALESCE(s.maintenance, 0) + COALESCE(s.support, 0)
               + COALESCE(s.parts, 0)) AS services_associated,
           SUM(s.total) AS sales
    FROM public.sales s
    JOIN public.accounts a ON a.account = s.account
    WHERE s.year IN (2020, 2021)
    GROUP BY a.region, s.year
), pivoted AS (
    SELECT region,
           MAX(product) FILTER (WHERE year = 2020) AS product_2020,
           MAX(product) FILTER (WHERE year = 2021) AS product_2021,
           MAX(services_associated) FILTER (WHERE year = 2020) AS services_2020,
           MAX(services_associated) FILTER (WHERE year = 2021) AS services_2021,
           MAX(sales) FILTER (WHERE year = 2020) AS sales_2020,
           MAX(sales) FILTER (WHERE year = 2021) AS sales_2021
    FROM regional
    GROUP BY region
)
SELECT region,
       product_2020, product_2021,
       product_2021 - product_2020 AS product_delta,
       ROUND(100.0 * (product_2021 - product_2020) / NULLIF(product_2020, 0), 2) AS product_growth_pct,
       services_2020, services_2021,
       services_2021 - services_2020 AS services_delta,
       ROUND(100.0 * (services_2021 - services_2020) / NULLIF(services_2020, 0), 2) AS services_growth_pct,
       sales_2020, sales_2021,
       CASE WHEN sales_2020 IS NULL OR sales_2021 IS NULL
            THEN 'incomplete_year_coverage' ELSE 'comparable' END AS coverage_status
FROM pivoted
ORDER BY sales_2021 - sales_2020 DESC NULLS LAST;
