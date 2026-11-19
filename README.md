# Smart Desk SQL Portfolio

Portfolio project based on the academic Smart Desk case. The original submission was created in Snowflake; this repository preserves that academic SQL and provides a reproducible PostgreSQL adaptation for Data Analyst and Business Analyst applications.

## Business problem

Understand which categories, countries, industries and regions contribute to commercial performance, and evaluate regional growth from 2020 to 2021 together with the mix between product and associated services.

## Project structure

- `sql/snowflake/original_analysis.sql`: faithful copy of the original academic submission.
- `sql/postgres/00_schema.sql`: non-destructive table creation.
- `sql/postgres/01_validation.sql`: schema, quality, relationships, grain and join-risk checks.
- `sql/postgres/02_analysis.sql`: academic questions and the regional case adapted to PostgreSQL.
- `sql/postgres/03_followup_checks.sql`: follow-up checks for detected data-quality issues and product/service composition.
- `data/README.md`: data provenance, loading instructions and redistribution notes.
- `docs/data_dictionary.md`: operational definitions of the tables and fields.
- `docs/review_notes.md`: decisions, Snowflake/PostgreSQL differences and review status.
- `docs/findings.md`: verified observations, interpretations, recommendations and limitations.

## Reproduce the analysis in PostgreSQL

1. Create a new database, for example `smart_desk_portfolio`, from DBeaver or `createdb`. Use the existing `smart_desk` database only if you intend to work on it.
2. Connect to the database in DBeaver and run `sql/postgres/00_schema.sql`.
3. Import `data/raw/Accounts.csv`, `Sales.csv` and `Forecasts.csv` into their matching tables with headers enabled, comma separator, UTF-8 encoding and dot decimal separator.
4. Run `sql/postgres/01_validation.sql`. Review row counts, nulls, account matching, duplicate candidates, numeric ranges and total consistency.
5. Run `sql/postgres/02_analysis.sql` after reviewing the validation results.
6. Run `sql/postgres/03_followup_checks.sql` to inspect the known forecast duplicates, the one total mismatch, fractional units and regional product/service composition.

With `psql`, files can be loaded from the repository root using `\copy`, for example:

```text
\copy public.accounts FROM 'data/raw/Accounts.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
```

`\copy` is a `psql` command, not standard SQL for direct execution in DBeaver. In DBeaver, use the CSV import wizard. Do not store database passwords in the repository; enter them only in the local credential dialog.

## Questions analysed

The original delivery covers four questions:

1. Sales, units and profit by category for Adabs Entertainment in 2020.
2. Average performance by country in APAC and EMEA.
3. Profit by industry for accounts with a Commit forecast above 500,000.
4. Actual 2021 profit versus 2022 forecast by category, including opportunity age.

The practical case is regional growth from 2020 to 2021 and the product versus associated-services mix.

## Verified results

The CSV inspection and the user's DBeaver execution confirm 188 `Accounts` rows, 159 `Sales` rows and 135 `Forecasts` rows. No duplicate account identifiers or orphan fact rows were found. The checks found one one-unit mismatch in `total`, seven repeated `account + category + year` forecast candidates, and fractional `units_sold` values in 144 rows. The extended forecast grain including `prediction_category` and `opportunity_age` returned no duplicates. These results are documented in `docs/findings.md`.

The regional case is reproduced: NAM sales increase from 24,403,809.00 to 44,179,349.00 and EMEA sales increase from 35,375,010.00 to 43,827,761.00. APAC decreases from 13,362,428.00 to 8,584,998.00. Product grows by 72.79% in NAM and 20.98% in EMEA, while associated services grow by 102.75% and 30.83%. APAC product decreases by 49.89% and associated services by 0.75%. LATAM has no comparable 2020 baseline.

## Limitations and publication

Academic CSVs and course materials are excluded from Git by default. No license is assigned to third-party materials. Before publishing, confirm redistribution rights or create a separate synthetic sample, clearly labelled as synthetic, without mixing its results with the academic data. No push has been made.

## GitHub upload checklist

- Review the files shown by `git status`.
- Confirm that `data/raw/`, PDFs, ZIP files, credentials and temporary files are ignored.
- Do not commit passwords, local connection settings or third-party course materials.
- Commit the project files locally, review the commit, and only then create the GitHub repository and push.
