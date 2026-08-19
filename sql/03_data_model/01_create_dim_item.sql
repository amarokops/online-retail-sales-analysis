USE online_retail_analysis;

-- Create the item dimension with one surrogate key per source stock code.
-- Separates merchandise from shipping, discounts, fees, and other operational items.

CREATE TABLE dim_item
(
    item_key INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    stock_code VARCHAR(20) NOT NULL,
    item_description VARCHAR(100) NOT NULL,
    transaction_category VARCHAR(50) NOT NULL,
    is_merchandise TINYINT NOT NULL,
    CONSTRAINT uq_dim_item_stock_code UNIQUE (stock_code),
	CONSTRAINT chk_dim_item_is_merchandise CHECK (is_merchandise IN (0, 1))
);


-- Load one dimension record per stock code using canonical merchandise
-- descriptions and business-category labels for non-merchandise items.
INSERT INTO dim_item
(
    stock_code,
    item_description,
    transaction_category,
    is_merchandise
)

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
SELECT
    sc.stock_code,
    CASE
        WHEN sc.transaction_category <> 'Merchandise' THEN sc.transaction_category
        WHEN rd.description IS NOT NULL THEN rd.description
        ELSE CONCAT('Unknown Product [', sc.stock_code, ']')
    END AS item_description,
    sc.transaction_category,
	CASE
        WHEN sc.transaction_category = 'Merchandise' THEN 1
        ELSE 0
    END AS is_merchandise
FROM all_stock_codes sc
LEFT JOIN ranked_descriptions rd
    ON sc.stock_code = rd.stock_code
    AND rd.description_rank = 1
ORDER BY
	sc.stock_code;
    

-- Validate item-dimension completeness, uniqueness, category split,
-- and the number of merchandise records requiring fallback descriptions.

SELECT
    COUNT(*) AS total_items,
    COUNT(DISTINCT stock_code) AS distinct_stock_codes,
    SUM(is_merchandise = 1) AS merchandise_items,
    SUM(is_merchandise = 0) AS non_merchandise_items,
    SUM(item_description LIKE 'Unknown Product [%') AS unknown_product_descriptions,
    SUM(item_description IS NULL) AS missing_item_descriptions
FROM dim_item;


-- Confirm that every primary transaction matches exactly one item record
-- without changing the cleaned row count or reconciled source value.

SELECT
    COUNT(*) AS joined_rows,
    COUNT(DISTINCT ct.source_row_id) AS distinct_source_rows,
    SUM(ct.line_value) AS joined_source_value,
    SUM(di.item_key IS NULL) AS orphan_transaction_rows
FROM vw_clean_transactions AS ct
LEFT JOIN dim_item AS di
    ON ct.stock_code = di.stock_code
WHERE ct.is_primary_record = 1;
