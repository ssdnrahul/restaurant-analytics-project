USE restaurant_analytics;

SELECT 'stores' AS table_name, COUNT(*) AS total_records
FROM stores
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'customers', COUNT(*) FROM customers
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL
SELECT 'inventory_daily', COUNT(*) FROM inventory_daily
UNION ALL
SELECT 'customer_feedback', COUNT(*) FROM customer_feedback
UNION ALL
SELECT 'complaints', COUNT(*) FROM complaints;

/* calculate the total number of orders for each order status (Completed, Cancelled, Refunded). 
Sort the results in descending order of total orders*/

SELECT order_status,
COUNT(*) AS total_orders
FROM orders
GROUP BY order_status
ORDER BY total_orders DESC;

/* calculate the total number of orders for each sales channel (Dine-in, Swiggy, Zomato, Takeaway). 
Sort the results in descending order of total orders. */

SELECT
    sales_channel,
    COUNT(*) AS total_orders
FROM orders
GROUP BY sales_channel
ORDER BY total_orders DESC;

-- Identify orders containing store_id or customer_id values that do not exist in their respective master tables.
SELECT o.order_id, o.store_id
FROM orders o
LEFT JOIN stores s
ON o.store_id = s.store_id
WHERE s.store_id IS NULL;

SELECT o.order_id, o.customer_id
FROM orders o
LEFT JOIN customers c
ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

-- Identify records in order_items that contain invalid order_id or product_id values

SELECT oi.order_id
FROM order_items oi
LEFT JOIN orders o
ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;

SELECT oi.product_id
FROM order_items oi
LEFT JOIN products p
ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;

-- REVENUE ANALYSIS

-- Calculate the restaurant chain's total revenue and completed orders for 2025.

SELECT ROUND(SUM(net_sales),2) AS total_revenue, COUNT(order_id) AS total_orders,
ROUND(AVG(net_sales),2) AS average_order_value
FROM orders
WHERE order_status = 'Completed';

-- Calculate total monthly net revenue from Completed orders for 2025. Display month-wise revenue in chronological order.

SELECT DATE_FORMAT(order_date, '%Y-%m') AS month,
ROUND(SUM(net_sales),2) AS total_revenue
FROM orders
WHERE order_status = 'Completed'
GROUP BY month
ORDER BY month;

-- Identify months with the highest revenue growth and the largest revenue decline.

WITH ninjas AS(
SELECT DATE_FORMAT(order_date, '%Y-%m') AS month,
ROUND(SUM(net_sales),2) AS total_revenue
FROM orders
WHERE order_status = 'Completed'
GROUP BY month
ORDER BY month)

SELECT month, 
total_revenue, LAG(total_revenue) OVER (ORDER BY month) AS previous_month_revenue,
ROUND((total_revenue - LAG(total_revenue) OVER (ORDER BY month))/LAG(total_revenue) OVER (ORDER BY month)*100,2) AS pct_change
FROM ninjas;


-- Identify which months have higher cancellations and refunds.

SELECT DATE_FORMAT(order_date, '%Y-%m') AS month,
SUM(CASE WHEN order_status = 'Completed' then 1 ELSE 0 END) AS completed_orders,
SUM(CASE WHEN order_status = 'Cancelled' then 1 ELSE 0 END) AS cancelled_orders,
SUM(CASE WHEN order_status = 'Refunded' then 1 ELSE 0 END) AS refunded_orders
FROM orders
GROUP BY month
ORDER BY month;

-- Identify which months have the highest and lowest average customer spending per order.

SELECT DATE_FORMAT(order_date, '%Y-%m') AS month,
ROUND(AVG(net_sales),2) AS average_order_value
FROM orders
WHERE order_status = 'Completed'
GROUP BY month
ORDER BY month;


-- Identify the top and bottom months based on total net sales from Completed orders in 2025.

SELECT DATE_FORMAT(order_date, '%Y-%m') AS month,
ROUND(SUM(net_sales),2) AS total_revenue
FROM orders
WHERE order_status = 'Completed'
GROUP BY month
ORDER BY total_revenue DESC;

-- Calculate the performance of each restaurant store based on completed orders, total revenue and Average Order Value (AOV).

SELECT store_id, COUNT(order_id) AS total_orders, ROUND(SUM(net_sales),2) AS total_revenue,
ROUND(AVG(net_sales),2) AS average_order_value
FROM orders
WHERE order_status = 'Completed'
GROUP BY store_id
ORDER BY total_revenue DESC;

-- Identify which regions generate the highest revenue and compare their order volume and Average Order Value.

