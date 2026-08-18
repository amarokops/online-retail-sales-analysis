USE online_retail_analysis;

-- Identify exact duplicate candidates across all eight source fields.
-- Quantifies their scale without assuming that identical rows are safe to remove.

WITH duplicate_groups AS (
    SELECT
        invoice_no_raw,
        stock_code_raw,
        description_raw,
        quantity_raw,
        invoice_date_raw,
        unit_price_raw,
        customer_id_raw,
        country_raw,
        COUNT(*) AS row_count
    FROM stg_online_retail
    GROUP BY
        invoice_no_raw,
        stock_code_raw,
        description_raw,
        quantity_raw,
        invoice_date_raw,
        unit_price_raw,
        customer_id_raw,
        country_raw
    HAVING COUNT(*) > 1
)
SELECT
	COUNT(*) AS duplicate_groups,
    SUM(row_count) AS rows_in_duplicate_groups,
    SUM(row_count - 1) AS excess_duplicate_rows
FROM duplicate_groups;


-- Estimate the quantity and transaction value attached to exact duplicate candidates.
-- Measures how deduplication could change reported KPIs before any records are removed.

WITH duplicate_groups AS (
    SELECT
        invoice_no_raw,
        stock_code_raw,
        description_raw,
        quantity_raw,
        invoice_date_raw,
        unit_price_raw,
        customer_id_raw,
        country_raw,
        CAST(quantity_raw AS SIGNED) AS quantity,
        CAST(unit_price_raw AS DECIMAL (12,4)) AS unit_price,
		COUNT(*) AS row_count
    FROM stg_online_retail
    GROUP BY
        invoice_no_raw,
        stock_code_raw,
        description_raw,
        quantity_raw,
        invoice_date_raw,
        unit_price_raw,
        customer_id_raw,
        country_raw
    HAVING COUNT(*) > 1
)
SELECT
	SUM(row_count - 1) AS excess_duplicate_rows,
    SUM((row_count - 1) * quantity) AS potential_excess_quantity,
    SUM((row_count - 1) * quantity * unit_price) AS potential_excess_net_value,
    SUM(CASE
			WHEN quantity * unit_price > 0 THEN (row_count - 1) * quantity * unit_price
            ELSE 0
		END) AS potential_excess_positive_value,
	SUM(CASE
			WHEN quantity * unit_price < 0 THEN (row_count - 1) * quantity * unit_price
            ELSE 0
		END) AS potential_excess_negative_value
FROM duplicate_groups;


-- Calculate full staging transaction values as a baseline for materiality analysis.
-- Provides denominators for evaluating the potential impact of duplicate removal.

WITH typed_transactions AS 
(
    SELECT
        CAST(quantity_raw AS SIGNED) AS quantity,
        CAST(unit_price_raw AS DECIMAL(12, 4)) AS unit_price
    FROM stg_online_retail
)
SELECT
	SUM(quantity) AS total_net_quantity,
    SUM(CASE
			WHEN quantity * unit_price > 0 THEN quantity * unit_price
            ELSE 0
		END) AS total_positive_value,
	SUM(CASE
			WHEN quantity * unit_price < 0 THEN quantity * unit_price
            ELSE 0
		END) AS total_negative_value,
	SUM(quantity * unit_price) AS total_net_value
FROM typed_transactions;