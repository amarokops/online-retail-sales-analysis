USE online_retail_analysis;

-- Calculate monthly merchandise performance to identify seasonality,
-- sales growth, cancellation impact, and changes in average order value.

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
        ) AS completed_orders,
        dd.year_month_label,
		dd.year_month_sort
    FROM fact_transactions ft
    INNER JOIN dim_item di
        ON ft.item_key = di.item_key
	INNER JOIN dim_date dd
		ON ft.date_key = dd.date_key
	GROUP BY
        dd.year_month_label,
        dd.year_month_sort
)
SELECT
	year_month_label,
    gross_merchandise_sales,
    merchandise_cancellation_impact,
    gross_merchandise_sales + merchandise_cancellation_impact AS net_merchandise_sales,
    completed_orders,
    ROUND(gross_merchandise_sales / NULLIF(completed_orders, 0), 2) AS average_order_value,
    ROUND(ABS(merchandise_cancellation_impact) / NULLIF(gross_merchandise_sales, 0) * 100, 2) AS cancellation_value_rate_pct,
    CASE
		WHEN year_month_label = '2011-12' THEN 'Partial Month'
		ELSE 'Complete Month'
	END AS period_coverage
FROM core_kpis
ORDER BY
	year_month_sort;