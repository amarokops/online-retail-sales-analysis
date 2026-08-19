USE online_retail_analysis;

-- Calculate core merchandise KPIs while keeping cancellations,
-- zero-price items, and shipping separate from standard product sales.

-- Calculate core merchandise KPIs while keeping cancellations,
-- zero-price items, and non-merchandise activity separate.

WITH core_kpis AS
(
    SELECT
        SUM(
            CASE
                WHEN ft.transaction_status = 'Standard Transaction'
				AND di.transaction_category = 'Merchandise'
                THEN ft.line_value
                ELSE 0
            END
        ) AS gross_merchandise_sales,
        
        SUM(
            CASE
                WHEN ft.transaction_status = 'Cancellation'
				AND di.transaction_category = 'Merchandise'
                THEN ft.line_value
                ELSE 0
            END
        ) AS merchandise_cancellation_impact,

        SUM(
            CASE
                WHEN ft.transaction_status = 'Standard Transaction'
				AND di.transaction_category = 'Merchandise'
				AND ft.unit_price > 0
                THEN ft.quantity
                ELSE 0
            END
        ) AS paid_units_sold,

        SUM(
            CASE
                WHEN ft.transaction_status = 'Standard Transaction'
				AND di.transaction_category = 'Merchandise'
				AND ft.unit_price = 0
                THEN ft.quantity
                ELSE 0
            END
        ) AS zero_price_units,

        COUNT(
            DISTINCT CASE
                WHEN ft.transaction_status = 'Standard Transaction'
				AND di.transaction_category = 'Merchandise'
				AND ft.line_value > 0
                THEN ft.invoice_no
                ELSE NULL
            END
        ) AS completed_orders
    FROM fact_transactions AS ft
    INNER JOIN dim_item AS di
        ON ft.item_key = di.item_key
)
SELECT
    gross_merchandise_sales,
    merchandise_cancellation_impact,
    gross_merchandise_sales + merchandise_cancellation_impact AS net_merchandise_sales,
    paid_units_sold,
    zero_price_units,
    completed_orders,
    ROUND(gross_merchandise_sales / NULLIF(completed_orders, 0), 2) AS average_order_value,
    ROUND(ABS(merchandise_cancellation_impact) / NULLIF(gross_merchandise_sales, 0) * 100, 2) AS cancellation_value_rate_pct,
    ROUND((gross_merchandise_sales + merchandise_cancellation_impact) / NULLIF(gross_merchandise_sales, 0) * 100, 2) AS net_sales_retention_pct,
    ROUND(paid_units_sold / NULLIF(completed_orders, 0), 2) AS avg_paid_units_per_order
FROM core_kpis;