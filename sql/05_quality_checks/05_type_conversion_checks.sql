-- Validate raw text fields before converting them into analytical data types.
-- Prevents malformed values from being silently converted to zero or NULL in the cleaned layer.

SELECT
	SUM(NULLIF(TRIM(invoice_no_raw), '') IS NULL) AS blank_invoice_numbers,
    SUM(NULLIF(TRIM(stock_code_raw), '') IS NULL) AS blank_stock_codes,
    SUM(NULLIF(TRIM(country_raw), '') IS NULL) AS blank_countries,
    SUM(TRIM(quantity_raw) NOT REGEXP '^-?[0-9]+$') AS invalid_quantity_values,
    SUM(TRIM(unit_price_raw) NOT REGEXP '^-?[0-9]+([.][0-9]+)?$') AS invalid_unit_price_values,
    SUM(STR_TO_DATE(invoice_date_raw, '%e.%m.%Y %H:%i') IS NULL) AS invalid_invoice_dates
FROM stg_online_retail;