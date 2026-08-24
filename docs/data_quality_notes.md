# Data Quality Notes

## Purpose

This document records the main data-quality findings, cleaning decisions and reconciliation checks applied before business analysis.

The original staging table remains unchanged. Cleaning rules are implemented in SQL views and model tables so that every final transaction can be traced back to its source row.

---

## Source Overview

| Metric | Result |
|---|---:|
| Source rows | **541,909** |
| Distinct invoices | **25,900** |
| Distinct stock codes | **3,958** |
| Identified customers | **4,372** |
| Countries | **38** |
| First invoice | **1 December 2010** |
| Last invoice | **9 December 2011** |

---

## Missing Values

| Finding | Rows | Treatment |
|---|---:|---|
| Missing `CustomerID` | **135,080** | Retained and assigned to an unidentified-customer record; excluded from RFM analysis |
| Missing `Description` | **1,454** | Retained in the transaction history; canonical descriptions were derived from other records with the same stock code |
| Missing invoice number | **0** | No action required |
| Missing stock code | **0** | No action required |
| Missing country | **0** | No action required |

Missing customer identifiers do not prevent sales analysis, but customer-level and RFM results cover only identified customers.

---

## Format Validation

The following checks returned no invalid records:

- quantity values not convertible to integers;
- unit prices not convertible to decimal values;
- invoice dates not convertible to `DATETIME`;
- blank invoice numbers;
- blank stock codes;
- blank countries.

Passing these checks confirms that the values can be converted into analytical data types. It does not confirm that every transaction is commercially valid.

---

## Cancellations and Negative Quantities

| Finding | Rows |
|---|---:|
| Cancellation rows | **9,288** |
| Negative-quantity rows | **10,624** |
| Negative quantities on cancellation documents | **9,288** |
| Negative quantities without a cancellation number | **1,336** |

The **1,336** negative non-cancellation rows:

- belonged to **1,336 distinct invoices**;
- had no identified customer;
- had a unit price of zero;
- represented **−206,957 units**.

These records were classified as `Inventory Adjustment` rather than customer cancellations. They remain in the model for reconciliation but are excluded from merchandise-sales and cancellation KPIs.

A cancellation document reverses recorded invoice value, but the dataset does not confirm whether it represents a physical product return or the reason for the reversal.

---

## Zero-Price Transactions

The source contains **2,515** zero-price rows:

| Type | Rows | Treatment |
|---|---:|---|
| Negative inventory adjustments | **1,336** | Classified as `Inventory Adjustment` |
| Positive-quantity records | **1,179** | Retained and reported separately as zero-price units |

Positive zero-price records may represent samples, free products, corrections or other operational activity. They are retained because the dataset does not provide enough information to classify every case reliably.

They contribute to unit volume but not to merchandise sales value.

---

## Negative Unit Prices

Two rows contained a negative unit price. Both used stock code `B` and the description `Adjust bad debt`.

The complete sequence contained:

- one positive accounting entry of **£11,062.06**;
- two negative entries of **−£11,062.06** each.

These entries were classified as `Accounting Adjustment` and excluded from merchandise sales and product rankings. They remain in the full transaction model for reconciliation.

---

## Operational Entries

Not every stock code represents a physical product. The following categories were separated from merchandise:

| Category | Example codes |
|---|---|
| Shipping | `POST`, `DOT`, `C2` |
| Discount | `D` |
| Manual Adjustment | `M` |
| Bank Charge | `BANK CHARGES` |
| Platform Fee | `AMAZONFEE` |
| Commission | `CRUK` |
| Accounting Adjustment | `B` |
| Sample | `S` |
| Gift Voucher | Codes beginning with `GIFT_` |

These entries remain available for transaction reconciliation but are excluded from merchandise product rankings.

---

## Potential Duplicate Lines

Rows were compared across all source transaction attributes:

- invoice number;
- stock code;
- description;
- quantity;
- invoice timestamp;
- unit price;
- customer ID;
- country.

The audit identified:

| Metric | Result |
|---|---:|
| Duplicate groups | **4,879** |
| Rows within duplicate groups | **10,147** |
| Excess duplicate candidates | **5,268** |
| Potential excess net value | **£21,740.98** |

Identical lines cannot be proven to be errors because the source contains no unique invoice-line identifier. A product may have been recorded more than once on the same invoice.

For analytical consistency, the clean view assigns `duplicate_rank` using `ROW_NUMBER()` and marks:

- `duplicate_rank = 1` as the primary analytical record;
- `duplicate_rank > 1` as a duplicate candidate.

The source rows are not deleted, preserving traceability and allowing the assumption to be reviewed.

---

## Product Descriptions

A single stock code can appear with multiple descriptions, including administrative notes such as `website fixed` or `allocate stock for online orders`.

Canonical merchandise descriptions were selected using:

1. the most frequently used non-null description;
2. the most recently used description as a tie-breaker;
3. alphabetical order as the final deterministic tie-breaker.

Missing descriptions were not replaced with unrelated administrative notes. Stock codes without a reliable merchandise description received an explicit unknown-product label.

---

## Reconciliation

| Stage | Rows | Recorded value |
|---|---:|---:|
| Raw staging table | **541,909** | **£9,747,747.93** |
| Primary clean records | **536,641** | **£9,726,006.95** |
| Final fact table | **536,641** | **£9,726,006.95** |

The difference of **5,268 rows** and **£21,740.98** between the raw and clean stages corresponds to the records flagged as duplicate candidates.

The clean view and final fact table contain matching:

- row counts;
- distinct source-row identifiers;
- total recorded values;
- dimension keys and relationships.

The reconciled source value includes merchandise and operational entries. It is therefore not equivalent to Net Merchandise Sales.

---

## Reporting Coverage

The dataset contains only the first nine days of December 2011. This period is retained in the model but excluded from comparisons between complete months.

No Saturday invoices appear in:

- the raw staging data;
- the clean transaction view;
- the final fact table.

The absence was therefore not introduced during cleaning. Invoice timestamps may represent document processing rather than the precise moment of an online purchase, so hourly and weekday patterns should be interpreted cautiously.

---

## Final Analytical Scope

The final model distinguishes between:

- standard merchandise transactions;
- merchandise cancellations;
- zero-price merchandise;
- inventory adjustments;
- shipping, discounts, fees and accounting entries;
- identified and unidentified customers;
- domestic and international markets.

This separation allows merchandise performance to be analyzed without discarding the operational records required for full source reconciliation.
