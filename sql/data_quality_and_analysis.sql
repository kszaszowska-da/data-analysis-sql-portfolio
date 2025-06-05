/*
    data_quality_and_analysis.sql

    This file contains a set of SQL queries related to:
    - Data quality analysis (e.g., detecting errors, missing values, duplicates)
    - Cleaning and validating customer data
    - Creating views and helper tables for further analysis
    - Verifying data correctness (e.g., email and phone formats)
    - Analyzing orders and customers (e.g., activity, statuses)
    - Basic statistics such as average order value

    Each query is accompanied by a comment explaining its purpose.

    The file should be executed in full and in the given order to maintain consistency and result accuracy.
*/

-- 1. Counting records with errors in specific columns.
SELECT COUNT(*) FILTER (WHERE first_name IS NULL OR
                              first_name IN ('', '-1', '0', 'unknown', 'none', 'NULL', 'N/A', '---')) AS bad_first_name,
       COUNT(*) FILTER (WHERE last_name IS NULL OR last_name IN ('', '-1', '0', 'unknown', 'none', 'NULL', 'N/A',
                                                                 '---'))                              AS bad_last_name,
       COUNT(*) FILTER (WHERE email IS NULL OR email IN ('', '-1', '0', 'unknown', 'none', 'NULL', 'N/A',
                                                         '---'))                                      AS bad_email,
       COUNT(*) FILTER (WHERE phone IS NULL OR phone IN ('', '-1', '0', 'unknown', 'none', 'NULL', 'N/A',
                                                         '---'))                                      AS bad_phone,
       COUNT(*) FILTER (WHERE city IS NULL OR city IN ('', '-1', '0', 'unknown', 'none', 'NULL', 'N/A',
                                                       '---'))                                        AS bad_city,
       COUNT(*) FILTER (WHERE postal_code IS NULL OR postal_code IN ('', '-1', '0', 'unknown', 'none', 'NULL', 'N/A',
                                                                     '---'))                          AS bad_postal_code,
       COUNT(*) FILTER (WHERE address IS NULL OR address IN ('', '-1', '0', 'unknown', 'none', 'NULL', 'N/A',
                                                             '---'))                                  AS bad_address,
       COUNT(*) FILTER (WHERE customer_type IS NULL OR customer_type IN
                                                       ('', '-1', '0', 'unknown', 'none', 'NULL', 'N/A',
                                                        '---'))                                       AS bad_customer_type
FROM customers;

-- 2. Searching for records containing whitespace and incorrect data; if an error is found, it is replaced with NULL for easier selection later.
CREATE OR REPLACE VIEW cleaned_customers_step1 AS
SELECT customer_id,
       CASE
           WHEN first_name IS NULL OR TRIM(first_name) IN ('', '-1', '0', 'unknown', 'none', 'N/A', '---') THEN NULL
           ELSE TRIM(first_name)
           END AS first_name,

       CASE
           WHEN last_name IS NULL OR TRIM(last_name) IN ('', '-1', '0', 'unknown', 'none', 'N/A', '---') THEN NULL
           ELSE TRIM(last_name)
           END AS last_name,

       CASE
           WHEN email IS NULL OR TRIM(email) IN ('', '-1', '0', 'unknown', 'none', 'N/A', '---') THEN NULL
           ELSE TRIM(email)
           END AS email,

       CASE
           WHEN phone IS NULL OR TRIM(phone) IN ('', '-1', '0', 'unknown', 'none', 'N/A', '---') THEN NULL
           ELSE TRIM(phone)
           END AS phone,

       CASE
           WHEN city IS NULL OR TRIM(city) IN ('', '-1', '0', 'unknown', 'none', 'N/A', '---') THEN NULL
           ELSE TRIM(city)
           END AS city,

       CASE
           WHEN postal_code IS NULL OR TRIM(postal_code) IN ('', '-1', '0', 'unknown', 'none', 'N/A', '---') THEN NULL
           ELSE TRIM(postal_code)
           END AS postal_code,

       CASE
           WHEN address IS NULL OR TRIM(address) IN ('', '-1', '0', 'unknown', 'none', 'N/A', '---') THEN NULL
           ELSE TRIM(address)
           END AS address,

       CASE
           WHEN customer_type IS NULL OR TRIM(customer_type) IN ('', '-1', '0', 'unknown', 'none', 'N/A', '---')
               THEN NULL
           ELSE TRIM(customer_type)
           END AS customer_type,

       region_id
FROM customers;

-- 3. Query for finding duplicate customers with identical data: first name, last name, email, phone, city, postal code, and address.
SELECT first_name,
       last_name,
       email,
       phone,
       city,
       postal_code,
       address,
       COUNT(*) AS duplicate_count
FROM customers
GROUP BY first_name, last_name, email, phone, city, postal_code, address
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