WITH ninjas AS(
SELECT s.region, COUNT(o.order_id) AS total_orders,
ROUND(SUM(o.net_sales),2) AS total_revenue, 
ROUND(AVG(o.net_sales),2) AS average_order_value
FROM orders o 
JOIN stores s 
ON o.store_id = s.store_id
WHERE o.order_status = 'Completed'
GROUP BY s.region)
SELECT region, total_orders, average_order_value, total_revenue,
ROUND((total_revenue)/SUM(total_revenue) OVER ()*100,2) AS pct_contribution
FROM ninjas;


-- Identify the top 3 revenue-generating stores within each region.

WITH ninjas AS(
SELECT s.region, o.store_id, ROUND(SUM(o.net_sales),2) AS total_revenue,
DENSE_RANK() OVER (PARTITION BY s.region ORDER BY ROUND(SUM(o.net_sales),2) DESC) AS ranking
FROM orders o 
JOIN stores s 
ON o.store_id = s.store_id
WHERE o.order_status='Completed'
GROUP BY s.region, o.store_id)
SELECT region, store_id, total_revenue, ranking
FROM ninjas
WHERE ranking <=3;

-- PRODUCT PERFORMANCE ANALYSIS

SELECT ot.product_id, p.product_name, SUM(ot.quantity) AS total_quantity_sold,
ROUND(SUM(ot.net_sales),2) AS total_revenue
FROM orders o 
JOIN order_items ot
ON o.order_id = ot.order_id
JOIN products p
ON ot.product_id = p.product_id
WHERE o.order_status = 'Completed'
GROUP BY ot.product_id, p.product_name
ORDER BY total_revenue DESC
LIMIT 10;

-- Identify the bottom 10 products based on revenue.

SELECT ot.product_id, p.product_name, SUM(ot.quantity) AS total_quantity_sold,
ROUND(SUM(ot.net_sales),2) AS total_revenue
FROM orders o 
JOIN order_items ot
ON o.order_id = ot.order_id
JOIN products p
ON ot.product_id = p.product_id
WHERE o.order_status = 'Completed'
GROUP BY ot.product_id, p.product_name
ORDER BY total_revenue
LIMIT 10;

-- Identify which product category generates the highest revenue.

WITH category_sales AS (
    SELECT
        p.category,
        SUM(ot.quantity) AS total_quantity_sold,
        ROUND(SUM(ot.net_sales), 2) AS total_revenue,
        ROUND(
            SUM(ot.net_sales) / SUM(ot.quantity),
            2
        ) AS average_selling_price
    FROM orders o
    JOIN order_items ot
        ON o.order_id = ot.order_id
    JOIN products p
        ON ot.product_id = p.product_id
    WHERE o.order_status = 'Completed'
    GROUP BY p.category
)

SELECT
    category,
    total_quantity_sold,
    total_revenue,
    average_selling_price,
    ROUND(
        total_revenue / SUM(total_revenue) OVER () * 100,
        2
    ) AS revenue_contribution_pct
FROM category_sales
ORDER BY total_revenue DESC;

-- Analyse monthly revenue generated by each product category.

SELECT DATE_FORMAT(o.order_date,'%Y-%m') AS month,
p.category, SUM(ot.quantity) AS total_quantity_sold,
ROUND(SUM(ot.net_sales),2) AS total_revenue
FROM orders o
JOIN order_items ot 
ON o.order_id = ot.order_id 
JOIN products p
ON ot.product_id = p.product_id
WHERE o.order_status = 'Completed'
GROUP BY month, p.category
ORDER BY month, total_revenue DESC;

-- Calculate month-over-month revenue growth percentage for each product category.

WITH ninjas AS(
SELECT DATE_FORMAT(o.order_date,'%Y-%m') AS month,
p.category, ROUND(SUM(ot.net_sales),2) AS current_month_revenue
FROM orders o
JOIN order_items ot 
ON o.order_id = ot.order_id 
JOIN products p
ON ot.product_id = p.product_id
WHERE o.order_status = 'Completed'
GROUP BY month, p.category)
SELECT month, category, current_month_revenue,
LAG(current_month_revenue) OVER (PARTITION BY category ORDER BY month) AS previous_month_revenue,
ROUND((current_month_revenue- LAG(current_month_revenue) OVER (PARTITION BY category ORDER BY month))/
LAG(current_month_revenue) OVER (PARTITION BY category ORDER BY month)*100,2) AS mom_growth_pct
FROM ninjas
ORDER BY category, month;

-- Identify how each store's revenue changes month over month.

