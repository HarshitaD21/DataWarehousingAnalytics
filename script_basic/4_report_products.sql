create view report_products as
-- 1. Base Query: Retrieves core columns from tables of sales and products

WITH base_query AS (
    SELECT
        s.order_number,
        s.product_key,
        s.order_date,
        s.sales_amount,
        s.quantity,
        s.customer_key,
        p.product_name,
        p.category,
        p.subcategory,
        p.cost
    FROM sales s 
    LEFT JOIN products p
        ON s.product_key = p.product_key 
    WHERE s.order_date IS NOT NULL   -- only consider valid sales dates
),
product_aggregation AS (
    -- 2. Customer aggregations: summarizes key metrics at the customer level.   
    SELECT 
        product_key,
        product_name,
        category,
        subcategory,
        cost,
        DATE_PART('month', AGE(MAX(order_date), MIN(order_date))) AS lifespan,       -- datediff(month, min(order_date), max(order_date)) as lifespan,
        max(order_date) as last_sale_date,
        COUNT(DISTINCT order_number) AS total_orders,
        count(distinct customer_key) as total_customers,
        SUM(sales_amount) AS total_sales,  
        SUM(quantity) AS total_quantity,
        ROUND(AVG(sales_amount::NUMERIC / NULLIF(quantity, 0)), 1) AS avg_selling_price        -- round(avg(cast(sales_amount as float)/ nullif(quantity, 0)),1) as avg_selling_price
    FROM base_query
    GROUP BY product_key, product_name, category, subcategory, cost
)   

-- Final Query: combines all products results into one output
SELECT 
        product_key,
        product_name,
        category,
        subcategory,
        cost,
        last_sale_date,
        DATE_PART('month', AGE(CURRENT_DATE, COALESCE(last_sale_date, CURRENT_DATE))) AS recency_in_months,      -- datediff(month, last_sale_date, getdate()) as recency_in_months

    CASE 
        WHEN total_sales > 50000 THEN 'High-Performer'
        WHEN total_sales > 10000 THEN 'Mid-Range'
        ELSE 'Low-Performer'   
    END AS product_segment, 

    lifespan,
    total_orders,
    total_sales,
    total_quantity,
    total_customers,
    avg_selling_price,
  

-- compute avg order value (AOV)
CASE 
    WHEN total_orders = 0 THEN 0 
    ELSE total_sales / total_orders 
END AS avg_order_revenue,

-- compute avg monthly spend
CASE 
    WHEN lifespan = 0 THEN total_sales
    ELSE total_sales / lifespan
END AS avg_monthly_revenue

FROM product_aggregation;



select * from report_products



 


