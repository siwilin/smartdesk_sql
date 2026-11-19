# Data

The CSV files come from the academic Smart Desk course material. They are kept locally under `data/raw/` only to support reproducible loading; that folder is excluded from Git because redistribution rights have not been confirmed. The assignment statement, logo and original report are third-party materials and are not included in the public project by default.

The inspected files are `Accounts.csv`, `Sales.csv` and `Forecasts.csv`. They contain headers, comma separators, apparent UTF-8 encoding and dot decimal notation. Confirm the imported row counts and database types with `sql/postgres/01_validation.sql`.

For a public demonstration, use a separate synthetic sample clearly labelled as synthetic. Do not mix synthetic results with the original academic results.
