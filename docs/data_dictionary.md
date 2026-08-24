# Data Dictionary

## Model Overview

The analytical model follows a star schema centred on `fact_transactions`.

**Fact-table grain:** one cleaned transaction line from an invoice.

| Table | Purpose |
|---|---|
| `fact_transactions` | Cleaned invoice lines containing quantities, prices and transaction values |
| `dim_date` | Calendar attributes used for time-based analysis |
| `dim_item` | Standardized products and operational transaction categories |
| `dim_customer` | Customer identifiers and RFM segmentation results |
| `dim_country` | Standardized countries and domestic/international classification |

---

## `fact_transactions`

| Column | Description |
|---|---|
| `transaction_key` | Surrogate primary key of the transaction line |
| `source_row_id` | Identifier of the corresponding row in the staging table |
| `date_key` | Foreign key to `dim_date` |
| `item_key` | Foreign key to `dim_item` |
| `customer_key` | Foreign key to `dim_customer` |
| `country_key` | Foreign key to `dim_country` |
| `invoice_no` | Source invoice or cancellation-document number |
| `invoice_datetime` | Date and time recorded on the invoice |
| `invoice_hour` | Hour extracted from `invoice_datetime` |
| `quantity` | Number of units recorded on the transaction line |
| `unit_price` | Recorded price per unit in pounds sterling |
| `line_value` | Transaction-line value calculated as `quantity × unit_price` |
| `transaction_status` | Classification as `Standard Transaction`, `Cancellation` or `Inventory Adjustment` |
| `quantity_movement` | Direction of the recorded quantity: `Positive`, `Negative` or `Zero` |
| `is_cancellation` | Flag identifying invoice numbers beginning with `C` |

---

## `dim_date`

| Column | Description |
|---|---|
| `date_key` | Calendar key stored in `YYYYMMDD` format |
| `full_date` | Complete calendar date |
| `calendar_year` | Calendar year |
| `quarter_number` | Quarter number from 1 to 4 |
| `quarter_label` | Quarter label such as `Q1` |
| `month_number` | Month number from 1 to 12 |
| `month_name` | Full English month name |
| `month_short` | Three-letter month abbreviation |
| `year_month_label` | Reporting-month label in `YYYY-MM` format |
| `year_month_sort` | Numeric field used to sort reporting months chronologically |
| `day_of_month` | Day number within the month |
| `day_name` | Full English weekday name |
| `day_of_week_number` | Weekday number beginning with Monday |
| `week_of_year` | Calendar week number |
| `is_weekend` | Flag identifying Saturday and Sunday |

---

## `dim_item`

| Column | Description |
|---|---|
| `item_key` | Surrogate primary key of the item |
| `stock_code` | Source product or operational-entry code |
| `item_description` | Canonical description selected for the stock code |
| `transaction_category` | Classification of the entry, such as `Merchandise`, `Shipping`, `Discount` or `Platform Fee` |
| `is_merchandise` | Flag identifying physical merchandise used in product-sales analysis |

Operational entries remain in the model for reconciliation but are excluded from merchandise rankings.

---

## `dim_customer`

| Column | Description |
|---|---|
| `customer_key` | Surrogate primary key of the customer |
| `customer_id` | Customer identifier supplied by the source dataset |
| `customer_label` | Reporting-friendly customer label |
| `is_identified` | Flag indicating whether a source customer ID is available |
| `first_order_date` | Date of the customer’s first standard sales order |
| `last_order_date` | Date of the customer’s latest standard sales order |
| `recency_days` | Days between the RFM reference date and the latest order |
| `frequency_orders` | Number of distinct standard sales orders |
| `monetary_net_value` | Customer’s net merchandise value after cancellations |
| `recency_score` | Recency quintile score from 1 to 5 |
| `frequency_score` | Frequency quintile score from 1 to 5 |
| `monetary_score` | Monetary quintile score from 1 to 5 |
| `rfm_code` | Combined Recency, Frequency and Monetary score |
| `customer_segment` | Business segment assigned from the RFM scores |

RFM analysis includes only customers with an available `CustomerID`.

---

## `dim_country`

| Column | Description |
|---|---|
| `country_key` | Surrogate primary key of the country |
| `source_country` | Country value retained from the source dataset |
| `country_name` | Standardized country name used in reporting |
| `market_type` | Classification as `Domestic` or `International` |
| `is_domestic` | Flag identifying the United Kingdom |

---

## Transaction Categories

| Category | Meaning |
|---|---|
| `Merchandise` | Physical products included in product-sales analysis |
| `Shipping` | Postage, carriage and delivery-related charges |
| `Discount` | Discount entries reducing transaction value |
| `Manual Adjustment` | Manually recorded operational adjustments |
| `Bank Charge` | Banking-related charges |
| `Platform Fee` | Online-platform fees |
| `Commission` | Commission-related entries |
| `Accounting Adjustment` | Accounting corrections such as bad-debt adjustments |
| `Sample` | Sample-product entries |
| `Gift Voucher` | Gift-voucher transactions |

---

## Core KPI Definitions

| KPI | Definition |
|---|---|
| **Gross Merchandise Sales** | Positive value of standard merchandise transactions before cancellations |
| **Cancellation Impact** | Negative merchandise value recorded on cancellation documents |
| **Net Merchandise Sales** | Gross Merchandise Sales plus Cancellation Impact |
| **Standard Sales Orders** | Distinct invoices containing positive standard merchandise sales |
| **Average Order Value** | Gross Merchandise Sales divided by Standard Sales Orders |
| **Median Order Value** | Median gross merchandise value of standard sales orders |
| **Cancellation Value Rate** | Absolute Cancellation Impact divided by Gross Merchandise Sales |
| **Net Sales Retention** | Net Merchandise Sales divided by Gross Merchandise Sales |
| **Paid Units Sold** | Merchandise quantity from standard transactions with a positive unit price |
| **Cancelled Units** | Absolute merchandise quantity recorded on cancellation documents |
| **Zero-Price Units** | Positive merchandise quantity recorded with a unit price of zero |
| **Zero-Price Unit Share** | Zero-Price Units divided by all positive merchandise units |
| **Active Products** | Distinct merchandise items appearing in the fact table |
| **RFM Customer Value** | Sum of net merchandise value attributed to identified customers |

---

## Relationships

| From | To | Cardinality |
|---|---|---|
| `fact_transactions.date_key` | `dim_date.date_key` | Many-to-one |
| `fact_transactions.item_key` | `dim_item.item_key` | Many-to-one |
| `fact_transactions.customer_key` | `dim_customer.customer_key` | Many-to-one |
| `fact_transactions.country_key` | `dim_country.country_key` | Many-to-one |
