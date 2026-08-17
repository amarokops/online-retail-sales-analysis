USE online_retail_analysis;

SELECT 
	COUNT(*) AS total_rows,
    COUNT(DISTINCT invoice_no_raw) AS distinct_invoices,
    COUNT(DISTINCT stock_code_raw) AS distinct_products,
    COUNT(DISTINCT(NULLIF(TRIM(customer_id_raw), ''))) AS identified_customers,
    COUNT(DISTINCT country_raw) AS distinct_countries,
    MIN(STR_TO_DATE(invoice_date_raw, '%e.%m.%Y %H:%i')) AS first_invoice_at,
    MAX(STR_TO_DATE(invoice_date_raw, '%e.%m.%Y %H:%i')) AS last_invoice_at,
    SUM(NULLIF(TRIM(description_raw), '') IS NULL) AS missing_descriptions,
    SUM(NULLIF(TRIM(customer_id_raw), '') IS NULL) AS missing_customer_ids
FROM stg_online_retail;