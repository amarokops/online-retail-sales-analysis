USE online_retail_analysis;

-- Reconcile row counts and total transaction value between the cleaned
-- source view and the transaction fact table.
WITH clean_source AS
(
    SELECT
        COUNT(*) AS row_count,
        COUNT(DISTINCT source_row_id) AS distinct_source_rows,
        SUM(line_value) AS total_value
    FROM vw_clean_transactions
    WHERE is_primary_record = 1
),
fact_model AS
(
    SELECT
        COUNT(*) AS row_count,
        COUNT(DISTINCT source_row_id) AS distinct_source_rows,
        SUM(line_value) AS total_value
    FROM fact_transactions
)
SELECT
    cs.row_count AS clean_source_rows,
    fm.row_count AS fact_rows,
    fm.row_count - cs.row_count AS row_count_difference,

    cs.distinct_source_rows AS clean_distinct_source_rows,
    fm.distinct_source_rows AS fact_distinct_source_rows,

    cs.total_value AS clean_source_value,
    fm.total_value AS fact_source_value,
    fm.total_value - cs.total_value AS value_difference,

    CASE
        WHEN cs.row_count = fm.row_count
         AND cs.distinct_source_rows = fm.distinct_source_rows
         AND ABS(fm.total_value - cs.total_value) < 0.01
        THEN 'PASS'
        ELSE 'FAIL'
    END AS reconciliation_status
FROM clean_source cs
CROSS JOIN fact_model fm;


-- Verify that the order summary contains exactly one row per invoice
-- and preserves the complete value of the transaction fact table.
WITH fact_totals AS
(
    SELECT
        COUNT(DISTINCT invoice_no) AS distinct_invoices,
        SUM(line_value) AS total_value
    FROM fact_transactions
),
order_summary_totals AS
(
    SELECT
        COUNT(*) AS summary_rows,
        COUNT(DISTINCT invoice_no) AS distinct_invoices,
        SUM(total_document_value) AS total_value
    FROM vw_order_summary
)
SELECT
    ft.distinct_invoices AS fact_distinct_invoices,
    ost.summary_rows,
    ost.distinct_invoices AS summary_distinct_invoices,

    ft.total_value AS fact_total_value,
    ost.total_value AS summary_total_value,
    ost.total_value - ft.total_value AS value_difference,

    CASE
        WHEN ost.summary_rows = ft.distinct_invoices
         AND ost.distinct_invoices = ft.distinct_invoices
         AND ABS(ost.total_value - ft.total_value) < 0.01
        THEN 'PASS'
        ELSE 'FAIL'
    END AS reconciliation_status
FROM fact_totals ft
CROSS JOIN order_summary_totals ost;