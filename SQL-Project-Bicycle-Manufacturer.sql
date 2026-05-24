-- Query 1: Calc Quantity of items, Sales value & Order quantity by each Subcategory in L12M
select
  format_date('%b %Y',sales.ModifiedDate) as period,
  productsub.name as name,
  sum(sales.OrderQty) as qty_item,
  sum(sales.LineTotal) as total_sales,
  count(sales.OrderQty) as order_cnt
from adventureworks2019.Sales.SalesOrderDetail as sales
left join adventureworks2019.Production.Product as product on sales.ProductID = product.ProductID
left join adventureworks2019.Production.ProductSubcategory as productsub on cast(product.ProductSubcategoryID as int) = productsub.ProductSubcategoryID
where date(sales.ModifiedDate) >= (select date_sub(date(max(sales.ModifiedDate)),interval 1 year) 
                                  from adventureworks2019.Sales.SalesOrderDetail)
group by 1,2
order by period desc, name;

-- Query 2: "Calc % YoY growth rate by SubCategory & release top 3 cat with highest grow rate. Can use metric: quantity_item. Round results to 2 decimal
-- qty_diff = qty_item / prv_qty - 1"

--ket qua khac voi de bai
with 
subsale as (
  select
      format_date('%Y',sales.ModifiedDate) as period,
      productsub.name as name,
      sum(sales.OrderQty) as qty_item,
    from adventureworks2019.Sales.SalesOrderDetail as sales
    left join adventureworks2019.Production.Product as product on sales.ProductID = product.ProductID
    left join adventureworks2019.Production.ProductSubcategory as productsub on cast(product.ProductSubcategoryID as int) = productsub.ProductSubcategoryID
    group by 1,2
    order by 2, 1),

prv_quantity as (
select
  period,
  name,
  qty_item,
  lag(qty_item) over (partition by name order by period) as prv_qty, 
  round((qty_item / lag(qty_item) over (partition by name order by period)) -1,2) as qty_diff
from subsale
  dense_rank
order by qty_diff desc),

rank_quantity as (
select
  name,
  qty_item,
  prv_qty,
  qty_diff,
  dense_rank() over (order by qty_diff desc) as rk
from prv_quantity)

select
  name,
  qty_item,
  prv_qty,
  qty_diff
from rank_quantity
where rk <= 3;

-- Query 3: Ranking Top 3 TeritoryID with biggest Order quantity of every year. If there's TerritoryID with same quantity in a year, do not skip the rank number

with 
sale_by_territory as (
  select
    format_date('%Y',sales_detail.ModifiedDate) as yr,
    sales_header.TerritoryID as TerritoryID,
    sum(sales_detail.OrderQty) as order_cnt,
  from adventureworks2019.Sales.SalesOrderDetail as sales_detail
  left join adventureworks2019.Sales.SalesOrderHeader as sales_header using (SalesOrderID)
  group by 1,2),

ranksale as (
  select
    yr,
    TerritoryID,
    order_cnt,
    dense_rank() over(partition by yr order by order_cnt desc) as rk
  from sale_by_territory)

select
  yr,
  TerritoryID,
  order_cnt,
  rk
from ranksale
where rk <=3
order by yr desc, rk;

-- query 4: Calc Total Discount Cost belongs to Seasonal Discount for each SubCategory
select
  format_date('%Y',yr) as year,
  name,
  sum(disc_cost) as total_cost
from 
  (select
    sales.ModifiedDate as yr,
    productsub.Name as name,
    sales.OrderQty * sales.UnitPriceDiscount * sales.UnitPrice as disc_cost
  from
  adventureworks2019.Sales.SalesOrderDetail as sales
  left join adventureworks2019.Production.Product as product on sales.ProductID = product.ProductID
  left join adventureworks2019.Production.ProductSubcategory as productsub on cast(product.ProductSubcategoryID as int) = productsub.ProductSubcategoryID
  left join adventureworks2019.Sales.SpecialOffer as discount on sales.SpecialOfferID = discount.SpecialOfferID
  where lower(discount.type) like '%seasonal discount%')
group by 1,2
order by 2,1;

-- query 5: Retention rate of Customer in 2014 with status of Successfully Shipped (Cohort Analysis)
with 
successful_order as (
  select
    format_date('%m',sales_header.ModifiedDate) as month_join,
    sales_header.CustomerID as customer,
    count(distinct sales_header.SalesOrderID) as cnt,
  from adventureworks2019.Sales.SalesOrderHeader as sales_header
  where 1=1
    and extract(year from sales_header.ModifiedDate) = 2014
    and sales_header.Status = 5
  group by 1,2
),
count_order as(
  select
    month_join,
    customer,
    row_number() over (partition by customer order by month_join) as rk
  from successful_order
),
first_order_month as (
  select 
    month_join,
    customer,
    rk
  from count_order
  where rk=1
)

select
  b.month_join,
  concat('M-',cast(a.month_join as int) - cast(b.month_join as int)) as month_diff,
  count(distinct a.customer) as customer_cnt
from successful_order as a
left join first_order_month as b on a.customer = b.customer
group by 1,2
order by 1,2;

-- Query 6: Trend of Stock level & MoM diff % by all product in 2011. If %gr rate is null then 0. Round to 1 decimal

with 
stock as (
  select
    b.name,
    extract(month from a.ModifiedDate) as mth,
    extract(year from a.ModifiedDate) as yr,
    sum(a.StockedQty) as stock_qty
  from adventureworks2019.Production.WorkOrder as a
  left join adventureworks2019.Production.Product as b on a.ProductID = b.ProductID
  where 1=1
    and extract(year from a.ModifiedDate) = 2011
  group by 1, 2,3),

compared_stock as (
  select
    name,
    mth,
    yr,
    stock_qty,
    lead(stock_qty) over (partition by name order by name,mth desc) as stock_prv
  from stock)

select
  name,
  mth,
  yr,
  stock_qty,
  stock_prv,
  round(coalesce((stock_qty/stock_prv - 1)*100,0),1) as diff
from compared_stock
order by 1, 2 desc;


-- Query 7: "Calc Ratio of Stock / Sales in 2011 by product name, by month
-- Order results by month desc, ratio desc. Round Ratio to 1 decimal
-- mom yoy"

with 
stock as (
  select
    a.ProductID,
    b.name,
    extract(month from a.ModifiedDate) as mth,
    extract(year from a.ModifiedDate) as yr,
    sum(a.StockedQty) as stock_qty
  from adventureworks2019.Production.WorkOrder as a
  left join adventureworks2019.Production.Product as b on a.ProductID = b.ProductID
  where extract(year from a.ModifiedDate) = 2011
  group by 1, 2,3,4
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

-- query 8 No of order and value at Pending status in 2014
select 
  extract (year from ModifiedDate) as yr,
  Status,
  count(distinct PurchaseOrderID) as order_Cnt,
  sum(TotalDue) as value
from adventureworks2019.Purchasing.PurchaseOrderHeader
where Status = 1
  and extract(year from ModifiedDate) = 2014
group by 1,2;