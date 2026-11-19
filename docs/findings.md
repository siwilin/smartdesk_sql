# Findings

## Evidence-backed observations

The results below were executed by the user in PostgreSQL through DBeaver.

### Data quality and structure

- Row counts match the inspected CSVs: 188 accounts, 159 sales rows and 135 forecast rows.
- The duplicate `accounts.account` query returned no rows.
- No sales or forecast rows lack a matching account (`0` and `0`).
- The `total` check found 1 inconsistent row out of 159. The maximum absolute difference is 1 monetary unit.
- The inconsistent row is `Reidwo Consulting` / `Break room` / `2020 Q4`: `total` is 6,531,068.00 and the component sum is 6,531,069.00, producing a -1.00 difference. It was not changed automatically.
- `units_sold` is fractional in 144 rows; the minimum among those rows is 350.87 and the maximum is 14,851.57. It is therefore stored as `numeric`, not integer.
- `prediction_category` contains `Commit` (19 rows), `Pipeline` (89) and `Upside` (27). `Committed` does not appear in the imported data.
- No duplicates were found in the candidate `sales` grain (`account`, `category`, `quarter`).
- Seven repeated candidate `forecasts` keys were found for `account + category + year`: MilaMart/Break room, Hannigan & Griff/Break room, Deehan Distribution Services/Electronics, Feist Home Goods/Break room, Rowe Creative Group/Break room, Farbey Banking Services/Break room and Anaheim Home Solutions/Break room. This combination is not a unique forecast key.
- The extended validation using `prediction_category` and `opportunity_age` returned no rows, so the observed forecast entries are uniquely distinguished by the extended combination in this import.
- Observed percentiles were: `sales.total` p01 420,781.10, median 1,180,000.00 and p99 5,589,112.46. For `sales.profit`, p01 128,721.58, median 420,266.00 and p99 1,881,304.88.

### Reproduced analysis

- For Adabs Entertainment in 2020, Electronics has total sales of 2,100,000.00 and profit of 756,000.00; Chairs has total sales of 1,835,672.00 and profit of 605,772.00.
- For the average sales row metric, Singapore has the highest APAC average sales value (3,415,680.00) and Austria the highest EMEA average (1,544,030.17). Row counts vary by country, so this is not an average per account.
- For accounts with at least one `Commit` or `Committed` forecast above 500,000, Consulting has the highest total profit (1,846,700.00), followed by Retail (1,381,959.00) and Technology (1,309,161.00). These industries are classified as `High` using the implemented 1,000,000 threshold.
- In actual 2021 profit versus 2022 forecast, Break room has the largest values: 22,115,484.00 actual profit and 33,107,609.00 forecast. Its maximum opportunity age is 78.
- Total sales growth from 2020 to 2021 is +19,775,540.00 for NAM, +8,452,751.00 for EMEA and -4,777,430.00 for APAC. LATAM has no 2020 baseline and is not comparable.
- Product growth is +12,875,619.00 for NAM, +5,224,855.00 for EMEA and -4,748,685.00 for APAC. LATAM only has 2021 product sales of 2,202,284.00.
- Associated services grow by 6,899,921.00 in NAM (+102.75%) and 3,227,896.00 in EMEA (+30.83%). APAC is nearly flat at -28,746.00 (-0.75%). LATAM only has 2021 associated services of 2,046,418.00.

## Interpretations

The country average is an average per `sales` row, usually account-category-quarter, not an average per account or a population-weighted country metric. “Associated services” groups maintenance, support and parts; it does not imply recurring revenue.

NAM growth is driven by both product (+72.79%) and associated services (+102.75%). EMEA grows in both components, while APAC's contraction is concentrated in product (-49.89%) and associated services remain almost unchanged (-0.75%). These are aggregated changes and do not measure customer-level efficiency.

## Recommendations

Review the single-unit mismatch and document the forecast grain before publishing. Present the 2021/2022 profit-versus-forecast comparison as an indicative comparison of different metric types, not as realised revenue. Use a synthetic, separately labelled dataset for a public demonstration if redistribution rights for the academic CSVs are not available.

## Limitations

- Forecast rows are not uniquely identified by `account + category + year`; the extended observed combination adds `prediction_category` and `opportunity_age`, but the project still does not impose a database key.
- The comparison between actual profit and forecast is directional because the measures have different business meanings.
- Regional aggregation does not control for account count, average deal size or changes in account mix.
- The original academic report and assignment were not used to claim reproduced results in this repository.
