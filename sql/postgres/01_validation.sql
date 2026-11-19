-- Smart Desk - schema, quality and grain validation
-- Run after 00_schema.sql while connected to smart_desk.

-- 1. Actual schema and imported data types.
SELECT table_name, column_name, data_type, numeric_precision, numeric_scale, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN ('accounts', 'sales', 'forecasts')
ORDER BY table_name, ordinal_position;

-- 2. Row count by table.
SELECT 'accounts' AS table_name, COUNT(*) AS row_count FROM public.accounts
UNION ALL SELECT 'sales', COUNT(*) FROM public.sales
UNION ALL SELECT 'forecasts', COUNT(*) FROM public.forecasts;

-- 3. Nulls in relevant fields.
SELECT 'accounts.account' AS field, COUNT(*) FILTER (WHERE account IS NULL OR btrim(account) = '') AS null_or_blank FROM public.accounts
UNION ALL SELECT 'accounts.region', COUNT(*) FILTER (WHERE region IS NULL OR btrim(region) = '') FROM public.accounts
UNION ALL SELECT 'sales.account', COUNT(*) FILTER (WHERE account IS NULL OR btrim(account) = '') FROM public.sales
UNION ALL SELECT 'sales.year', COUNT(*) FILTER (WHERE year IS NULL) FROM public.sales
UNION ALL SELECT 'sales.total', COUNT(*) FILTER (WHERE total IS NULL) FROM public.sales
UNION ALL SELECT 'sales.profit', COUNT(*) FILTER (WHERE profit IS NULL) FROM public.sales
UNION ALL SELECT 'forecasts.account', COUNT(*) FILTER (WHERE account IS NULL OR btrim(account) = '') FROM public.forecasts
UNION ALL SELECT 'forecasts.forecast', COUNT(*) FILTER (WHERE forecast IS NULL) FROM public.forecasts
UNION ALL SELECT 'forecasts.year', COUNT(*) FILTER (WHERE year IS NULL) FROM public.forecasts;

-- 4. Duplicate account identifiers in the accounts dimension.
SELECT account, COUNT(*) AS row_count
FROM public.accounts
GROUP BY account
HAVING COUNT(*) > 1
ORDER BY row_count DESC, account;

-- 5. Fact rows without a matching account.
SELECT 'sales_without_account' AS check_name, COUNT(*) AS row_count
FROM public.sales s
LEFT JOIN public.accounts a ON a.account = s.account
WHERE a.account IS NULL
UNION ALL
SELECT 'forecasts_without_account', COUNT(*)
FROM public.forecasts f
LEFT JOIN public.accounts a ON a.account = f.account
WHERE a.account IS NULL;

-- 6. Years, categories and prediction_category values.
SELECT 'sales_year' AS dimension, year::text AS value, COUNT(*) AS row_count FROM public.sales GROUP BY year
UNION ALL
SELECT 'forecast_year', year::text, COUNT(*) FROM public.forecasts GROUP BY year
ORDER BY dimension, value;

SELECT 'sales_category' AS dimension, category AS value, COUNT(*) AS row_count FROM public.sales GROUP BY category
UNION ALL
SELECT 'forecast_category', category, COUNT(*) FROM public.forecasts GROUP BY category
ORDER BY dimension, value;

SELECT prediction_category, COUNT(*) AS row_count
FROM public.forecasts
GROUP BY prediction_category
ORDER BY prediction_category;

-- 7. Fractional units.
SELECT COUNT(*) AS fractional_units_rows,
       MIN(units_sold) AS min_units,
       MAX(units_sold) AS max_units
FROM public.sales
WHERE units_sold IS NOT NULL AND units_sold <> trunc(units_sold);

-- 8. Total consistency = product + maintenance + parts + support.
-- Null components are treated as absent for this check and are not modified.
SELECT COUNT(*) AS rows_checked,
       COUNT(*) FILTER (
         WHERE total IS NOT NULL
           AND total <> COALESCE(product, 0) + COALESCE(maintenance, 0)
                            + COALESCE(parts, 0) + COALESCE(support, 0)
       ) AS inconsistent_total_rows,
       MAX(ABS(total - (COALESCE(product, 0) + COALESCE(maintenance, 0)
                        + COALESCE(parts, 0) + COALESCE(support, 0))))
         FILTER (WHERE total IS NOT NULL) AS max_absolute_difference
FROM public.sales;

-- 9. Negative and extreme values: review signals, not automatic errors.
SELECT 'sales.total' AS metric, COUNT(*) FILTER (WHERE total < 0) AS negative_rows,
       MIN(total) AS min_value, MAX(total) AS max_value FROM public.sales
UNION ALL SELECT 'sales.profit', COUNT(*) FILTER (WHERE profit < 0), MIN(profit), MAX(profit) FROM public.sales
UNION ALL SELECT 'sales.units_sold', COUNT(*) FILTER (WHERE units_sold < 0), MIN(units_sold), MAX(units_sold) FROM public.sales
UNION ALL SELECT 'forecasts.forecast', COUNT(*) FILTER (WHERE forecast < 0), MIN(forecast), MAX(forecast) FROM public.forecasts;

SELECT 'sales.total' AS metric,
       percentile_cont(0.01) WITHIN GROUP (ORDER BY total) AS p01,
       percentile_cont(0.50) WITHIN GROUP (ORDER BY total) AS median,
       percentile_cont(0.99) WITHIN GROUP (ORDER BY total) AS p99
FROM public.sales
UNION ALL
SELECT 'sales.profit', percentile_cont(0.01) WITHIN GROUP (ORDER BY profit),
       percentile_cont(0.50) WITHIN GROUP (ORDER BY profit),
       percentile_cont(0.99) WITHIN GROUP (ORDER BY profit)
FROM public.sales;

-- 10. Observed grain and possible duplicate business keys.
SELECT account, category, quarter, COUNT(*) AS row_count
FROM public.sales
GROUP BY account, category, quarter
HAVING COUNT(*) > 1
ORDER BY row_count DESC;

SELECT account, category, year, COUNT(*) AS row_count
FROM public.forecasts
GROUP BY account, category, year
HAVING COUNT(*) > 1
ORDER BY row_count DESC;

-- Check whether prediction category and opportunity age explain repeated
-- account-category-year forecast rows.
SELECT account, category, year, prediction_category, opportunity_age,
       COUNT(*) AS row_count
FROM public.forecasts
GROUP BY account, category, year, prediction_category, opportunity_age
HAVING COUNT(*) > 1
ORDER BY row_count DESC;

-- The candidate sales grain is account-category-quarter. The candidate forecast
-- grain is not unique in this import. A direct join can multiply rows, so
-- aggregate each fact table before joining them.
