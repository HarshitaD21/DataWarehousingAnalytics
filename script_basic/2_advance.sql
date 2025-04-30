
/*Advance Analytics
1. Change-over-time - trends
2. Cumulative Analysis
3. Performance Analysis
4. Part-to-whole - proportional
5. Data Segmentation
6. Reporting 
*/

/*
* Change over time analysis - analyze how a measure evolves over time.
Helps track trends and identify seasonality in your data
formula: aggregate[measure] by [date dimension]
eg: total sales by year, avg cost by month
*/


--Analyze the sales performance over time 
select 
order_date,
sum(sales_amount) total_sales
from sales
where order_date is not null
group by order_date
order by order_date
-- for each day we have the sales, the granuality of the data is by day.

select 
year(order_date) as order_year,   -- year is only in sql and there is different func for postgres
sum(sales_amount) total_sales,
count(distinct customer_key) as total_customers
sum(quantity) as total_quantity
from sales
where order_date is not null
group by year(order_date)
order by year(order_date)
-- year level analysis
-- very nice pic to understand is the revenue increasing or decreasing over time, what is the best and worst year
-- are we gaining any customers over time, are there any trends that we can spot?   
-- Changes over time. A high level overview insight that helps with strategic decision making.
-- you can do this month wise too. trends and patterns

select 
date_trunc('year',order_date)::date as order_date,  
sum(sales_amount) total_sales,
count(distinct customer_key) as total_customers,
sum(quantity) as total_quantity
from sales
where order_date is not null
group by date_trunc('year',order_date)
order by date_trunc('year',order_date)

select 
format(order_date,'yyyy-MMM') as order_date,   -- this in sql
sum(sales_amount) total_sales,
count(distinct customer_key) as total_customers,
sum(quantity) as total_quantity
from sales
where order_date is not null
group by format(order_date,'yyyy-MMM')
order by format(order_date,'yyyy-MMM')


SELECT 
    TO_CHAR(order_date, 'YYYY-Mon') AS order_month,  -- Corrected format function
    SUM(sales_amount) AS total_sales,
    COUNT(DISTINCT customer_key) AS total_customers,  -- postgres way of writing the above query
    SUM(quantity) AS total_quantity     -- using date_trunc is a better approach instead of this. you can have both year and month displayed seperately.
FROM sale
WHERE order_date IS NOT NULL
GROUP BY TO_CHAR(order_date, 'YYYY-Mon')
ORDER BY TO_CHAR(order_date, 'YYYY-Mon');


--2. Cumulative Analysis:
--  Aggregates the data progressively over time. Helps to understand whether our business is growing or declining. 
-- fromaula -aggregation [cumulative measure] by [date dimension]
-- eg: running total sales by year, moving average of sales by month

-- query: Calculate the total sales per month and running total of sales over time, along with moving average
select
order_date,     --- this same question can be done for year as well which is more commonly asked. just chnage the month to year keyword
total_sales,
sum(total_sales) over(partition by order_date order by order_date) as running_total_sales
avg(avg_price) over(order by order_date) as moving_avg_sales
-- window function 
from(
    select 
date_trunc('month',order_date)::date as order_date,
sum(sales_amount) as total_sales
avg(price) as avg_price
from sales
where order_date is not null
group by date_trunc('month',order_date)
)t


-- Perfromance Analysis:
-- comparing the current value to a target value
-- helps measure  success and compare performance
-- formula: current[measure] - target[measure]
-- eg: current sales - avg sales, current year sales - previous year sales, current sales - lowest/highest sales


-- query: Aanlyze the yearly performance of products by comparing each product's sales to both its avg sales performance and the previous year's sales. 
with yearly_product_sales as (
    SELECT 
    EXTRACT(YEAR FROM s.order_date) AS order_year,  -- Extracts year from date
    p.product_name,
    SUM(s.sales_amount) AS current_sales
FROM sales s 
LEFT JOIN products p 
ON s.product_key = p.product_key
WHERE s.order_date IS NOT NULL 
GROUP BY EXTRACT(YEAR FROM s.order_date), p.product_name
)
select 
order_year,
product_name,
current_sales,
avg(current_sales) over(partition by product_name) as avg_sales,
current_sales - avg(current_sales) over(partition by product_name)::integer as diff_avg,
case when current_sales - avg(current_sales) over(partition by product_name) > 0 then 'Above Avg'
     when current_sales - avg(current_sales) over(partition by product_name) < 0 then 'Below Avg'
else 'Avg'
end avg_change,
lag(current_sales) over(partition by product_name order by order_year) as pre_year_sales,
current_sales - lag(current_sales) over(partition by product_name order by order_year) as diff_pre_year,
case when current_sales - lag(current_sales) over(partition by product_name order by order_year) > 0 then 'Increase'
     when current_sales - lag(current_sales) over(partition by product_name order by order_year) < 0 then 'Decrease'
else 'No change'
end py_change
from yearly_product_sales
order by product_name, order_year
-- this type of analysis is called y-o-y year-over-year analysis


-- Part to whole Analysis:
-- Aanalyze how an indivisual part is performing compared to the overall,
-- allowing us to understand whihc category has the gretest impact on the business. 
-- formula: ([measure]/total[measure]) * 100 by [dimension]
-- eg: (sales/total sales) * 100 by category,
-- (quantity/ total quantity) * 100 by country

-- query: Which categories contribute the most to overall sales
with category_sales as (
    select
p.category,
sum(s.sales_amount) total_sales
from sales s
left join products p 
on p.product_key = s.product_key 
group by p.category)

select
category,
total_sales,
sum(total_sales) over() overall_sales,
round((total_sales/ sum(total_sales) over()) * 100, 2) as percentage_of_total
from category_sales
order by total_sales desc


-- Data Segmentation
-- Group the d ata based on a specific range.
-- Helps understand the correlation between two measures.
-- formula: [measure] by [measure] : here we have to convert one measure into a range or group and then aggregate the data by this measure
-- eg: total products by sales range, total customers by age 


-- query: segment products into cost ranges and count how many products fall into each segment
with product_segments as (
    select
product_key,
product_name,
cost,
case when cost < 100  then 'Below 100'
    when cost between 100 and 500 then '100-500'
    when cost between 500 and 1000 then '500-1000'
    else 'Above 1000'
end cost_range
from products)

select 
cost_range,
count(product_key) as total_products
from product_segments
group by cost_range
order by total_products desc


-- q: Group customers into 3 segments based on their spending behavior:
-- VIP : at least 12 months of history and spending more than $5000
-- Regular: at least 12 months of history but spending $5000 or less
-- New: lifespan less than 12 months
-- and find the total number of customers by each group 
WITH customer_spending AS (
    SELECT
        c.customer_key,
        SUM(s.sales_amount) AS total_spending,
        MIN(s.order_date) AS first_order,
        MAX(s.order_date) AS last_order,
        DATE_PART('year', AGE(MAX(s.order_date), MIN(s.order_date))) * 12 
        + DATE_PART('month', AGE(MAX(s.order_date), MIN(s.order_date))) AS lifespan_months
    FROM sales s
    LEFT JOIN customers c ON s.customer_key = c.customer_key 
    GROUP BY c.customer_key
)

select
customer_segment,
count(customer_key) as total_cust
from(
SELECT
    customer_key,
    CASE 
        WHEN lifespan_months >= 12 AND total_spending > 5000 THEN 'VIP'
        WHEN lifespan_months >= 12 AND total_spending <= 5000 THEN 'Regular'
        ELSE 'New'
    END AS customer_segment
FROM customer_spending) t
group by customer_segment
order by total_cust desc