-- 4. Query displaying records with duplicate emails and phone numbers.
SELECT *
FROM cleaned_customers_step1
WHERE email IN (SELECT email
                FROM cleaned_customers_step1
                WHERE email IS NOT NULL
                GROUP BY email
                HAVING COUNT(*) > 1)
   OR phone IN (SELECT phone
                FROM cleaned_customers_step1
                WHERE phone IS NOT NULL
                GROUP BY phone
                HAVING COUNT(*) > 1);

-- 5. Query creating a view with duplicate emails and phone numbers, without removing them, for possible later analysis.
CREATE OR REPLACE VIEW duplicated_emails_phones AS
SELECT *
FROM cleaned_customers_step1
WHERE email IN (SELECT email
                FROM cleaned_customers_step1
                WHERE email IS NOT NULL
                GROUP BY email
                HAVING COUNT(*) > 1)
   OR phone IN (SELECT phone
                FROM cleaned_customers_step1
                WHERE phone IS NOT NULL
                GROUP BY phone
                HAVING COUNT(*) > 1);

-- 6. Query checking for digits in text fields or letters in numeric fields.
SELECT *
FROM cleaned_customers_step1
WHERE first_name ~ '[0-9]'
   OR last_name ~ '[0-9]'
   OR city ~ '[0-9]'
   OR customer_type ~ '[0-9]'
   OR phone ~ '[^0-9+ ]'
   OR postal_code ~ '[^0-9-]';

-- 7. Query validating email, phone number and postal code.
SELECT *
FROM cleaned_customers_step1
WHERE phone !~ '^[0-9 +()-]+$'
   OR LENGTH(REGEXP_REPLACE(phone, '[^0-9]', '', 'g')) NOT BETWEEN 7 AND 15
   OR email !~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
   OR postal_code !~ '^[0-9]{2}-[0-9]{3}$';

-- 8. Query changing the first letters of names and surnames to uppercase.
SELECT DISTINCT first_name, last_name
FROM cleaned_customers_step1
WHERE first_name IS NOT NULL AND
      (LEFT(first_name, 1) <> UPPER(LEFT(first_name, 1))
          OR SUBSTRING(first_name FROM 2) <> LOWER(SUBSTRING(first_name FROM 2)))
   OR last_name IS NOT NULL AND
      (LEFT(last_name, 1) <> UPPER(LEFT(last_name, 1))
          OR SUBSTRING(last_name FROM 2) <> LOWER(SUBSTRING(last_name FROM 2)));

-- 9. Query creating a view with NULLs in place of invalid phone formats.
CREATE OR REPLACE VIEW cleaned_customers_step2 AS
SELECT customer_id,
       first_name,
       last_name,

       CASE
           WHEN email !~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN NULL
           ELSE email
           END AS email,

       CASE
           WHEN phone !~ '^[0-9 +()-]+$'
               OR LENGTH(REGEXP_REPLACE(phone, '[^0-9]', '', 'g')) NOT BETWEEN 7 AND 15
               THEN NULL
           ELSE phone
           END AS phone,

       city,

       CASE
           WHEN postal_code !~ '^[0-9]{2}-[0-9]{3}$' THEN NULL
           ELSE postal_code
           END AS postal_code,

       address,
       customer_type,
       region_id
FROM cleaned_customers_step1;

-- 10. Checking if text fields exceed reasonable length limits.
SELECT *
FROM cleaned_customers_step2
WHERE LENGTH(first_name) > 30
   OR LENGTH(last_name) > 30
   OR LENGTH(email) > 100
   OR LENGTH(phone) > 30
   OR LENGTH(city) > 30
   OR LENGTH(postal_code) > 10
   OR LENGTH(address) > 100;

-- 11. Customers with suspiciously short first or last names.
SELECT *
FROM cleaned_customers_step2
WHERE LENGTH(first_name) < 2
   OR LENGTH(last_name) < 2;

-- 12. Query checking for orders with non-existent products.
SELECT *
FROM order_details
WHERE product_id NOT IN (SELECT product_id FROM products);

-- 13. Query checking for customers without a valid region_id.
SELECT *
FROM cleaned_customers_step2
WHERE region_id IS NOT NULL
  AND region_id NOT IN (SELECT region_id FROM regions);

-- 14. Query checking for repeated IDs for the same customer.
SELECT *
FROM cleaned_customers_step2
WHERE customer_id IN (SELECT customer_id
                      FROM cleaned_customers_step2
                      GROUP BY customer_id
                      HAVING COUNT(DISTINCT first_name) > 1
                          OR COUNT(DISTINCT last_name) > 1
                          OR COUNT(DISTINCT email) > 1
                          OR COUNT(DISTINCT phone) > 1);

-- 15. Query checking for duplicate IDs for the same order.
SELECT *
FROM orders
WHERE order_id IN (SELECT order_id
                   FROM orders
                   GROUP BY order_id
                   HAVING COUNT(DISTINCT customer_id) > 1
                       OR COUNT(DISTINCT order_date) > 1
                       OR COUNT(DISTINCT order_time) > 1
                       OR COUNT(DISTINCT payment_method) > 1)
