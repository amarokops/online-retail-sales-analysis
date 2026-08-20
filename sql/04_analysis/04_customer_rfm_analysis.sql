USE online_retail_analysis;

-- Build customer-level Recency, Frequency, and Monetary metrics
-- using identified customers and standard merchandise purchasing activity.

WITH analysis_date AS
(
    SELECT
        DATE_ADD(MAX(full_date), INTERVAL 1 DAY) AS reference_date
    FROM dim_date
),
customer_metrics AS
(
    SELECT
        dc.customer_key,
        dc.customer_id,
        dc.customer_label,

        MIN(
            CASE
                WHEN ft.transaction_status = 'Standard Transaction'
                     AND ft.line_value > 0
                THEN DATE(ft.invoice_datetime)
                ELSE NULL
            END
        ) AS first_order_date,

        MAX(
            CASE
                WHEN ft.transaction_status = 'Standard Transaction'
                     AND ft.line_value > 0
                THEN DATE(ft.invoice_datetime)
                ELSE NULL
            END
        ) AS last_order_date,

        DATEDIFF(
            ad.reference_date,
            MAX(
                CASE
                    WHEN ft.transaction_status = 'Standard Transaction'
                         AND ft.line_value > 0
                    THEN DATE(ft.invoice_datetime)
                    ELSE NULL
                END
            )
        ) AS recency_days,

        COUNT(
            DISTINCT CASE
                WHEN ft.transaction_status = 'Standard Transaction'
                     AND ft.line_value > 0
                THEN ft.invoice_no
                ELSE NULL
            END
        ) AS frequency_orders,

        SUM(
            CASE
                WHEN ft.transaction_status = 'Standard Transaction'
                THEN ft.line_value
                WHEN ft.transaction_status = 'Cancellation'
                THEN ft.line_value
                ELSE 0
            END
        ) AS monetary_net_value

    FROM fact_transactions AS ft
    INNER JOIN dim_item AS di
        ON ft.item_key = di.item_key
    INNER JOIN dim_customer AS dc
        ON ft.customer_key = dc.customer_key
    CROSS JOIN analysis_date AS ad

    WHERE
        di.is_merchandise = 1
        AND dc.is_identified = 1

    GROUP BY
        dc.customer_key,
        dc.customer_id,
        dc.customer_label,
        ad.reference_date
)
SELECT *
FROM customer_metrics
WHERE frequency_orders > 0
ORDER BY monetary_net_value DESC
LIMIT 20;


-- Validate the customer RFM population and identify customers
-- with zero or negative net merchandise value before scoring.

WITH analysis_date AS
(
    SELECT
        DATE_ADD(MAX(full_date), INTERVAL 1 DAY) AS reference_date
    FROM dim_date
),
customer_metrics AS
(
    SELECT
        dc.customer_key,
        dc.customer_id,
        dc.customer_label,

        MIN(
            CASE
                WHEN ft.transaction_status = 'Standard Transaction'
                     AND ft.line_value > 0
                THEN DATE(ft.invoice_datetime)
                ELSE NULL
            END
        ) AS first_order_date,

        MAX(
            CASE
                WHEN ft.transaction_status = 'Standard Transaction'
                     AND ft.line_value > 0
                THEN DATE(ft.invoice_datetime)
                ELSE NULL
            END
        ) AS last_order_date,

        DATEDIFF(
            ad.reference_date,
            MAX(
                CASE
                    WHEN ft.transaction_status = 'Standard Transaction'
                         AND ft.line_value > 0
                    THEN DATE(ft.invoice_datetime)
                    ELSE NULL
                END
            )
        ) AS recency_days,

        COUNT(
            DISTINCT CASE
                WHEN ft.transaction_status = 'Standard Transaction'
                     AND ft.line_value > 0
                THEN ft.invoice_no
                ELSE NULL
            END
        ) AS frequency_orders,

        SUM(
            CASE
                WHEN ft.transaction_status = 'Standard Transaction'
                THEN ft.line_value
                WHEN ft.transaction_status = 'Cancellation'
                THEN ft.line_value
                ELSE 0
            END
        ) AS monetary_net_value

    FROM fact_transactions AS ft
    INNER JOIN dim_item AS di
        ON ft.item_key = di.item_key
    INNER JOIN dim_customer AS dc
        ON ft.customer_key = dc.customer_key
    CROSS JOIN analysis_date AS ad

    WHERE
        di.is_merchandise = 1
        AND dc.is_identified = 1

    GROUP BY
        dc.customer_key,
        dc.customer_id,
        dc.customer_label,
        ad.reference_date
),
-- Assign percentile-based RFM scores from 1 to 5.
-- Higher scores consistently represent stronger customer performance.
eligible_customers AS
(
    SELECT *
    FROM customer_metrics
    WHERE frequency_orders > 0
),
scored_customers AS
(
    SELECT
        eligible_customers.*,
        LEAST(5, FLOOR(PERCENT_RANK() OVER(ORDER BY recency_days DESC) * 5) + 1) AS recency_score,
        LEAST(5, FLOOR(PERCENT_RANK() OVER(ORDER BY frequency_orders ASC) * 5) + 1) AS frequency_score,
        LEAST(5, FLOOR(PERCENT_RANK() OVER(ORDER BY monetary_net_value ASC) * 5) + 1) AS monetary_score
    FROM eligible_customers
)
SELECT
    customer_key,
    customer_id,
    customer_label,
    recency_days,
    frequency_orders,
    monetary_net_value,
    recency_score,
    frequency_score,
    monetary_score,
    CONCAT(recency_score, frequency_score, monetary_score) AS rfm_code
