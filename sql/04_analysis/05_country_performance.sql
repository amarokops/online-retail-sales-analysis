USE online_retail_analysis;

-- Compare merchandise performance across countries while separating
-- gross sales, cancellation impact, order volume, and market contribution.

WITH country_kpis AS
(
    SELECT
        dco.country_key,
        dco.country_name,
        dco.is_domestic,

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

        COUNT(
            DISTINCT CASE
                WHEN ft.transaction_status = 'Standard Transaction'
                     AND ft.line_value > 0
                THEN ft.invoice_no
                ELSE NULL
            END
        ) AS standard_sales_orders

    FROM fact_transactions AS ft
    INNER JOIN dim_item AS di
        ON ft.item_key = di.item_key
    INNER JOIN dim_country AS dco
        ON ft.country_key = dco.country_key

    WHERE di.is_merchandise = 1

    GROUP BY
        dco.country_key,
        dco.country_name,
        dco.is_domestic
),
country_performance AS
(
    SELECT
        country_key,
        country_name,
        is_domestic,
        gross_merchandise_sales,
        cancellation_impact,
        gross_merchandise_sales + cancellation_impact
            AS net_merchandise_sales,
        paid_units_sold,
        standard_sales_orders,

        ROUND(
            gross_merchandise_sales
                / NULLIF(standard_sales_orders, 0),
            2
        ) AS average_order_value,

        ROUND(
            ABS(cancellation_impact)
                / NULLIF(gross_merchandise_sales, 0) * 100,
            2
        ) AS cancellation_value_rate_pct

    FROM country_kpis
)
SELECT
    country_name,
    CASE
        WHEN is_domestic = 1 THEN 'Domestic'
        ELSE 'International'
    END AS market_type,
    gross_merchandise_sales,
    cancellation_impact,
    net_merchandise_sales,
    paid_units_sold,
    standard_sales_orders,
    average_order_value,
    cancellation_value_rate_pct,

    ROUND(
        net_merchandise_sales
            / NULLIF(SUM(net_merchandise_sales) OVER (), 0) * 100,
        2
    ) AS net_sales_share_pct

FROM country_performance
ORDER BY net_merchandise_sales DESC;


