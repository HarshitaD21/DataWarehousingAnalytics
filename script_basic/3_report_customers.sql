create view report_customers as
-- 1. Base Query: Retrieves core columns from tables

WITH base_query AS (
    SELECT
        s.order_number,
        s.product_key,
        s.order_date,
        s.sales_amount,
        s.quantity,
        c.customer_key,
        c.customer_number,
        c.first_name || ' ' || c.last_name AS customer_name,
        EXTRACT(YEAR FROM AGE(c.birthdate)) AS age
    FROM sales s 
    LEFT JOIN customers c
        ON c.customer_key = s.customer_key  
    WHERE s.order_date IS NOT NULL
),
customer_aggregation AS (
    -- 2. Customer aggregations: summarizes key metrics at the customer level.   
    SELECT 
        customer_key,
        customer_number,
        customer_name,
        age,
        COUNT(DISTINCT order_number) AS total_orders,
        SUM(sales_amount) AS total_sales,  
        SUM(quantity) AS total_quantity,
        COUNT(DISTINCT product_key) AS total_products,
        MAX(order_date)::date AS last_order_date,
        -- Ensuring positive lifespan using ABS()
        ABS(
            (EXTRACT(YEAR FROM AGE(MIN(order_date), MAX(order_date))) * 12) 
            + EXTRACT(MONTH FROM AGE(MIN(order_date), MAX(order_date)))
        ) AS lifespan
    FROM base_query
    GROUP BY customer_key, customer_number, customer_name, age
)
SELECT 
    customer_key,
    customer_number,
    customer_name,
    age,
    CASE 
        WHEN age < 20 THEN 'Under 20'
        WHEN age BETWEEN 20 AND 29 THEN '20-29'
        WHEN age BETWEEN 30 AND 39 THEN '30-39'
        WHEN age BETWEEN 40 AND 49 THEN '40-49'
        ELSE '50 and above'   
    END AS age_group, 
    CASE 
        WHEN lifespan >= 12 AND total_sales > 5000 THEN 'VIP'  
        WHEN lifespan >= 12 AND total_sales <= 5000 THEN 'Regular'  
        ELSE 'New'
    END AS customer_segment,
    last_order_date,
    -- Corrected recency calculation in PostgreSQL
    (EXTRACT(YEAR FROM AGE(CURRENT_DATE, last_order_date)) * 12) 
    + EXTRACT(MONTH FROM AGE(CURRENT_DATE, last_order_date)) AS recency,    
    total_orders,
    total_sales,
    total_quantity,
    total_products,
    lifespan, 


-- compute avg order value (AOV)
CASE 
    WHEN total_sales = 0 THEN 0 
    ELSE total_sales / total_orders 
END AS avg_order_value,

-- compute avg monthly spend
CASE 
    WHEN lifespan = 0 THEN total_sales
    ELSE total_sales / lifespan
END AS avg_monthly_spend

FROM customer_aggregation;


-- example if someone wants to visualize the view created aboe.
select 
age_group,  -- customer_segment
count(customer_number) as total_customers,
sum(total_sales) total_sales
from report_customers
group by age_group


DROP VIEW IF EXISTS report_customers;

select * from report_customers;



