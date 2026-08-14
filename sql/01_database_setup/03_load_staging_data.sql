USE online_retail_analysis;

LOAD DATA LOCAL INFILE 'C:/path/to/repository/data/raw/online_retail.csv'
-- Update the local file path before running this script.
INTO TABLE stg_online_retail
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ';'
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(
    invoice_no_raw,
	stock_code_raw,
	description_raw,
	quantity_raw,
	invoice_date_raw,
	unit_price_raw,
	customer_id_raw,
	country_raw
);


SELECT
    COUNT(*) AS imported_rows,
    COUNT(DISTINCT invoice_no_raw) AS distinct_invoices,
    SUM(
        customer_id_raw IS NULL
        OR TRIM(customer_id_raw) = ''
    ) AS missing_customer_ids
FROM stg_online_retail;