ORDER BY order_id;

-- 16. Customers who didn’t place any orders (registration without purchases, abandoned cart, etc.)
SELECT *
FROM cleaned_customers_step2 AS customers
WHERE NOT EXISTS (SELECT 1
                  FROM orders
                  WHERE orders.customer_id = customers.customer_id);

-- 17. Adding a status column for active and inactive customers to the view `cleaned_customers_step2` and creating a new view.
CREATE OR REPLACE VIEW cleaned_customers_step3 AS
SELECT cleaned_customers_step2.*,
       CASE
           WHEN cleaned_customers_step2.customer_id IN (SELECT customer_id
                                                        FROM orders)
               THEN 'active'
           ELSE 'potential'
           END AS status
FROM cleaned_customers_step2;

-- 18. Creating a table with potential customers, i.e. those who are in the database but didn’t place any order.
CREATE TABLE potential_customers AS
SELECT *
FROM cleaned_customers_step3
WHERE status = 'potential';

-- 19. Creating a view with active customers.
CREATE VIEW active_customers AS
SELECT *
FROM cleaned_customers_step3
WHERE status = 'active';

-- 20. Checking for orders without a linked customer.
SELECT *
FROM orders
WHERE customer_id IS NULL;

-- 21. Checking for orders with an invalid date (in the future).
SELECT *
FROM orders
WHERE order_date > CURRENT_DATE;

-- 22. Products without a price or with a price ≤ 0.
SELECT *
FROM products
WHERE price IS NULL
   OR price <= 0;

-- 23. Checking if there are products without an assigned category.
SELECT *
FROM products
WHERE category IS NULL
   OR category = '';

-- 24. Checking if there are products without a name.
SELECT *
FROM products
WHERE product_name IS NULL
   OR TRIM(product_name) = '';

-- 25. Products that have never been ordered.
SELECT *
FROM products
WHERE product_id NOT IN (SELECT DISTINCT product_id FROM orders);

-- 26. Customers with more than 10 orders.
SELECT cleaned_customers_step3.customer_id,
       COUNT(*) AS order_count
FROM cleaned_customers_step3
         JOIN orders ON cleaned_customers_step3.customer_id = orders.customer_id
GROUP BY cleaned_customers_step3.customer_id
HAVING COUNT(*) > 10;

-- 27. Calculating the percentage of records with NULLs.
SELECT COUNT(*) AS total_rows,
       COUNT(*) FILTER (
           WHERE
           customer_id IS NULL
               OR first_name IS NULL
               OR last_name IS NULL
               OR email IS NULL
               OR phone IS NULL
               OR city IS NULL
               OR postal_code IS NULL
               OR address IS NULL
               OR customer_type IS NULL
               OR region_id IS NULL
           )    AS rows_with_nulls,
       ROUND(
               100.0 * COUNT(*) FILTER (
                   WHERE
                   customer_id IS NULL
                       OR first_name IS NULL
                       OR last_name IS NULL
                       OR email IS NULL
                       OR phone IS NULL
                       OR city IS NULL
                       OR postal_code IS NULL
                       OR address IS NULL
                       OR customer_type IS NULL
                       OR region_id IS NULL
                   )::NUMERIC / COUNT(*), 2
       )        AS percent_with_nulls
FROM cleaned_customers_step3;

-- 28. View showing only records with NULL values.
CREATE OR REPLACE VIEW customers_with_nulls AS
SELECT *
FROM cleaned_customers_step3
WHERE customer_id IS NULL
   OR first_name IS NULL
   OR last_name IS NULL
   OR email IS NULL
   OR phone IS NULL
   OR city IS NULL
   OR postal_code IS NULL
   OR address IS NULL
   OR customer_type IS NULL
   OR region_id IS NULL;

-- 29. Creating a helper table with order values.
CREATE TABLE order_totals AS
SELECT orders.order_id,
       orders.customer_id,
       SUM(order_details.quantity_ordered * order_details.unit_price) AS total_amount
FROM orders
         JOIN order_details ON orders.order_id = order_details.order_id
GROUP BY orders.order_id, orders.customer_id;

-- 30. What is the average order value.
SELECT AVG(total_amount) AS average_order_value
FROM order_totals;

-- 31. Function to calculate the average order value (without providing a time range).
CREATE OR REPLACE FUNCTION average_order_value()
    RETURNS NUMERIC AS
$$
SELECT AVG(total_amount)
FROM (SELECT orders.order_id,
             SUM(order_details.quantity_ordered * order_details.unit_price) AS total_amount
      FROM orders
               JOIN order_details ON orders.order_id = order_details.order_id
      GROUP BY orders.order_id) AS order_totals;
$$ LANGUAGE sql;

-- 32. Calling the function.
SELECT average_order_value();
