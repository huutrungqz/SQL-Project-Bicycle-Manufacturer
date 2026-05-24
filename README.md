# Bicycle Manufacturer SQL Analysis Project

## Overview

This project explores the AdventureWorks2019 database using SQL in Google BigQuery to analyze sales performance, customer retention, inventory trends, purchasing activities, and product growth performance for a bicycle manufacturing business.

The analysis focuses on business-oriented KPIs including:
- Sales performance
- YoY growth trends
- Territory ranking
- Seasonal discount impact
- Customer retention
- Inventory analysis
- Stock efficiency
- Purchase order monitoring

---

# Business Objectives

The project aims to answer the following business questions:

- Which product subcategories generate the highest sales and order quantities?
- Which product categories have the strongest Year-over-Year growth?
- Which territories perform best in terms of order quantity?
- How much revenue is impacted by seasonal discounts?
- What is the customer retention trend over time?
- How does stock level fluctuate month-over-month?
- Which products have inefficient stock-to-sales ratios?
- How many purchase orders remain pending?

---

# Dataset

Database Used: ```AdventureWorks2019```

Datasets Used:
```text
Sales.SalesOrderDetail
Sales.SalesOrderHeader
Production.Product
Production.ProductSubcategory
Production.WorkOrder
Sales.SpecialOffer
Purchasing.PurchaseOrderHeader
```

---


# Tools Used

- Google BigQuery
- SQL
- Google Cloud Platform (GCP)

---

# SQL Skills Demonstrated

This project demonstrates the following SQL concepts:

- Common Table Expressions (CTEs)
- Aggregate Functions
- Window Functions
- Dense Rank
- Lag & Lead
- Date Functions
- Cohort Analysis
- JOIN operations
- Conditional Logic
- GROUP BY and ORDER BY

---

# Project Structure

```text
Bicycle-Manufacturer-SQL-Analysis/
│
├── SQL-Project-Bicycle-Manufacturer.sql
├── screenshots/
└── README.md
```

---

# Dataset Access

The dataset was accessed through Google BigQuery Studio on Google Cloud Platform (GCP).

I explored these steps to access the AdventureWorks2019 dataset:

## Method 1

1. Opened Google BigQuery Studio
2. Navigated to the Explorer panel
3. Selected `Add Data`
4. Imported or connected the AdventureWorks2019 database
5. Accessed the datasets:
   - `Sales`
   - `Production`
   - `Purchasing`
6. Queried tables such as:
   - `SalesOrderDetail`
   - `SalesOrderHeader`
   - `Product`
   - `WorkOrder`
   - `PurchaseOrderHeader`

![dataset access](screenshots/dataset_access.png)

---

## Method 2

1. Used the search bar inside the Explorer panel
2. Searched for tables such as:
   - `SalesOrderDetail`
   - `Product`
   - `PurchaseOrderHeader`
3. Opened the corresponding tables directly from the search results
4. Performed SQL analysis using BigQuery Editor

![table search](screenshots/table_search.png)

---

# Analysis Performed

## 1. Sales Performance by Product Subcategory

Calculate quantity sold, total sales value, and order quantity by product subcategory over the last 12 months.

### Query
```sql
-- Query 1: Calc Quantity of items, Sales value & Order quantity by each Subcategory in L12M

select
  format_date('%b %Y',sales.ModifiedDate) as period,
  productsub.name as name,
  sum(sales.OrderQty) as qty_item,
  sum(sales.LineTotal) as total_sales,
  count(sales.OrderQty) as order_cnt
from adventureworks2019.Sales.SalesOrderDetail as sales
left join adventureworks2019.Production.Product as product 
  on sales.ProductID = product.ProductID
left join adventureworks2019.Production.ProductSubcategory as productsub 
  on cast(product.ProductSubcategoryID as int) = productsub.ProductSubcategoryID
where date(sales.ModifiedDate) >= (
  select date_sub(date(max(sales.ModifiedDate)), interval 1 year)
  from adventureworks2019.Sales.SalesOrderDetail
)
group by 1,2
order by period desc, name;
```

### Result

![Query Result](screenshots/query1.png)

---

## 2. Year-over-Year Growth Analysis

Calculate YoY growth rate by subcategory and identify the top 3 categories with the highest growth rate.

