USE online_retail_analysis;

-- Create an invoice-level summary view for Excel reconciliation
-- and ad hoc order analysis without exposing transaction-line volume.
-- Invoice lines may span adjacent minutes, so the earliest recorded
-- timestamp is used as the representative document time.

CREATE OR REPLACE VIEW vw_order_summary AS

SELECT
    ft.invoice_no,
	MIN(ft.invoice_datetime) AS invoice_datetime,
	HOUR(MIN(ft.invoice_datetime)) AS invoice_hour,
    ft.date_key,

    ft.customer_key,
    dc.customer_id,
    dc.customer_label,
    dc.is_identified,

    ft.country_key,
    dco.country_name,
    dco.is_domestic,

    ft.transaction_status AS document_status,

    COUNT(*) AS line_count,
    COUNT(DISTINCT ft.item_key) AS distinct_items,

    SUM(
        CASE
            WHEN di.is_merchandise = 1
                 AND ft.transaction_status = 'Standard Transaction'
            THEN ft.line_value
            ELSE 0
        END
    ) AS gross_merchandise_sales,

    SUM(
        CASE
            WHEN di.is_merchandise = 1
                 AND ft.transaction_status = 'Cancellation'
            THEN ft.line_value
            ELSE 0
        END
    ) AS merchandise_cancellation_impact,

    SUM(
        CASE
            WHEN di.is_merchandise = 1
            THEN ft.line_value
            ELSE 0
        END
    ) AS net_merchandise_value,

    SUM(
        CASE
            WHEN di.is_merchandise = 1
                 AND ft.transaction_status = 'Standard Transaction'
                 AND ft.unit_price > 0
            THEN ft.quantity
            ELSE 0
        END
    ) AS paid_units,

    SUM(
        CASE
            WHEN di.is_merchandise = 1
                 AND ft.transaction_status = 'Standard Transaction'
                 AND ft.unit_price = 0
            THEN ft.quantity
            ELSE 0
        END
    ) AS zero_price_units,

    SUM(
        CASE
            WHEN di.transaction_category = 'Shipping'
            THEN ft.line_value
            ELSE 0
        END
    ) AS shipping_value,

    SUM(
        CASE
            WHEN di.transaction_category = 'Discount'
            THEN ft.line_value
            ELSE 0
        END
    ) AS discount_value,

    SUM(
        CASE
            WHEN di.transaction_category = 'Gift Voucher'
            THEN ft.line_value
            ELSE 0
        END
    ) AS gift_voucher_value,

    SUM(
        CASE
            WHEN di.transaction_category NOT IN
            (
                'Merchandise',
                'Shipping',
                'Discount',
                'Gift Voucher'
            )
            THEN ft.line_value
            ELSE 0
        END
    ) AS operational_adjustment_value,

    SUM(ft.line_value) AS total_document_value

FROM fact_transactions AS ft
INNER JOIN dim_item AS di
    ON ft.item_key = di.item_key
INNER JOIN dim_customer AS dc
    ON ft.customer_key = dc.customer_key
INNER JOIN dim_country AS dco
    ON ft.country_key = dco.country_key

GROUP BY
    ft.invoice_no,
    ft.date_key,
    ft.customer_key,
    dc.customer_id,
    dc.customer_label,
    dc.is_identified,
    ft.country_key,
    dco.country_name,
    dco.is_domestic,
    ft.transaction_status;
    

-- Validate invoice-level grain and reconcile the order summary
-- to the transaction fact table and approved KPI baselines.

SELECT
    COUNT(*) AS summary_rows,
    COUNT(DISTINCT invoice_no) AS distinct_invoices,

    SUM(gross_merchandise_sales) AS gross_merchandise_sales,
    SUM(merchandise_cancellation_impact) AS cancellation_impact,
    SUM(net_merchandise_value) AS net_merchandise_sales,

    SUM(total_document_value) AS reconciled_source_value,

    SUM(
        document_status = 'Standard Transaction'
        AND gross_merchandise_sales > 0
    ) AS standard_sales_orders,

    SUM(document_status = 'Cancellation')
        AS cancellation_documents,

    SUM(document_status = 'Inventory Adjustment')
        AS inventory_adjustment_documents

FROM vw_order_summary;


-- Identify invoice numbers containing inconsistent timestamps,
-- customers, countries, or transaction statuses across their line items.

SELECT
    ft.invoice_no,
    COUNT(*) AS transaction_lines,
    COUNT(DISTINCT ft.invoice_datetime) AS distinct_datetimes,
    COUNT(DISTINCT ft.date_key) AS distinct_dates,
    COUNT(DISTINCT ft.customer_key) AS distinct_customers,
    COUNT(DISTINCT ft.country_key) AS distinct_countries,
    COUNT(DISTINCT ft.transaction_status) AS distinct_statuses,
    MIN(ft.invoice_datetime) AS first_recorded_at,
    MAX(ft.invoice_datetime) AS last_recorded_at
FROM fact_transactions AS ft
GROUP BY ft.invoice_no
HAVING
    COUNT(DISTINCT ft.invoice_datetime) > 1
    OR COUNT(DISTINCT ft.date_key) > 1
    OR COUNT(DISTINCT ft.customer_key) > 1
    OR COUNT(DISTINCT ft.country_key) > 1
    OR COUNT(DISTINCT ft.transaction_status) > 1
ORDER BY
    distinct_statuses DESC,
    distinct_customers DESC,
    distinct_countries DESC,
    distinct_datetimes DESC,
    ft.invoice_no;