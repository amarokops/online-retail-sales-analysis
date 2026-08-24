# Raw Data

The complete dataset is not stored in this repository.

Download the **Online Retail** dataset from the [UCI Machine Learning Repository](https://archive.ics.uci.edu/dataset/352/online%2Bretail) and place the source file in this directory as:

```text
Online Retail.xlsx
```

Before loading the data into MySQL, export the worksheet to:

```text
online_retail.csv
```

The expected source columns are:

```text
InvoiceNo
StockCode
Description
Quantity
InvoiceDate
UnitPrice
CustomerID
Country
```

The SQL loading process is documented in [`sql/01_database_setup/`](../../sql/01_database_setup/).
