USE online_retail_analysis;

-- Create the transaction fact table at invoice-line grain.
-- Each record represents one primary cleaned source row linked to all dimensions.

CREATE TABLE fact_transactions
(
    transaction_key BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    source_row_id BIGINT UNSIGNED NOT NULL,
    invoice_no VARCHAR(20) NOT NULL,
    invoice_datetime DATETIME NOT NULL,
    invoice_hour TINYINT UNSIGNED NOT NULL,

    date_key INT UNSIGNED NOT NULL,
    item_key INT UNSIGNED NOT NULL,
    customer_key INT UNSIGNED NOT NULL,
    country_key INT UNSIGNED NOT NULL,

    quantity INT NOT NULL,
    unit_price DECIMAL(12,4) NOT NULL,
    line_value DECIMAL(18,4) NOT NULL,

    transaction_status VARCHAR(30) NOT NULL,
    quantity_movement VARCHAR(10) NOT NULL,
    is_cancellation TINYINT NOT NULL,

    CONSTRAINT uq_fact_transactions_source_row
        UNIQUE (source_row_id),

    CONSTRAINT chk_fact_transactions_is_cancellation
        CHECK (is_cancellation IN (0, 1)),

    CONSTRAINT fk_fact_transactions_date
        FOREIGN KEY (date_key)
        REFERENCES dim_date (date_key),

    CONSTRAINT fk_fact_transactions_item
        FOREIGN KEY (item_key)
        REFERENCES dim_item (item_key),

    CONSTRAINT fk_fact_transactions_customer
        FOREIGN KEY (customer_key)
        REFERENCES dim_customer (customer_key),

    CONSTRAINT fk_fact_transactions_country
        FOREIGN KEY (country_key)
        REFERENCES dim_country (country_key)
);


-- Load one fact record per primary cleaned transaction line
-- and replace natural dimension values with surrogate keys.

INSERT INTO fact_transactions
(
    source_row_id,
    invoice_no,
    invoice_datetime,
    invoice_hour,
    date_key,
    item_key,
    customer_key,
    country_key,
    quantity,
    unit_price,
    line_value,
    transaction_status,
    quantity_movement,
    is_cancellation
)
SELECT
    ct.source_row_id,
    ct.invoice_no,
    ct.invoice_datetime,
    HOUR(ct.invoice_datetime) AS invoice_hour,
    dd.date_key,
    di.item_key,
    dc.customer_key,
    dco.country_key,
    ct.quantity,
    ct.unit_price,
    CAST(ct.line_value AS DECIMAL(18,4)) AS line_value,
    ct.transaction_status,
    ct.quantity_movement,
    ct.is_cancellation
FROM vw_clean_transactions AS ct
INNER JOIN dim_date AS dd
    ON DATE(ct.invoice_datetime) = dd.full_date
INNER JOIN dim_item AS di
    ON ct.stock_code = di.stock_code
INNER JOIN dim_customer AS dc
    ON ct.customer_id <=> dc.customer_id
INNER JOIN dim_country AS dco
    ON ct.country = dco.source_country
WHERE ct.is_primary_record = 1;


-- Validate fact-table grain, source-row uniqueness, invoice coverage,
-- date coverage, and reconciliation to the cleaned source value.

SELECT
    COUNT(*) AS fact_rows,
    COUNT(DISTINCT source_row_id) AS distinct_source_rows,
    COUNT(DISTINCT invoice_no) AS distinct_invoices,
    MIN(invoice_datetime) AS first_invoice_at,
    MAX(invoice_datetime) AS last_invoice_at,
    SUM(line_value) AS fact_source_value
FROM fact_transactions;