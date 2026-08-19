USE online_retail_analysis;

-- Identify merchandise products with the largest cancellation exposure.
-- Cancellation records indicate reversed transaction value but do not reveal the underlying cause.

-- Identify merchandise products with the largest cancellation exposure.
-- Cancellation records indicate reversed transaction value but do not reveal the underlying cause.

WITH product_kpis AS
(
    SELECT
        di.item_key,
        di.stock_code,
        di.item_description,

        SUM(
            CASE
                WHEN ft.transaction_status = 'Standard Transaction'
                THEN ft.line_value
                ELSE 0
            END
        ) AS gross_merchandise_sales,

        SUM(
            CASE
                WHEN ft.transaction_status = 'Cancellation'
                THEN ft.line_value
                ELSE 0
            END
        ) AS cancellation_impact,

        SUM(
            CASE
                WHEN ft.transaction_status = 'Standard Transaction'
                     AND ft.unit_price > 0
                THEN ft.quantity
                ELSE 0
            END
        ) AS paid_units_sold,

        ABS(
            SUM(
                CASE
                    WHEN ft.transaction_status = 'Cancellation'
                    THEN ft.quantity
                    ELSE 0
                END
            )
        ) AS cancelled_units,

        COUNT(
            DISTINCT CASE
                WHEN ft.transaction_status = 'Standard Transaction'
                     AND ft.line_value > 0
                THEN ft.invoice_no
                ELSE NULL
            END
        ) AS completed_orders,

        COUNT(
            DISTINCT CASE
                WHEN ft.transaction_status = 'Cancellation'
                THEN ft.invoice_no
                ELSE NULL
            END
        ) AS cancellation_documents

    FROM fact_transactions AS ft
    INNER JOIN dim_item AS di
        ON ft.item_key = di.item_key
    WHERE di.is_merchandise = 1
    GROUP BY
        di.item_key,
        di.stock_code,
        di.item_description
)
SELECT
    stock_code,
    item_description,
    gross_merchandise_sales,
    cancellation_impact,
    gross_merchandise_sales + cancellation_impact AS net_merchandise_sales,
    paid_units_sold,
    cancelled_units,
    completed_orders,
    cancellation_documents,
    ROUND(ABS(cancellation_impact) / NULLIF(gross_merchandise_sales, 0) * 100, 2) AS cancellation_value_rate_pct
FROM product_kpis
WHERE cancellation_impact < 0
ORDER BY ABS(cancellation_impact) DESC
LIMIT 20;


-- Drill into the two products with the largest cancellation exposure
-- to determine whether the result is driven by isolated bulk transactions.

SELECT
    di.stock_code,
    di.item_description,
    ft.invoice_no,
    ft.invoice_datetime,
    ft.transaction_status,
    ft.quantity,
    ft.unit_price,
    ft.line_value,
    dc.customer_label,
    dco.country_name
FROM fact_transactions AS ft
INNER JOIN dim_item AS di
    ON ft.item_key = di.item_key
INNER JOIN dim_customer AS dc
    ON ft.customer_key = dc.customer_key
INNER JOIN dim_country AS dco
    ON ft.country_key = dco.country_key
WHERE di.stock_code IN ('23843', '23166')
ORDER BY
    ABS(ft.line_value) DESC,
    ft.invoice_datetime;
    

-- Compare mean and median standard order value to measure
-- how strongly extreme bulk transactions distort the average.

WITH order_values AS
(
    SELECT
        ft.invoice_no,
        SUM(ft.line_value) AS order_value
    FROM fact_transactions AS ft
    INNER JOIN dim_item AS di
        ON ft.item_key = di.item_key
    WHERE
        ft.transaction_status = 'Standard Transaction'
        AND di.is_merchandise = 1
        AND ft.unit_price > 0
    GROUP BY ft.invoice_no
),
ranked_orders AS
(
    SELECT
        invoice_no,
        order_value,
        ROW_NUMBER() OVER
        (
            ORDER BY order_value
        ) AS order_rank,
        COUNT(*) OVER () AS order_count
    FROM order_values
)
SELECT
    COUNT(*) AS standard_sales_orders,
    ROUND(AVG(order_value), 2) AS mean_order_value,
    ROUND(
        AVG(
            CASE
                WHEN order_rank IN
                (
                    (order_count + 1) DIV 2,
                    (order_count + 2) DIV 2
                )
                THEN order_value
                ELSE NULL
            END
        ),
        2
    ) AS median_order_value,
    MIN(order_value) AS minimum_order_value,
    MAX(order_value) AS maximum_order_value
FROM ranked_orders;