-- Smart Desk - reproducible PostgreSQL schema
-- Does not drop, truncate or replace existing tables.
-- Run while connected to the smart_desk database.

CREATE TABLE IF NOT EXISTS public.accounts (
    account text,
    account_executive text,
    account_level text,
    contact_email text,
    country text,
    industry text,
    region text
);

CREATE TABLE IF NOT EXISTS public.sales (
    account text,
    category text,
    quarter text,
    quarter_of_year text,
    year integer,
    maintenance numeric(18,2),
    parts numeric(18,2),
    product numeric(18,2),
    profit numeric(18,2),
    support numeric(18,2),
    total numeric(18,2),
    units_sold numeric
);

CREATE TABLE IF NOT EXISTS public.forecasts (
    account text,
    category text,
    prediction_category text,
    forecast numeric(18,2),
    opportunity_age integer,
    year integer
);

-- No PK, FK, UNIQUE or CHECK constraints are added until the imports
-- have been verified. Validation is in 01_validation.sql.
