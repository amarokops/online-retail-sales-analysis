USE online_retail_analysis;

-- 1. Profile the main transaction anomalies in the staging table.
-- Compares cancellation indicators with negative quantities and flags zero or negative prices.
SELECT
	COUNT(*) AS total_rows,
    SUM(invoice_no_raw LIKE 'C%') AS cancellation_rows,
    SUM(CAST(quantity_raw AS SIGNED) < 0) AS negative_quantity_rows,
    SUM(CAST(quantity_raw AS SIGNED) = 0) AS zero_quantity_rows,
	SUM(CAST(unit_price_raw AS DECIMAL(12, 4)) < 0) AS negative_price_rows,
    SUM(CAST(unit_price_raw AS DECIMAL(12, 4)) = 0) AS zero_price_rows,
    SUM(invoice_no_raw LIKE 'C%' AND (CAST(quantity_raw AS SIGNED) < 0)) AS negative_quantity_cancellation_rows,
    SUM(invoice_no_raw NOT LIKE 'C%' AND (CAST(quantity_raw AS SIGNED) < 0)) AS negative_quantity_non_cancellation_rows
FROM stg_online_retail;


-- 2. Inspect the most frequent products with negative quantities outside cancellation invoices.
-- Helps determine whether these records represent customer activity or internal inventory adjustments.
SELECT
	COUNT(*) AS total_rows,
	stock_code_raw AS stock_code,
    description_raw AS description,
    SUM(CAST(quantity_raw AS SIGNED)) AS total_quantity,
    COUNT(DISTINCT invoice_no_raw) AS distinct_invoices,
    SUM(NULLIF(TRIM(customer_id_raw), '') IS NULL) AS missing_customer_ids
FROM stg_online_retail
WHERE
	CAST(quantity_raw AS SIGNED) < 0
	AND
    invoice_no_raw NOT LIKE 'C%'
GROUP BY
	stock_code_raw,
    description_raw
ORDER BY total_rows DESC
LIMIT 20;


-- 3. Summarize all negative-quantity records that are not marked as cancellations.
-- Checks whether missing descriptions, missing customers and zero prices support an inventory-adjustment classification.
SELECT
	COUNT(*) AS total_rows,
    COUNT(DISTINCT invoice_no_raw) AS distinct_invoices,
    COUNT(DISTINCT stock_code_raw) AS distinct_products,
    SUM(NULLIF(TRIM(description_raw), '') IS NULL) AS missing_descriptions,
    SUM(NULLIF(TRIM(customer_id_raw), '') IS NULL) AS missing_customer_ids,
    SUM(CAST(unit_price_raw AS DECIMAL(12,4)) = 0) AS zero_price_rows,
    SUM(CAST(unit_price_raw AS DECIMAL(12,4)) <> 0) AS non_zero_price_rows
FROM stg_online_retail
WHERE
	CAST(quantity_raw AS SIGNED) < 0
    AND
    invoice_no_raw NOT LIKE 'C%';
    

-- 4. Classify every zero-price record by invoice status and quantity direction.
-- Separates cancellations, negative non-cancellations, positive quantities and any zero-quantity records.
WITH zero_price_data AS
(
	SELECT
		invoice_no_raw,
        stock_code_raw,
        description_raw,
        customer_id_raw,
        CAST(quantity_raw AS SIGNED) AS quantity,
		CASE
			WHEN invoice_no_raw LIKE 'C%' THEN 'Cancellation'
            WHEN CAST(quantity_raw AS SIGNED) < 0 THEN 'Negative Non-Cancellation'
            WHEN CAST(quantity_raw AS SIGNED) > 0 THEN 'Positive Quantity'
            ELSE 'Zero Quantity'
        END AS zero_price_type
    FROM stg_online_retail
    WHERE CAST(unit_price_raw AS DECIMAL(12,4)) = 0
)
SELECT
	zero_price_type,
	COUNT(*) AS total_rows,
    COUNT(DISTINCT invoice_no_raw) AS distinct_invoices,
    COUNT(DISTINCT stock_code_raw) AS distinct_products,
    SUM(NULLIF(TRIM(description_raw), '') IS NULL) AS missing_descriptions,
    SUM(NULLIF(TRIM(customer_id_raw), '') IS NULL) AS missing_customer_ids,
    SUM(quantity) AS total_quantity
FROM zero_price_data
GROUP BY zero_price_type;


-- 5. Inspect positive-quantity, zero-price products assigned to identified customers.
-- These records are possible promotional items, manual adjustments or data-quality issues.
SELECT
	COUNT(*) AS total_rows,
    stock_code_raw AS stock_code,
    description_raw AS description,
    SUM(CAST(quantity_raw AS SIGNED)) AS total_quantity,
    COUNT(DISTINCT invoice_no_raw) AS distinct_invoices,
    COUNT(DISTINCT customer_id_raw) AS distinct_customers
FROM stg_online_retail
WHERE
	CAST(unit_price_raw AS DECIMAL(12, 4)) = 0
	AND
	CAST(quantity_raw AS SIGNED) > 0
    AND
    NULLIF(TRIM(customer_id_raw), '') IS NOT NULL
GROUP BY
	stock_code_raw,
    description_raw
ORDER BY
	total_rows DESC,
    total_quantity DESC;
    

-- 6. Check whether customer-linked zero-price items appear alongside paid invoice lines.
-- Invoices containing paid lines support a promotional-item interpretation; zero-price-only invoices remain unclassified.
WITH target_invoices AS
(
	SELECT DISTINCT
		invoice_no_raw
    FROM stg_online_retail
    WHERE
		CAST(unit_price_raw AS DECIMAL(12,4)) = 0
        AND
        CAST(quantity_raw AS SIGNED) > 0
        AND
        NULLIF(TRIM(customer_id_raw), '') IS NOT NULL
)
SELECT
	ti.invoice_no_raw AS invoice_no,
    COUNT(*) AS total_lines,
    SUM(CAST(sor.unit_price_raw AS DECIMAL(12,4)) > 0) AS positive_price_lines,
    SUM(CAST(sor.unit_price_raw AS DECIMAL(12,4)) = 0) AS zero_price_lines,
    SUM((CAST(sor.quantity_raw AS SIGNED)) * (CAST(sor.unit_price_raw AS DECIMAL(12,4)))) AS invoice_value
FROM target_invoices ti
INNER JOIN stg_online_retail sor
ON ti.invoice_no_raw = sor.invoice_no_raw
GROUP BY 
	ti.invoice_no_raw
ORDER BY
	positive_price_lines;
