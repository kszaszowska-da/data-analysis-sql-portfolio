/*
    dashboard_views.sql

    Ten plik zawiera definicje widoków SQL dla dashboardu KPI i analiz sprzedaży, obejmujące:
    - Kluczowe wskaźniki wydajności (KPI) dla roku 2024 (sprzedaż, liczba zamówień i klientów, średnia wartość zamówienia, porównanie wzrostu sprzedaży rok do roku)
    - Sprzedaż wg kategorii produktów w 2024 roku
    - Sprzedaż miesięczna w latach 2023 i 2024
    - Sprzedaż wg regionów w 2024 roku
    - Liczbę zamówień wg metody płatności w 2024 roku

    Widoki służą do prezentacji danych na dashboardzie wykonanym w Power BI, w bezpośrednim połączeniu z bazą danych.
*/

-- Dashboard KPI.
CREATE OR REPLACE VIEW _dashboard_kpi AS
SELECT
    -- Suma sprzedaży w 2024 roku
    SUM(order_details.quantity_ordered * order_details.unit_price)
    FILTER (WHERE EXTRACT(YEAR FROM orders.order_date) = 2024) AS total_sales_2024,

    -- Liczba unikalnych zamówień w 2024 roku
    COUNT(DISTINCT orders.order_id)
    FILTER (WHERE EXTRACT(YEAR FROM orders.order_date) = 2024) AS orders_2024,

    -- Liczba unikalnych klientów w 2024 roku
    COUNT(DISTINCT orders.customer_id)
    FILTER (WHERE EXTRACT(YEAR FROM orders.order_date) = 2024) AS customers_2024,

    -- Średnia wartość zamówienia w 2024 roku (średnia kwota 1 zamówienia)
    (SELECT ROUND(AVG(order_total), 2)
     FROM (SELECT orders.order_id, SUM(order_details.quantity_ordered * order_details.unit_price) AS order_total
           FROM orders
                    JOIN order_details ON orders.order_id = order_details.order_id
           WHERE EXTRACT(YEAR FROM orders.order_date) = 2024
           GROUP BY orders.order_id) AS order_totals)          AS avg_order_value_2024,

    -- Wzrost sprzedaży rok do roku (YoY Growth %)
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

-- Dashboard sprzedaż wg kategorii (2024).
CREATE OR REPLACE VIEW _dashboard_sales_by_category_2024 AS
SELECT products.category,
       SUM(order_details.quantity_ordered * order_details.unit_price) AS total_sales
FROM order_details
         JOIN products ON order_details.product_id = products.product_id
         JOIN orders ON order_details.order_id = orders.order_id
WHERE EXTRACT(YEAR FROM orders.order_date) = 2024
GROUP BY products.category;

-- Dashboard sprzedaż miesięczna (2023 vs 2024).
CREATE OR REPLACE VIEW _dashboard_sales_over_time AS
SELECT DATE_TRUNC('month', orders.order_date)                         AS month,
       EXTRACT(YEAR FROM orders.order_date)                           AS year,
       SUM(order_details.quantity_ordered * order_details.unit_price) AS total_sales
FROM order_details
         JOIN orders ON order_details.order_id = orders.order_id
WHERE EXTRACT(YEAR FROM orders.order_date) IN (2023, 2024)
GROUP BY DATE_TRUNC('month', orders.order_date), EXTRACT(YEAR FROM orders.order_date)
ORDER BY month;

-- Dashboard sprzedaż wg regionów (2024).
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

-- Dashboard liczba zamówień wg metody płatności (2024).
CREATE OR REPLACE VIEW _dashboard_payment_methods_2024 AS
SELECT DATE_TRUNC('month', orders.order_date) AS month,
       orders.payment_method,
       COUNT(*)                               AS order_count
FROM orders
WHERE EXTRACT(YEAR FROM orders.order_date) = 2024
GROUP BY DATE_TRUNC('month', orders.order_date), orders.payment_method
ORDER BY month, orders.payment_method;