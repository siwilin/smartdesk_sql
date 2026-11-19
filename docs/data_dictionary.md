# Data dictionary

## Accounts

One row is intended to represent a commercial account. `account` identifies the account; `account_executive`, `account_level`, `contact_email`, `country`, `industry` and `region` describe the commercial dimension. Account uniqueness must be checked before using this table as a dimension.

## Sales

One row contains sales for an account, category and quarter (`quarter`, `quarter_of_year`, `year`). `product`, `maintenance`, `parts` and `support` are monetary components; `total` is the imported total; `profit` is profit; `units_sold` can be fractional and is therefore stored as `numeric`.

The candidate grain is `account + category + quarter`; it is checked by `01_validation.sql`.

## Forecasts

One row contains a forecast entry for an account and category, with `prediction_category`, `forecast`, `opportunity_age` and `year`. The initial candidate grain `account + category + year` repeats in seven cases. The extended combination including `prediction_category` and `opportunity_age` returned no duplicates in the imported data. No uniqueness constraint is imposed because this is an observed grain, not a declared business rule.