### Query
```sql
-- Query 2: Calc % YoY growth rate by SubCategory & release top 3 cat with highest grow rate

with 
subsale as (
  select
    format_date('%Y',sales.ModifiedDate) as period,
    productsub.name as name,
    sum(sales.OrderQty) as qty_item
  from adventureworks2019.Sales.SalesOrderDetail as sales
  left join adventureworks2019.Production.Product as product
    on sales.ProductID = product.ProductID
  left join adventureworks2019.Production.ProductSubcategory as productsub
    on cast(product.ProductSubcategoryID as int) = productsub.ProductSubcategoryID
  group by 1,2
),

prv_quantity as (
  select
    period,
    name,
    qty_item,
    lag(qty_item) over (partition by name order by period) as prv_qty, 
    round(
      (qty_item / lag(qty_item) over (partition by name order by period)) -1,
      2
    ) as qty_diff
  from subsale
),

rank_quantity as (
  select
    name,
    qty_item,
    prv_qty,
    qty_diff,
    dense_rank() over (order by qty_diff desc) as rk
  from prv_quantity
)

select
  name,
  qty_item,
  prv_qty,
  qty_diff
from rank_quantity
where rk <= 3;
```

### Result

![Query Result](screenshots/query2.png)

---

## 3. Territory Performance Ranking

Rank top 3 territories with the highest order quantity each year.

### Query
```sql
-- Query 3: Ranking Top 3 TerritoryID with biggest Order quantity of every year

with 
sale_by_territory as (
  select
    format_date('%Y',sales_detail.ModifiedDate) as yr,
    sales_header.TerritoryID as TerritoryID,
    sum(sales_detail.OrderQty) as order_cnt
  from adventureworks2019.Sales.SalesOrderDetail as sales_detail
  left join adventureworks2019.Sales.SalesOrderHeader as sales_header
    using (SalesOrderID)
  group by 1,2
),

ranksale as (
  select
    yr,
    TerritoryID,
    order_cnt,
    dense_rank() over(partition by yr order by order_cnt desc) as rk
  from sale_by_territory
)

select
  yr,
  TerritoryID,
  order_cnt,
  rk
from ranksale
where rk <= 3
order by yr desc, rk;
```

### Result

![Query Result](screenshots/query3.png)

---

## 4. Seasonal Discount Analysis

Calculate total discount cost generated from seasonal discount campaigns for each subcategory.

### Query
```sql
-- Query 4: Calc Total Discount Cost belongs to Seasonal Discount for each SubCategory

select
  format_date('%Y',yr) as year,
  name,
  sum(disc_cost) as total_cost
from 
(
  select
    sales.ModifiedDate as yr,
    productsub.Name as name,
    sales.OrderQty * sales.UnitPriceDiscount * sales.UnitPrice as disc_cost
  from adventureworks2019.Sales.SalesOrderDetail as sales
  left join adventureworks2019.Production.Product as product
    on sales.ProductID = product.ProductID
  left join adventureworks2019.Production.ProductSubcategory as productsub
    on cast(product.ProductSubcategoryID as int) = productsub.ProductSubcategoryID
  left join adventureworks2019.Sales.SpecialOffer as discount
    on sales.SpecialOfferID = discount.SpecialOfferID
  where lower(discount.type) like '%seasonal discount%'
)
group by 1,2
order by 2,1;
```

### Result

![Query Result](screenshots/query4.png)

---

## 5. Customer Retention Analysis

Analyze customer retention rate in 2014 for successfully shipped orders.

### Query
```sql
-- Query 5: Retention rate of Customer in 2014 with status of Successfully Shipped

with 
successful_order as (
  select
    format_date('%m',sales_header.ModifiedDate) as month_join,
    sales_header.CustomerID as customer,
    count(distinct sales_header.SalesOrderID) as cnt
  from adventureworks2019.Sales.SalesOrderHeader as sales_header
  where extract(year from sales_header.ModifiedDate) = 2014
    and sales_header.Status = 5
  group by 1,2
),

count_order as(
  select
    month_join,
    customer,
    row_number() over (
      partition by customer
      order by month_join
    ) as rk
  from successful_order
),

first_order_month as (
  select 
    month_join,
    customer,
    rk
  from count_order
  where rk = 1
)

select
  b.month_join,
  concat(
    'M-',
    cast(a.month_join as int) - cast(b.month_join as int)
  ) as month_diff,
  count(distinct a.customer) as customer_cnt
from successful_order as a
left join first_order_month as b
  on a.customer = b.customer
group by 1,2
order by 1,2;
```

