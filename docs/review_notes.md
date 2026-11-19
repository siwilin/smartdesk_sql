# Review notes

## Reviewed material

- `sql/snowflake/original_analysis.sql`: faithful copy of the academic SQL submission.
- The three CSV files: headers, separator, initial rows and numeric format inspected.
- The SQL copy was verified byte-for-byte with SHA-256; the copy and source have the same hash. The CSVs contain 188, 159 and 135 data rows respectively (`Accounts`, `Sales`, `Forecasts`).
- The user executed the PostgreSQL scripts in DBeaver. The verified findings are summarised in `docs/findings.md`.
- The assignment and report PDFs are available in the original material, but their text could not be fully extracted in this environment. Their contents were not used to claim reproduced results.

## Four academic questions

1. Sales, units and profit by category for Adabs Entertainment in 2020.
2. Average performance by country in APAC and EMEA.
3. Profit by industry for accounts with Commit opportunities and forecast above 500,000.
4. Actual 2021 profit versus 2022 forecast by category and opportunity age.

The practical case in the SQL submission is option 1: regional growth from 2020 to 2021, including the product versus maintenance, support and parts composition.

## Corrections and decisions

- Removed `USE WAREHOUSE`, `USE DATABASE` and `USE SCHEMA`: these are Snowflake-specific and are not needed when connected to PostgreSQL.
- Replaced Snowflake-style aliases and quoting with lower-case PostgreSQL names.
- Used `EXISTS` in question 3 so multiple forecast rows for one account cannot multiply sales rows.
- Kept `NULL` when one side of the 2021/2022 comparison is absent; zero is a real value and is different from missing data.
- Used `100.0` and `NULLIF` to avoid integer division and division by zero.
- Used `COALESCE` for the associated-service components. The project does not call them recurring revenue because the dataset does not prove contractual recurrence.
- Added no keys or constraints until the imported data has been checked.

## Forecast grain decision

The observed candidate `account + category + year` is repeated in seven cases. These rows are not deleted or arbitrarily deduplicated. The extended check using `prediction_category` and `opportunity_age` returned no duplicate rows, so those fields distinguish the observed forecast entries in this import. For analysis, forecasts are aggregated at the level required by the question; the result should be described as the sum of forecast entries, not as a unique forecast record per account-category-year.

## Verified PostgreSQL issues

- One `sales` row differs by 1 between `total` and the sum of its components.
- Seven forecast rows repeat the candidate `account + category + year` combination; the extended candidate including `prediction_category` and `opportunity_age` has no duplicates.
- Accounts are unique and fact tables contain no orphan accounts.
- `prediction_category` contains 19 `Commit`, 89 `Pipeline` and 27 `Upside` rows; `Committed` does not appear.
- `units_sold` is fractional in 144 rows, so `numeric` is required.
- The total mismatch is `Reidwo Consulting / Break room / 2020 Q4`, with a calculated difference of -1.00.