WITH ninjas AS(
SELECT store_id, DATE_FORMAT(order_date,'%Y-%m') AS month,
ROUND(SUM(net_sales),2) AS current_month_revenue
FROM orders
WHERE order_status='Completed'
GROUP BY store_id, month)
SELECT store_id, month, current_month_revenue,
LAG(current_month_revenue) OVER (PARTITION BY store_id ORDER BY month) AS previous_month_revenue,
ROUND((current_month_revenue-LAG(current_month_revenue) OVER (PARTITION BY store_id ORDER BY month))/
LAG(current_month_revenue) OVER (PARTITION BY store_id ORDER BY month)*100,2) AS mom_pct
FROM ninjas;

-- CUSTOMER ANALYSIS

-- Find customers who placed more than one completed order in 2025.

SELECT customer_id, COUNT(*) AS total_orders,
ROUND(SUM(net_sales),2) AS total_revenue
FROM orders
WHERE order_status = 'Completed'
GROUP BY customer_id
HAVING COUNT(*)>1;

-- Find the top 10 customers by total revenue.

SELECT o.customer_id, c.customer_name, COUNT(o.order_id) AS total_orders,
ROUND(SUM(o.net_sales),2) AS total_revenue,
ROUND(AVG(o.net_sales),2) AS avg_order_value
FROM orders o
JOIN customers c 
ON o.customer_id = c.customer_id
WHERE order_status = 'Completed'
GROUP BY o.customer_id, c.customer_name
ORDER BY total_revenue DESC
LIMIT 10;

/* Segment customers based on their total spending in 2025.

Categories:
- High Value: Revenue >= ₹5,000
- Medium Value: Revenue between ₹2,000 and ₹4,999.99
- Low Value: Revenue below ₹2,000 */

WITH ninjas AS(
SELECT customer_id, COUNT(*) AS total_orders,
ROUND(SUM(net_sales),2) AS total_revenue
FROM orders
WHERE order_status = 'Completed'
GROUP BY customer_id)

SELECT customer_id, total_orders,
total_revenue, 
CASE
WHEN total_revenue >= 5000 THEN 'High Value'
WHEN total_revenue < 2000 THEN 'Low Value'
ELSE 'Medium Value'
END AS Customer_segment
FROM ninjas;

/* Analyse how frequently customers place completed orders.

Task:
- Customer ID
- Total completed orders
- Customer frequency category:
  - 1 order: One-time Customer
  - 2–3 orders: Occasional Customer
  - 4 or more orders: Frequent Customer
  */
  
  WITH ninjas AS(
  SELECT customer_id, COUNT(*) AS total_orders
  FROM orders
  WHERE order_status = 'Completed'
  GROUP BY customer_id)
  SELECT customer_id, total_orders,
  CASE
  WHEN total_orders = 1 THEN "One-time Customer"
  WHEN total_orders >= 4 THEN "Frequent Customer"
  ELSE "Occasional Customer"
  END AS loyality
  FROM ninjas;
  
  
  -- Identify customers who made purchases in multiple months during 2025.
  
  SELECT
    customer_id,
    COUNT(DISTINCT DATE_FORMAT(order_date, '%Y-%m')) AS total_purchase_months,
    COUNT(order_id) AS total_orders,
    ROUND(SUM(net_sales), 2) AS total_revenue
FROM orders
WHERE order_status = 'Completed'
GROUP BY customer_id
HAVING COUNT(DISTINCT DATE_FORMAT(order_date, '%Y-%m')) >= 2
ORDER BY total_purchase_months DESC, total_revenue DESC;

-- Identify which sales channel generates the highest revenue.

WITH channel_sales AS (
    SELECT
        sales_channel,
        COUNT(order_id) AS total_orders,
        ROUND(SUM(net_sales), 2) AS total_revenue,
        ROUND(AVG(net_sales), 2) AS average_order_value
    FROM orders
    WHERE order_status = 'Completed'
    GROUP BY sales_channel
)

SELECT
    sales_channel,
    total_orders,
    total_revenue,
    average_order_value,
    ROUND(
        total_revenue / SUM(total_revenue) OVER () * 100,
        2
    ) AS revenue_contribution_pct
FROM channel_sales
ORDER BY total_revenue DESC;

-- Analyse monthly revenue performance of each sales channel.

