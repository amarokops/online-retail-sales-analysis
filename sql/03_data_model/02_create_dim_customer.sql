USE online_retail_analysis;

-- Create the customer dimension with a surrogate key and one controlled
-- member representing transactions without an identified customer.

CREATE TABLE dim_customer
(
    customer_key INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    customer_id INT UNSIGNED NULL,
    customer_label VARCHAR(50) NOT NULL,
    is_identified TINYINT NOT NULL,

    CONSTRAINT uq_dim_customer_customer_id
        UNIQUE (customer_id),

    CONSTRAINT chk_dim_customer_is_identified
        CHECK (is_identified IN (0, 1))
);


-- Insert a controlled dimension member for transactions without customer identification.

INSERT INTO dim_customer
(
    customer_id,
    customer_label,
    is_identified
)
VALUES
(
    NULL,
    'Unidentified Customer',
    0
);


-- Load one dimension record for each identified customer in the cleaned dataset.

INSERT INTO dim_customer
(
    customer_id,
    customer_label,
    is_identified
)
SELECT
    customer_id,
    CONCAT('Customer ', customer_id) AS customer_label,
    1 AS is_identified
FROM vw_clean_transactions
WHERE
    is_primary_record = 1
    AND customer_id IS NOT NULL
GROUP BY customer_id
ORDER BY customer_id;


-- Validate customer-dimension completeness and uniqueness.

SELECT
    COUNT(*) AS total_customer_members,
    COUNT(DISTINCT customer_id) AS identified_customers,
    SUM(is_identified = 1) AS identified_customer_members,
    SUM(is_identified = 0) AS unidentified_customer_members,
    SUM(customer_id IS NULL) AS null_customer_ids
FROM dim_customer;


-- Confirm that every primary transaction resolves to exactly one customer member.
-- The NULL-safe equality operator maps missing customer IDs to the controlled unknown member.

SELECT
    COUNT(*) AS joined_rows,
    COUNT(DISTINCT ct.source_row_id) AS distinct_source_rows,
    SUM(dc.customer_key IS NULL) AS orphan_transaction_rows
FROM vw_clean_transactions AS ct
LEFT JOIN dim_customer AS dc
    ON ct.customer_id <=> dc.customer_id
WHERE ct.is_primary_record = 1;