FROM scored_customers
ORDER BY
    monetary_net_value DESC
LIMIT 20;


-- Create a reusable customer-level RFM view for segmentation,
-- Excel analysis, and Power BI reporting.

CREATE OR REPLACE VIEW vw_customer_rfm AS
WITH analysis_date AS
(
    SELECT
        DATE_ADD(MAX(full_date), INTERVAL 1 DAY) AS reference_date
    FROM dim_date
),
customer_metrics AS
(
    SELECT
        dc.customer_key,
        dc.customer_id,
        dc.customer_label,

        MIN(
            CASE
                WHEN ft.transaction_status = 'Standard Transaction'
                     AND ft.line_value > 0
                THEN DATE(ft.invoice_datetime)
                ELSE NULL
            END
        ) AS first_order_date,

        MAX(
            CASE
                WHEN ft.transaction_status = 'Standard Transaction'
                     AND ft.line_value > 0
                THEN DATE(ft.invoice_datetime)
                ELSE NULL
            END
        ) AS last_order_date,

        DATEDIFF(
            ad.reference_date,
            MAX(
                CASE
                    WHEN ft.transaction_status = 'Standard Transaction'
                         AND ft.line_value > 0
                    THEN DATE(ft.invoice_datetime)
                    ELSE NULL
                END
            )
        ) AS recency_days,

        COUNT(
            DISTINCT CASE
                WHEN ft.transaction_status = 'Standard Transaction'
                     AND ft.line_value > 0
                THEN ft.invoice_no
                ELSE NULL
            END
        ) AS frequency_orders,

        SUM(
            CASE
                WHEN ft.transaction_status = 'Standard Transaction'
                THEN ft.line_value
                WHEN ft.transaction_status = 'Cancellation'
                THEN ft.line_value
                ELSE 0
            END
        ) AS monetary_net_value

    FROM fact_transactions AS ft
    INNER JOIN dim_item AS di
        ON ft.item_key = di.item_key
    INNER JOIN dim_customer AS dc
        ON ft.customer_key = dc.customer_key
    CROSS JOIN analysis_date AS ad

    WHERE
        di.is_merchandise = 1
        AND dc.is_identified = 1

    GROUP BY
        dc.customer_key,
        dc.customer_id,
        dc.customer_label,
        ad.reference_date
),
-- Assign percentile-based RFM scores from 1 to 5.
-- Higher scores consistently represent stronger customer performance.
eligible_customers AS
(
    SELECT *
    FROM customer_metrics
    WHERE frequency_orders > 0
),
scored_customers AS
(
    SELECT
        eligible_customers.*,
        LEAST(5, FLOOR(PERCENT_RANK() OVER(ORDER BY recency_days DESC) * 5) + 1) AS recency_score,
        LEAST(5, FLOOR(PERCENT_RANK() OVER(ORDER BY frequency_orders ASC) * 5) + 1) AS frequency_score,
        LEAST(5, FLOOR(PERCENT_RANK() OVER(ORDER BY monetary_net_value ASC) * 5) + 1) AS monetary_score
    FROM eligible_customers
),
-- Convert numerical RFM scores into actionable customer segments
-- designed for retention, loyalty, development, and reactivation activity.
segmented_customers AS
(
    SELECT
        scored_customers.*,
        CONCAT(
            recency_score,
            frequency_score,
            monetary_score
        ) AS rfm_code,

        CASE
            WHEN recency_score >= 4
                 AND frequency_score >= 4
                 AND monetary_score >= 4
                THEN 'Champions'

            WHEN recency_score <= 2
                 AND (
                     frequency_score >= 4
                     OR monetary_score >= 4
                 )
                THEN 'At Risk'

            WHEN recency_score >= 3
                 AND frequency_score >= 4
                THEN 'Loyal Customers'

            WHEN recency_score >= 4
                 AND frequency_orders = 1
                THEN 'New Customers'

            WHEN recency_score >= 3
                 AND frequency_score BETWEEN 2 AND 3
                THEN 'Potential Loyalists'

            WHEN recency_score <= 2
                 AND frequency_score <= 2
                 AND monetary_score <= 3
                THEN 'Hibernating'

            ELSE 'Regular Customers'
        END AS customer_segment

    FROM scored_customers
)
SELECT
    customer_key,
    customer_id,
    customer_label,
    first_order_date,
    last_order_date,
    recency_days,
    frequency_orders,
    monetary_net_value,
    recency_score,
    frequency_score,
    monetary_score,
    rfm_code,
    customer_segment
FROM segmented_customers;


-- Validate RFM-view grain, customer uniqueness, score ranges,
-- segment coverage, and total identified-customer value.

SELECT
    COUNT(*) AS rfm_customers,
    COUNT(DISTINCT customer_key) AS distinct_customer_keys,
    COUNT(DISTINCT customer_id) AS distinct_customer_ids,
    COUNT(DISTINCT customer_segment) AS customer_segments,
    MIN(recency_score) AS minimum_recency_score,
    MAX(recency_score) AS maximum_recency_score,
    MIN(frequency_score) AS minimum_frequency_score,
    MAX(frequency_score) AS maximum_frequency_score,
    MIN(monetary_score) AS minimum_monetary_score,
    MAX(monetary_score) AS maximum_monetary_score,
    SUM(monetary_net_value) AS rfm_net_value
FROM vw_customer_rfm;