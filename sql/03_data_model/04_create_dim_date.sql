USE online_retail_analysis;

-- Create a continuous calendar dimension covering the complete transaction period.

CREATE TABLE dim_date
(
    date_key INT UNSIGNED PRIMARY KEY,
    full_date DATE NOT NULL,
    calendar_year SMALLINT UNSIGNED NOT NULL,
    quarter_number TINYINT UNSIGNED NOT NULL,
    quarter_label CHAR(2) NOT NULL,
    month_number TINYINT UNSIGNED NOT NULL,
    month_name VARCHAR(10) NOT NULL,
    month_short CHAR(3) NOT NULL,
    year_month_label CHAR(7) NOT NULL,
    year_month_sort INT UNSIGNED NOT NULL,
    day_of_month TINYINT UNSIGNED NOT NULL,
    day_name VARCHAR(10) NOT NULL,
    day_of_week_number TINYINT UNSIGNED NOT NULL,
    week_of_year TINYINT UNSIGNED NOT NULL,
    is_weekend TINYINT NOT NULL,

    CONSTRAINT uq_dim_date_full_date
        UNIQUE (full_date),

    CONSTRAINT chk_dim_date_is_weekend
        CHECK (is_weekend IN (0, 1))
);


-- Generate every calendar date from the first through the last transaction date.

INSERT INTO dim_date
(
    date_key,
    full_date,
    calendar_year,
    quarter_number,
    quarter_label,
    month_number,
    month_name,
    month_short,
    year_month_label,
    year_month_sort,
    day_of_month,
    day_name,
    day_of_week_number,
    week_of_year,
    is_weekend
)

WITH RECURSIVE date_range AS
(
    SELECT
        MIN(DATE(invoice_datetime)) AS full_date
    FROM vw_clean_transactions
    WHERE is_primary_record = 1

    UNION ALL

    SELECT
        DATE_ADD(full_date, INTERVAL 1 DAY)
    FROM date_range
    WHERE full_date <
    (
        SELECT MAX(DATE(invoice_datetime))
        FROM vw_clean_transactions
        WHERE is_primary_record = 1
    )
)
SELECT
    CAST(DATE_FORMAT(full_date, '%Y%m%d') AS UNSIGNED) AS date_key,
    full_date,
    YEAR(full_date) AS calendar_year,
    QUARTER(full_date) AS quarter_number,
    CONCAT('Q', QUARTER(full_date)) AS quarter_label,
    MONTH(full_date) AS month_number,
    DATE_FORMAT(full_date, '%M') AS month_name,
    DATE_FORMAT(full_date, '%b') AS month_short,
    DATE_FORMAT(full_date, '%Y-%m') AS year_month_label,
    YEAR(full_date) * 100 + MONTH(full_date) AS year_month_sort,
    DAY(full_date) AS day_of_month,
    DATE_FORMAT(full_date, '%W') AS day_name,
    WEEKDAY(full_date) + 1 AS day_of_week_number,
    WEEK(full_date, 3) AS week_of_year,
    CASE
        WHEN WEEKDAY(full_date) >= 5 THEN 1
        ELSE 0
    END AS is_weekend
FROM date_range;


-- Validate calendar continuity, uniqueness, and date coverage.

SELECT
    COUNT(*) AS total_dates,
    COUNT(DISTINCT full_date) AS distinct_dates,
    MIN(full_date) AS first_date,
    MAX(full_date) AS last_date,
    DATEDIFF(MAX(full_date), MIN(full_date)) + 1 AS expected_dates
FROM dim_date;


-- Confirm that every primary transaction resolves to exactly one calendar date.

SELECT
    COUNT(*) AS joined_rows,
    COUNT(DISTINCT ct.source_row_id) AS distinct_source_rows,
    SUM(dd.date_key IS NULL) AS orphan_transaction_rows
FROM vw_clean_transactions AS ct
LEFT JOIN dim_date AS dd
    ON DATE(ct.invoice_datetime) = dd.full_date
WHERE ct.is_primary_record = 1;