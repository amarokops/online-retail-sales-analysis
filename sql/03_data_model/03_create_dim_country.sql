USE online_retail_analysis;

-- Create the country dimension with standardized display names
-- and a flag separating domestic from international transactions.

CREATE TABLE dim_country
(
    country_key INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    source_country VARCHAR(50) NOT NULL,
    country_name VARCHAR(50) NOT NULL,
    is_domestic TINYINT NOT NULL,

    CONSTRAINT uq_dim_country_source_country
        UNIQUE (source_country),

    CONSTRAINT chk_dim_country_is_domestic
        CHECK (is_domestic IN (0, 1))
);


-- Load one country member per distinct source value and standardize
-- selected legacy country labels for clearer reporting.

INSERT INTO dim_country
(
    source_country,
    country_name,
    is_domestic
)
SELECT DISTINCT
    country AS source_country,
    CASE
        WHEN country = 'EIRE' THEN 'Ireland'
        WHEN country = 'RSA' THEN 'South Africa'
        WHEN country = 'USA' THEN 'United States'
        ELSE country
    END AS country_name,
    CASE
        WHEN country = 'United Kingdom' THEN 1
        ELSE 0
    END AS is_domestic
FROM vw_clean_transactions
WHERE is_primary_record = 1
ORDER BY country;


-- Validate country-dimension completeness and domestic/international split.

SELECT
    COUNT(*) AS total_countries,
    COUNT(DISTINCT source_country) AS distinct_source_countries,
    SUM(is_domestic = 1) AS domestic_country_members,
    SUM(is_domestic = 0) AS international_country_members
FROM dim_country;


-- Confirm that every primary transaction resolves to exactly one country member.

SELECT
    COUNT(*) AS joined_rows,
    COUNT(DISTINCT ct.source_row_id) AS distinct_source_rows,
    SUM(dc.country_key IS NULL) AS orphan_transaction_rows
FROM vw_clean_transactions AS ct
LEFT JOIN dim_country AS dc
    ON ct.country = dc.source_country
WHERE ct.is_primary_record = 1;