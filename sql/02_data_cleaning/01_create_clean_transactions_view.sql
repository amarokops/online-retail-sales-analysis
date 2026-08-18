USE online_retail_analysis;

CREATE OR REPLACE VIEW vw_clean_transactions AS

-- Create an auditable cleaned transaction view with standardized types,
-- business classifications, and explicit duplicate-candidate ranking.
WITH prepared_transactions AS
(
	SELECT
		raw_row_id AS source_row_id,
        TRIM(invoice_no_raw) AS invoice_no,
        UPPER(TRIM(stock_code_raw)) AS stock_code,
        NULLIF(TRIM(description_raw), '') AS description,
        CAST(quantity_raw AS SIGNED) AS quantity,
        STR_TO_DATE(invoice_date_raw, '%e.%m.%Y %H:%i') AS invoice_datetime,
        CAST(unit_price_raw AS DECIMAL(12,4)) AS unit_price,
        CAST(NULLIF(TRIM(customer_id_raw), '') AS UNSIGNED) AS customer_id,
        TRIM(country_raw) AS country,
        CAST(quantity_raw AS SIGNED) * CAST(unit_price_raw AS DECIMAL(12,4)) AS line_value,
        CASE
			WHEN TRIM(invoice_no_raw) LIKE 'C%' THEN 1
            ELSE 0
        END AS is_cancellation,
        CASE
			WHEN NULLIF(TRIM(customer_id_raw), '') IS NOT NULL THEN 1
            ELSE 0
        END AS has_customer,
        CASE
			WHEN CAST(quantity_raw AS SIGNED) > 0 THEN 'Positive'
            WHEN CAST(quantity_raw AS SIGNED) < 0 THEN 'Negative'
            ELSE 'Zero'
        END AS quantity_movement,
        CASE
			WHEN TRIM(invoice_no_raw) LIKE 'C%' THEN 'Cancellation'
			WHEN CAST(quantity_raw AS SIGNED) < 0 THEN 'Inventory Adjustment'
			ELSE 'Standard Transaction'
        END AS transaction_status,
		CASE
			WHEN UPPER(TRIM(stock_code_raw)) IN ('POST','DOT','C2') THEN 'Shipping'
            WHEN UPPER(TRIM(stock_code_raw)) = 'D' THEN 'Discount'
            WHEN UPPER(TRIM(stock_code_raw)) = 'M' THEN 'Manual Adjustment'
            WHEN UPPER(TRIM(stock_code_raw)) = 'BANK CHARGES' THEN 'Bank Charge'
            WHEN UPPER(TRIM(stock_code_raw)) = 'AMAZONFEE' THEN 'Platform Fee'
            WHEN UPPER(TRIM(stock_code_raw)) = 'CRUK' THEN 'Commission'
            WHEN UPPER(TRIM(stock_code_raw)) = 'B' THEN 'Accounting Adjustment'
            WHEN UPPER(TRIM(stock_code_raw)) = 'S' THEN 'Sample'
            WHEN UPPER(TRIM(stock_code_raw)) LIKE 'GIFT_%' THEN 'Gift Voucher'
            ELSE 'Merchandise'
		END AS transaction_category
    FROM stg_online_retail
),
-- Rank exact duplicate candidates while preserving every source record.
-- The first occurrence remains primary and later occurrences can be excluded analytically.
ranked_transactions AS
(
	SELECT
		prepared_transactions.*,
        ROW_NUMBER() OVER(
			PARTITION BY 
				invoice_no, 
				stock_code, 
				description, 
				quantity, 
				invoice_datetime, 
				unit_price, 
				customer_id, 
				country 
			ORDER BY 
				source_row_id) AS duplicate_rank
	FROM prepared_transactions
)
SELECT
    ranked_transactions.*,
    CASE
        WHEN duplicate_rank = 1 THEN 1
        ELSE 0
    END AS is_primary_record,
    CASE
        WHEN duplicate_rank > 1 THEN 1
        ELSE 0
    END AS is_duplicate_candidate
FROM ranked_transactions;


-- Validate that the cleaned view preserves all source rows
-- and flags the expected number of duplicate candidates.
SELECT
    COUNT(*) AS total_rows,
    SUM(is_primary_record) AS primary_records,
    SUM(is_duplicate_candidate) AS duplicate_candidate_rows
FROM vw_clean_transactions;