USE online_retail_analysis;

CREATE TABLE IF NOT EXISTS stg_online_retail (
    raw_row_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,

    invoice_no_raw VARCHAR(20),
    stock_code_raw VARCHAR(30),
    description_raw VARCHAR(255),
    quantity_raw VARCHAR(30),
    invoice_date_raw VARCHAR(50),
    unit_price_raw VARCHAR(30),
    customer_id_raw VARCHAR(30),
    country_raw VARCHAR(100),

    source_file VARCHAR(100) NOT NULL DEFAULT 'online_retail.csv',
    loaded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (raw_row_id)
);

SHOW CREATE TABLE stg_online_retail;