USE online_retail_analysis;

-- Profile non-standard stock codes that may represent fees, discounts or operational adjustments.
-- Prevents non-merchandise records from distorting product sales and product ranking metrics.


WITH typed_transactions AS
(
    SELECT
		stock_code_raw AS stock_code,
		description_raw AS description,
        invoice_no_raw AS invoice_no,
        customer_id_raw AS customer_id,
        CAST(quantity_raw AS SIGNED) AS quantity,
        CAST(unit_price_raw AS DECIMAL(12, 4)) AS unit_price
    FROM stg_online_retail
)
SELECT 
	stock_code,
    description,
	COUNT(*) AS total_rows,
    COUNT(DISTINCT invoice_no) AS distinct_invoices,
    SUM(quantity) AS total_quantity,
	SUM(CASE
			WHEN quantity * unit_price > 0 THEN quantity * unit_price
            ELSE 0
		END) AS total_positive_value,
	SUM(CASE
			WHEN quantity * unit_price < 0 THEN quantity * unit_price
            ELSE 0
		END) AS total_negative_value,
	SUM(quantity * unit_price) AS total_net_value,
    SUM((NULLIF(TRIM(customer_id), '')) IS NULL) AS missing_customer_ids
FROM typed_transactions
WHERE 
	LOWER(stock_code) REGEXP '^[A-Za-z ]+$'
    OR
    LOWER(stock_code) REGEXP '^gift_'
    OR
    stock_code = 'C2'
GROUP BY
	stock_code,
    description
ORDER BY
    total_rows DESC,
    stock_code,
    description;
    

-- Validate the proposed transaction categories before applying them in the cleaned data layer.
-- Measures the row count and net value assigned to each business category.

WITH classified_transactions AS
(
	SELECT
		invoice_no_raw AS invoice_no,
		CAST(quantity_raw AS SIGNED) AS quantity,
        CAST(unit_price_raw AS DECIMAL(12, 4)) AS unit_price,
        CASE
			WHEN stock_code_raw IN ('POST','DOT','C2') THEN 'Shipping'
            WHEN stock_code_raw = 'D' THEN 'Discount'
            WHEN stock_code_raw = 'M' THEN 'Manual Adjustment'
            WHEN stock_code_raw = 'BANK CHARGES' THEN 'Bank Charge'
            WHEN stock_code_raw = 'AMAZONFEE' THEN 'Platform Fee'
            WHEN stock_code_raw = 'CRUK' THEN 'Commission'
            WHEN stock_code_raw = 'B' THEN 'Accounting Adjustment'
            WHEN stock_code_raw = 'S' THEN 'Sample'
            WHEN LOWER(stock_code_raw) REGEXP '^gift_' THEN 'Gift Voucher'
            ELSE 'Merchandise'
        END AS transaction_category
    FROM stg_online_retail
)
SELECT
	transaction_category,
    COUNT(*) AS total_rows,
    COUNT(DISTINCT invoice_no) AS distinct_invoices,
    SUM(quantity) AS total_quantity,
    SUM(CASE
			WHEN quantity * unit_price > 0 THEN quantity * unit_price
            ELSE 0
		END) AS total_positive_value,
	SUM(CASE
			WHEN quantity * unit_price < 0 THEN quantity * unit_price
            ELSE 0
		END) AS total_negative_value,
	SUM(quantity * unit_price) AS total_net_value
FROM classified_transactions
GROUP BY 
	transaction_category
ORDER BY
	total_net_value DESC;