WITH monthly_channel_sales AS (
    SELECT
        DATE_FORMAT(order_date, '%Y-%m') AS month,
        sales_channel,
        COUNT(order_id) AS total_orders,
        ROUND(SUM(net_sales), 2) AS total_revenue
    FROM orders
    WHERE order_status = 'Completed'
    GROUP BY
        month,
        sales_channel
),
channel_trends AS (
    SELECT
        month,
        sales_channel,
        total_orders,
        total_revenue,
        LAG(total_revenue) OVER (
            PARTITION BY sales_channel
            ORDER BY month
        ) AS previous_month_revenue
    FROM monthly_channel_sales
)
SELECT
    month,
    sales_channel,
    total_orders,
    total_revenue,
    previous_month_revenue,
    ROUND(
        (total_revenue - previous_month_revenue)
        / previous_month_revenue * 100,
        2
    ) AS mom_growth_pct
FROM channel_trends
ORDER BY sales_channel, month;

-- Identify the top 10 products with the highest average stock variance across all stores during 2025.

SELECT i.product_id, p.product_name, SUM(i.variance_qty) AS total_stock_variance,
AVG(i.variance_qty) AS average_stock_variance,
COUNT(i.inventory_record_id) AS total_records
FROM inventory_daily i
JOIN products p
ON i.product_id = p.product_id
GROUP BY i.product_id, p.product_name
ORDER BY average_stock_variance DESC
LIMIT 10;

-- Find the top 10 stores with the highest negative stock variance during 2025.

SELECT
    store_id,
    SUM(variance_qty) AS total_stock_variance,
    ROUND(AVG(variance_qty), 2) AS average_stock_variance,
    COUNT(*) AS total_records
FROM inventory_daily
GROUP BY store_id
ORDER BY total_stock_variance ASC
LIMIT 10;

-- Identify which product categories have the highest stock discrepancies across all stores during 2025.

SELECT
    p.category,
    SUM(i.variance_qty) AS total_stock_variance,
    ROUND(AVG(i.variance_qty), 2) AS average_stock_variance,
    COUNT(*) AS total_records
FROM inventory_daily i
JOIN products p
    ON i.product_id = p.product_id
GROUP BY p.category
ORDER BY total_stock_variance ASC;

-- Find the top 10 stores with the highest number of customer complaints during 2025.


SELECT store_id, COUNT(*) AS total_complaints,
SUM(refund_amount) AS total_refund_amount,
AVG(refund_amount) AS avg_refund_amount
FROM complaints
GROUP BY store_id
ORDER BY total_complaints DESC
LIMIT 10;

-- Find the complaint categories with the highest number of complaints.

SELECT
    complaint_category,
    COUNT(*) AS total_complaints,
    ROUND(SUM(refund_amount), 2) AS total_refund_amount,
    ROUND(AVG(refund_amount), 2) AS average_refund_amount
FROM complaints
GROUP BY complaint_category
ORDER BY total_complaints DESC;

-- Management wants to understand how customer complaints and refund amounts changed month by month during 2025.

SELECT
    DATE_FORMAT(
        STR_TO_DATE(complaint_date, '%d-%m-%Y'),
        '%Y-%m'
    ) AS month,
COUNT(*) AS total_complaints,
ROUND(SUM(refund_amount), 2) AS total_refund_amount,
ROUND(AVG(refund_amount), 2) AS average_refund_amount
FROM complaints
GROUP BY month
ORDER BY month;

-- Identify the top 10 stores with the highest average customer ratings.

SELECT
    store_id,
    COUNT(*) AS total_feedback,
    ROUND(AVG(overall_rating), 2) AS average_rating,
    SUM(CASE WHEN overall_rating IN (4, 5) THEN 1 ELSE 0 END) AS positive_ratings
FROM customer_feedback
GROUP BY store_id
ORDER BY average_rating DESC
LIMIT 10;


-- Management wants to identify stores that need improvement in customer satisfaction.
  
  SELECT
    s.store_id,
    s.store_name,
    s.region, COUNT(cf.feedback_id) AS total_feedback,
	ROUND(AVG(cf.overall_rating), 2) AS average_rating,

    SUM(CASE WHEN cf.overall_rating IN (4, 5) THEN 1 ELSE 0 END
    ) AS positive_ratings,
    SUM(CASE WHEN cf.overall_rating IN (1, 2) THEN 1 ELSE 0 END
    ) AS negative_ratings, 
    ROUND(SUM(CASE WHEN cf.overall_rating IN (4, 5) THEN 1 ELSE 0 END)
        / COUNT(cf.feedback_id) * 100,
        2
    ) AS positive_rating_pct
FROM customer_feedback cf
JOIN stores s
ON cf.store_id = s.store_id
GROUP BY
    s.store_id,
    s.store_name,
    s.region
ORDER BY average_rating ASC
LIMIT 10;

