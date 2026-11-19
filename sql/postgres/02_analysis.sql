-- Smart Desk - PostgreSQL analysis
-- Run after reviewing 01_validation.sql.
-- Metrics are aggregated before facts are compared.

-- Question 1. Sales and profit by category for Adabs Entertainment in 2020.
SELECT category,
       SUM(maintenance) AS maintenance,
       SUM(product) AS product,
       SUM(parts) AS parts,
       SUM(support) AS support,
       SUM(total) AS total_sales,
       SUM(units_sold) AS units_sold,
       SUM(profit) AS total_profit,
       COUNT(*) AS sales_rows
FROM public.sales
WHERE account = 'Adabs Entertainment' AND year = 2020
GROUP BY category
ORDER BY total_sales DESC;

-- Question 2. Average performance by country in APAC and EMEA.
-- The averaging unit is one sales row (usually account-category-quarter),
-- not an account or a country weighted by population or customer count.
SELECT a.region, a.country,
       ROUND(AVG(s.total), 2) AS average_sales_row_total,
       ROUND(AVG(s.units_sold), 2) AS average_sales_row_units,
       ROUND(AVG(s.profit), 2) AS average_sales_row_profit,
       COUNT(*) AS sales_rows
FROM public.sales s
JOIN public.accounts a ON a.account = s.account
WHERE a.region IN ('APAC', 'EMEA')
GROUP BY a.region, a.country
ORDER BY a.region, average_sales_row_total DESC;

-- Question 3. Profit by industry for accounts with at least one
-- Commit forecast above 500000. EXISTS prevents sales multiplication.
SELECT a.industry,
       SUM(s.profit) AS total_profit,
       CASE WHEN SUM(s.profit) > 1000000 THEN 'High' ELSE 'Normal' END AS benefit_category,
       COUNT(*) AS sales_rows
FROM public.sales s
JOIN public.accounts a ON a.account = s.account
WHERE EXISTS (
    SELECT 1 FROM public.forecasts f
    WHERE f.account = s.account
      AND f.prediction_category IN ('Commit', 'Committed')
      AND f.forecast > 500000
)
GROUP BY a.industry
ORDER BY total_profit DESC;

-- Question 4. Actual 2021 profit versus 2022 forecast by category.
-- NULL means that side has no data; missing data is not converted to zero.
WITH sales_2021 AS (
    SELECT category, SUM(profit) AS actual_profit_2021, COUNT(*) AS sales_rows_2021
    FROM public.sales WHERE year = 2021 GROUP BY category
), forecast_2022 AS (
    SELECT category, SUM(forecast) AS forecast_2022,
           MIN(opportunity_age) AS youngest_opportunity_age,
           MAX(opportunity_age) AS oldest_opportunity_age,
           COUNT(*) AS forecast_rows_2022
    FROM public.forecasts WHERE year = 2022 GROUP BY category
)
SELECT COALESCE(s.category, f.category) AS category,
       s.actual_profit_2021, f.forecast_2022,
       f.youngest_opportunity_age, f.oldest_opportunity_age,
       s.sales_rows_2021, f.forecast_rows_2022
FROM sales_2021 s
FULL OUTER JOIN forecast_2022 f ON f.category = s.category
ORDER BY s.actual_profit_2021 DESC NULLS LAST, f.forecast_2022 DESC NULLS LAST;

-- Practical case: regional growth from 2020 to 2021.
WITH regional AS (
    SELECT a.region, s.year,
           SUM(s.total) AS sales,
           SUM(s.profit) AS profit,
           SUM(s.units_sold) AS units_sold,
           SUM(s.product) AS product,
           SUM(COALESCE(s.maintenance, 0) + COALESCE(s.support, 0)
               + COALESCE(s.parts, 0)) AS services_associated
    FROM public.sales s
    JOIN public.accounts a ON a.account = s.account
    WHERE s.year IN (2020, 2021)
    GROUP BY a.region, s.year
), pivoted AS (
    SELECT region,
           MAX(sales) FILTER (WHERE year = 2020) AS sales_2020,
           MAX(sales) FILTER (WHERE year = 2021) AS sales_2021,
           MAX(profit) FILTER (WHERE year = 2020) AS profit_2020,
           MAX(profit) FILTER (WHERE year = 2021) AS profit_2021,
           MAX(product) FILTER (WHERE year = 2020) AS product_2020,
           MAX(product) FILTER (WHERE year = 2021) AS product_2021,
           MAX(services_associated) FILTER (WHERE year = 2020) AS services_2020,
           MAX(services_associated) FILTER (WHERE year = 2021) AS services_2021
    FROM regional GROUP BY region
)
SELECT region, sales_2020, sales_2021,
       sales_2021 - sales_2020 AS sales_delta,
       ROUND(100.0 * (sales_2021 - sales_2020) / NULLIF(sales_2020, 0), 2) AS sales_growth_pct,
       profit_2020, profit_2021,
       profit_2021 - profit_2020 AS profit_delta,
       ROUND(100.0 * (profit_2021 - profit_2020) / NULLIF(profit_2020, 0), 2) AS profit_growth_pct,
       product_2020, product_2021, product_2021 - product_2020 AS product_delta,
       ROUND(100.0 * (product_2021 - product_2020) / NULLIF(product_2020, 0), 2) AS product_growth_pct,
       services_2020, services_2021, services_2021 - services_2020 AS services_delta,
       ROUND(100.0 * (services_2021 - services_2020) / NULLIF(services_2020, 0), 2) AS services_growth_pct,
       CASE WHEN sales_2020 IS NULL OR sales_2021 IS NULL THEN 'incomplete_year_coverage' ELSE 'comparable' END AS coverage_status
FROM pivoted
ORDER BY profit_delta DESC NULLS LAST;

-- "services_associated" groups maintenance/support/parts for mix analysis.
-- It is not labelled recurring revenue because the model does not prove
-- contractual recurrence.