### Result

![Query Result](screenshots/query5.png)

---

## 6. Inventory Trend Analysis

Track stock levels and Month-over-Month inventory changes in 2011.

### Query
```sql
-- Query 6: Trend of Stock level & MoM diff % by all product in 2011

with 
stock as (
  select
    b.name,
    extract(month from a.ModifiedDate) as mth,
    extract(year from a.ModifiedDate) as yr,
    sum(a.StockedQty) as stock_qty
  from adventureworks2019.Production.WorkOrder as a
  left join adventureworks2019.Production.Product as b
    on a.ProductID = b.ProductID
  where extract(year from a.ModifiedDate) = 2011
  group by 1,2,3
),

compared_stock as (
  select
    name,
    mth,
    yr,
    stock_qty,
    lead(stock_qty) over (
      partition by name
      order by name,mth desc
    ) as stock_prv
  from stock
)

select
  name,
  mth,
  yr,
  stock_qty,
  stock_prv,
  round(
    coalesce((stock_qty / stock_prv - 1) * 100,0),
    1
  ) as diff
from compared_stock
order by 1,2 desc;
```

### Result

![Query Result](screenshots/query6.png)

---

## 7. Stock-to-Sales Ratio Analysis

Calculate stock-to-sales ratio by product and month to evaluate inventory efficiency.

### Query
```sql
-- Query 7: Calc Ratio of Stock / Sales in 2011 by product name, by month

with 
stock as (
  select
    a.ProductID,
    b.name,
    extract(month from a.ModifiedDate) as mth,
    extract(year from a.ModifiedDate) as yr,
    sum(a.StockedQty) as stock_qty
  from adventureworks2019.Production.WorkOrder as a
  left join adventureworks2019.Production.Product as b
    on a.ProductID = b.ProductID
  where extract(year from a.ModifiedDate) = 2011
  group by 1,2,3,4
),

sales as (
  select
    ProductID,
    extract(month from ModifiedDate) as mth,
    sum(OrderQty) as sale_qty
  from adventureworks2019.Sales.SalesOrderDetail
  where extract(year from ModifiedDate) = 2011
  group by 1,2
)

select
  stock.mth,
  stock.yr,
  stock.ProductID,
  stock.name,
  sale_qty as sales,
  stock_qty as stock,
  round(coalesce(stock_qty,0) / sale_qty,2) as ratio
from stock
left join sales 
  on stock.ProductID = sales.ProductID
  and stock.mth = sales.mth
order by 1 desc, ratio desc;
```

### Result

![Query Result](screenshots/query7.png)

---

## 8. Purchase Order Monitoring

Calculate number of purchase orders and purchasing value at pending status in 2014.

### Query
```sql
-- Query 8: No of order and value at Pending status in 2014

select 
  extract(year from ModifiedDate) as yr,
  Status,
  count(distinct PurchaseOrderID) as order_Cnt,
  sum(TotalDue) as value
from adventureworks2019.Purchasing.PurchaseOrderHeader
where Status = 1
  and extract(year from ModifiedDate) = 2014
group by 1,2;
```

### Result

![Query Result](screenshots/query8.png)

---

# Key Insights

- Certain product subcategories consistently generated higher sales volume.
- Some product categories achieved exceptionally high YoY growth.
- Territory performance varied significantly across years.
- Seasonal discounts created measurable impacts on profitability.
- Customer retention patterns revealed repeat purchasing behavior.
- Inventory trends highlighted fluctuations in stock management efficiency.
- Some products showed inefficient stock-to-sales ratios, indicating possible overstocking.
- Pending purchase orders helped identify procurement bottlenecks.

---

# Conclusion

This project demonstrates how SQL and Google BigQuery can be used to analyze large-scale manufacturing and sales data to generate business insights related to sales performance, customer retention, inventory optimization, and purchasing operations.

---
