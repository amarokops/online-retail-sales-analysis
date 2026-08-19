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


-- Profile the primary analytical records after duplicate-candidate exclusion.
-- Establishes the cleaned baseline that will feed the dimensional model.
SELECT
	COUNT(*) AS clean_rows,
    COUNT(DISTINCT invoice_no) AS distinct_invoices,
    COUNT(DISTINCT stock_code) AS distinct_stock_codes,
    COUNT(DISTINCT customer_id) AS identified_customers,
    COUNT(DISTINCT country) AS distinct_countries,
    SUM(line_value) AS clean_source_value
FROM vw_clean_transactions
WHERE is_primary_record = 1;


-- Identify product codes with missing or inconsistent descriptions
-- before selecting one canonical description for the product dimension.
SELECT
	stock_code,
	COUNT(*) AS total_rows,
    COUNT(DISTINCT description) AS distinct_descriptions,
    SUM(description IS NULL) AS missing_descriptions
FROM vw_clean_transactions
WHERE 
	is_primary_record = 1
    AND
    transaction_category = 'Merchandise'
GROUP BY
	stock_code
HAVING
	COUNT(DISTINCT description) > 1
    OR
    SUM(description IS NULL) > 0
ORDER BY
	distinct_descriptions DESC,
    total_rows DESC;
    
    
-- Inspect description variants for the product code with the highest
-- number of distinct descriptions before defining a canonical-name rule.

SELECT
	stock_code,
	description,
    COUNT(*) AS total_rows,
    MIN(invoice_datetime) AS first_used_at,
    MAX(invoice_datetime) AS last_used_at
FROM vw_clean_transactions
WHERE 
	is_primary_record = 1
    AND
    transaction_category = 'Merchandise'
    AND
    stock_code = '23084'
GROUP BY
	description
ORDER BY
    total_rows DESC;
    
    
-- Rank valid product descriptions by usage frequency to select one canonical
-- description per stock code without overwriting the original transaction text.

WITH description_frequency AS
(
	SELECT
		stock_code,
        description,
		COUNT(*) AS description_rows,
        MAX(invoice_datetime) AS last_used_at
	FROM vw_clean_transactions
	WHERE
		is_primary_record = 1
		AND 
		transaction_category = 'Merchandise'
		AND 
		transaction_status IN ('Standard Transaction', 'Cancellation')
		AND 
		description IS NOT NULL
	GROUP BY
		stock_code,
        description
),
ranked_descriptions AS
(
	SELECT
		description_frequency.*,
        ROW_NUMBER() OVER
			(
			PARTITION BY
				stock_code
			ORDER BY
				description_rows DESC,
                last_used_at DESC,
                description
			) AS description_rank
    FROM description_frequency
)
SELECT
    stock_code,
    description AS canonical_description,
    description_rows,
    last_used_at
FROM ranked_descriptions
WHERE description_rank = 1 AND stock_code = '23084'
ORDER BY stock_code
LIMIT 20;


-- Count stock codes with a selected canonical description
-- before comparing coverage against all codes required by the fact table.
WITH description_frequency AS
(
	SELECT
		stock_code,
        description,
		COUNT(*) AS description_rows,
        MAX(invoice_datetime) AS last_used_at
	FROM vw_clean_transactions
	WHERE
		is_primary_record = 1
		AND 
		transaction_category = 'Merchandise'
		AND 
		transaction_status IN ('Standard Transaction', 'Cancellation')
		AND 
		description IS NOT NULL
	GROUP BY
		stock_code,
        description
),
ranked_descriptions AS
(
	SELECT
		description_frequency.*,
        ROW_NUMBER() OVER
			(
			PARTITION BY
				stock_code
			ORDER BY
				description_rows DESC,
                last_used_at DESC,
                description
			) AS description_rank
    FROM description_frequency
),
all_stock_codes AS
(
    SELECT
        stock_code,
        transaction_category,
        COUNT(*) AS transaction_rows,
        SUM(description IS NULL) AS missing_description_rows
    FROM vw_clean_transactions
    WHERE is_primary_record = 1
    GROUP BY
        stock_code,
        transaction_category
)
-- Identify stock codes not covered by the canonical-description rule
-- so every transaction can still connect to exactly one dimension record.
SELECT
    sc.stock_code,
    CASE
        WHEN sc.transaction_category <> 'Merchandise'
            THEN sc.transaction_category
        WHEN rd.description IS NOT NULL
            THEN rd.description
        ELSE CONCAT('Unknown Product [', sc.stock_code, ']')
    END AS item_description,
    sc.transaction_category,
    CASE
        WHEN sc.transaction_category = 'Merchandise' THEN 1
        ELSE 0
    END AS is_merchandise
FROM all_stock_codes AS sc
LEFT JOIN ranked_descriptions AS rd
    ON sc.stock_code = rd.stock_code
    AND rd.description_rank = 1
ORDER BY sc.stock_code;