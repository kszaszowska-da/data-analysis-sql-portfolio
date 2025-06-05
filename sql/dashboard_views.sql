/*
    dashboard_views.sql

    This file contains SQL view definitions for the KPI dashboard and sales analysis, including:
    - Key Performance Indicators (KPIs) for the year 2024 (sales, number of orders and customers, average order value, year-over-year sales growth)
    - Sales by product category in 2024
    - Monthly sales in 2023 and 2024
    - Sales by regions in 2024
    - Number of orders by payment method in 2024

    These views are used to present data in a Power BI dashboard with a direct connection to the database.
*/

-- Dashboard KPI.
CREATE OR REPLACE VIEW _dashboard_kpi AS
SELECT
    -- Total sales in 2024
    SUM(order_details.quantity_ordered * order_details.unit_price)
    FILTER (WHERE EXTRACT(YEAR FROM orders.order_date) = 2024) AS total_sales_2024,

    -- Number of unique orders in 2024
    COUNT(DISTINCT orders.order_id)
    FILTER (WHERE EXTRACT(YEAR FROM orders.order_date) = 2024) AS orders_2024,

    -- Number of unique customers in 2024
    COUNT(DISTINCT orders.customer_id)
    FILTER (WHERE EXTRACT(YEAR FROM orders.order_date) = 2024) AS customers_2024,

    -- Average order value in 2024 (average amount per order)
    (SELECT ROUND(AVG(order_total), 2)
     FROM (SELECT orders.order_id, SUM(order_details.quantity_ordered * order_details.unit_price) AS order_total
           FROM orders
                    JOIN order_details ON orders.order_id = order_details.order_id
           WHERE EXTRACT(YEAR FROM orders.order_date) = 2024
           GROUP BY orders.order_id) AS order_totals)          AS avg_order_value_2024,

    -- Year-over-year sales growth (YoY Growth %)
    ROUND(
            (
                        SUM(order_details.quantity_ordered * order_details.unit_price)
                        FILTER (WHERE EXTRACT(YEAR FROM orders.order_date) = 2024)
                    -
                        SUM(order_details.quantity_ordered * order_details.unit_price)
                        FILTER (WHERE EXTRACT(YEAR FROM orders.order_date) = 2023)
                )
                /
            NULLIF(SUM(order_details.quantity_ordered * order_details.unit_price)
                   FILTER (WHERE EXTRACT(YEAR FROM orders.order_date) = 2023), 0)
                * 100, 2
    )                                                          AS yoy_growth

FROM orders
         JOIN order_details ON orders.order_id = order_details.order_id;

-- Dashboard: sales by category (2024).
CREATE OR REPLACE VIEW _dashboard_sales_by_category_2024 AS
SELECT products.category,
       SUM(order_details.quantity_ordered * order_details.unit_price) AS total_sales
FROM order_details
         JOIN products ON order_details.product_id = products.product_id
         JOIN orders ON order_details.order_id = orders.order_id
WHERE EXTRACT(YEAR FROM orders.order_date) = 2024
GROUP BY products.category;

-- Dashboard: monthly sales (2023 vs 2024).
CREATE OR REPLACE VIEW _dashboard_sales_over_time AS
SELECT DATE_TRUNC('month', orders.order_date)                         AS month,
       EXTRACT(YEAR FROM orders.order_date)                           AS year,
       SUM(order_details.quantity_ordered * order_details.unit_price) AS total_sales
FROM order_details
         JOIN orders ON order_details.order_id = orders.order_id
WHERE EXTRACT(YEAR FROM orders.order_date) IN (2023, 2024)
GROUP BY DATE_TRUNC('month', orders.order_date), EXTRACT(YEAR FROM orders.order_date)
ORDER BY month;

-- Dashboard: sales by regions (2024).
CREATE OR REPLACE VIEW _dashboard_sales_by_region_2024 AS
SELECT customers.region_id,
       regions.region_name,
       SUM(order_details.quantity_ordered * order_details.unit_price) AS total_sales_by_region
FROM order_details
         JOIN orders ON order_details.order_id = orders.order_id
         JOIN customers ON orders.customer_id = customers.customer_id
         JOIN regions ON customers.region_id = regions.region_id
WHERE EXTRACT(YEAR FROM orders.order_date) = 2024
GROUP BY customers.region_id, regions.region_name;

-- Dashboard: number of orders by payment method (2024).
CREATE OR REPLACE VIEW _dashboard_payment_methods_2024 AS
SELECT DATE_TRUNC('month', orders.order_date) AS month,
       orders.payment_method,
       COUNT(*)                               AS order_count
FROM orders
WHERE EXTRACT(YEAR FROM orders.order_date) = 2024
GROUP BY DATE_TRUNC('month', orders.order_date), orders.payment_method
ORDER BY month, orders.payment_method;
