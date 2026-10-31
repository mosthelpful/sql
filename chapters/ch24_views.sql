-- The Most Helpful SQL Guide, Second Edition
-- Chapter 24: Views
--
-- Every example in this chapter that runs on PostgreSQL,
-- in book order, with the result the book prints. Load
-- sample_db.sql first. To run the whole file in psql:
--   psql -d sqlguide -f chapters/ch24_views.sql
-- It runs as one transaction and rolls back at the end, so your
-- database is left unchanged. Examples that change data or fail on
-- purpose are wrapped in a savepoint and undone, as in the book.
-- You can also copy any single example into a query window.

BEGIN;

-- ------------------------------------------------------------
-- Example 1: Creating a View
-- ------------------------------------------------------------
CREATE VIEW employee_directory AS
SELECT employee_id, first_name, last_name,
       email, job_title, department_id
FROM employees;

-- Result: CREATE VIEW

-- ------------------------------------------------------------
-- Example 2: Creating a View
-- ------------------------------------------------------------
SELECT first_name, last_name, job_title
FROM employee_directory
WHERE department_id = 30
ORDER BY employee_id;

-- Result:
--  first_name | last_name |      job_title
-- ------------+-----------+---------------------
--  Emily      | Johnson   | Engineering Manager
--  Michael    | Williams  | Software Engineer
--  Sarah      | Chen      | Software Engineer
-- (3 rows)

-- ------------------------------------------------------------
-- Example 3: Views That Join Tables
-- ------------------------------------------------------------
CREATE VIEW order_summary AS
SELECT o.order_id, o.order_date, o.status,
       c.customer_id,
       c.first_name || ' ' || c.last_name
           AS customer_name,
       SUM(oi.quantity * oi.unit_price)
           AS order_total
FROM orders o
JOIN customers c
    ON c.customer_id = o.customer_id
JOIN order_items oi
    ON oi.order_id = o.order_id
GROUP BY o.order_id, o.order_date, o.status,
         c.customer_id, c.first_name,
         c.last_name;

-- Result: CREATE VIEW

-- ------------------------------------------------------------
-- Example 4: Views That Join Tables
-- ------------------------------------------------------------
SELECT order_id, customer_name, status,
       order_total
FROM order_summary
ORDER BY order_id;

-- Result:
--  order_id | customer_name |   status   | order_total
-- ----------+---------------+------------+-------------
--       101 | Alice Brown   | shipped    |     1221.98
--       102 | Bob Davis     | shipped    |      800.00
--       103 | Charlie Evans | cancelled  |      900.00
--       104 | Alice Brown   | shipped    |     1800.00
--       105 | Dana Kim      | processing |      292.96
--       106 | Charlie Evans | shipped    |     1100.00
-- (6 rows)

-- ------------------------------------------------------------
-- Example 5: Views That Join Tables
-- ------------------------------------------------------------
SELECT c.city,
       COUNT(*) AS order_count,
       SUM(os.order_total) AS total_spent
FROM order_summary os
JOIN customers c
    ON c.customer_id = os.customer_id
WHERE os.status <> 'cancelled'
GROUP BY c.city
ORDER BY total_spent DESC;

-- Result:
--    city   | order_count | total_spent
-- ----------+-------------+-------------
--  New York |           3 |     4121.98
--  Chicago  |           1 |      800.00
--  Austin   |           1 |      292.96
-- (3 rows)

-- ------------------------------------------------------------
-- Example 6: A View Stores a Query, Not Data
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

UPDATE order_items
SET unit_price = 199.00
WHERE order_id = 105
    AND product_id = 6;

SELECT order_id, order_total
FROM order_summary
WHERE order_id = 105;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  order_id | order_total
-- ----------+-------------
--       105 |      242.96
-- (1 row)

-- ------------------------------------------------------------
-- Example 7: Changing and Dropping a View
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW employee_directory AS
SELECT employee_id, first_name, last_name,
       email, job_title, department_id,
       manager_id
FROM employees;

-- Result: CREATE VIEW

-- ------------------------------------------------------------
-- Example 8: Changing and Dropping a View
-- Fails on purpose, to show the error.
-- ------------------------------------------------------------
SAVEPOINT example;

CREATE OR REPLACE VIEW employee_directory AS
SELECT employee_id, first_name, last_name,
       job_title, department_id, manager_id
FROM employees;

ROLLBACK TO SAVEPOINT example;

-- Expected error:
--   ERROR:  cannot drop columns from view

-- ------------------------------------------------------------
-- Example 9: Dependencies
-- Fails on purpose, to show the error.
-- ------------------------------------------------------------
SAVEPOINT example;

ALTER TABLE employees DROP COLUMN job_title;

ROLLBACK TO SAVEPOINT example;

-- Expected error:
--   ERROR:  cannot drop column job_title of table employees because other objects depend on it
--   DETAIL:  view employee_directory depends on column job_title of table employees
--   HINT:  Use DROP ... CASCADE to drop the dependent objects too.

-- ------------------------------------------------------------
-- Example 10: Updating Data Through a View
-- ------------------------------------------------------------
CREATE VIEW electronic_products AS
SELECT product_id, product_name, category,
       price, stock
FROM products
WHERE category = 'Electronics';

-- Result: CREATE VIEW

-- ------------------------------------------------------------
-- Example 11: Updating Data Through a View
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

UPDATE electronic_products
SET category = 'Furniture'
WHERE product_id = 4;

SELECT product_id, product_name
FROM electronic_products
ORDER BY product_id;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  product_id | product_name
-- ------------+--------------
--           1 | Laptop
--           2 | Smartphone
--           3 | Tablet
-- (3 rows)

-- ------------------------------------------------------------
-- Example 12: WITH CHECK OPTION
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW electronic_products AS
SELECT product_id, product_name, category,
       price, stock
FROM products
WHERE category = 'Electronics'
WITH CHECK OPTION;

-- Result: CREATE VIEW

-- ------------------------------------------------------------
-- Example 13: WITH CHECK OPTION
-- Fails on purpose, to show the error.
-- ------------------------------------------------------------
SAVEPOINT example;

UPDATE electronic_products
SET category = 'Furniture'
WHERE product_id = 4;

ROLLBACK TO SAVEPOINT example;

-- Expected error:
--   ERROR:  new row violates check option for view "electronic_products"
--   DETAIL:  Failing row contains (4, Monitor, Furniture, 300.00, 30).

-- ------------------------------------------------------------
-- Example 14: Materialized Views
-- ------------------------------------------------------------
CREATE MATERIALIZED VIEW product_sales AS
SELECT p.product_id, p.product_name,
       SUM(oi.quantity) AS units_sold,
       SUM(oi.quantity * oi.unit_price)
           AS revenue
FROM products p
JOIN order_items oi
    ON oi.product_id = p.product_id
JOIN orders o
    ON o.order_id = oi.order_id
WHERE o.status <> 'cancelled'
GROUP BY p.product_id, p.product_name;

SELECT product_name, units_sold, revenue
FROM product_sales
ORDER BY product_id;

-- Result:
--  product_name | units_sold | revenue
-- --------------+------------+---------
--  Laptop       |          2 | 2400.00
--  Smartphone   |          2 | 1600.00
--  Monitor      |          3 |  900.00
--  Coffee Mug   |          6 |   65.94
--  Desk Chair   |          1 |  249.00
-- (5 rows)

-- ------------------------------------------------------------
-- Example 15: Materialized Views
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

UPDATE order_items
SET unit_price = 199.00
WHERE order_id = 105
    AND product_id = 6;

SELECT product_name, revenue
FROM product_sales
WHERE product_id = 6;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  product_name | revenue
-- --------------+---------
--  Desk Chair   |  249.00
-- (1 row)

-- ------------------------------------------------------------
-- Example 16: Materialized Views
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

UPDATE order_items
SET unit_price = 199.00
WHERE order_id = 105
    AND product_id = 6;

REFRESH MATERIALIZED VIEW product_sales;

SELECT product_name, revenue
FROM product_sales
WHERE product_id = 6;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  product_name | revenue
-- --------------+---------
--  Desk Chair   |  199.00
-- (1 row)

-- ------------------------------------------------------------
-- Example 17: Materialized Views
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

CREATE UNIQUE INDEX uq_product_sales_product
    ON product_sales (product_id);

REFRESH MATERIALIZED VIEW CONCURRENTLY
    product_sales;

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Example 18: Views and Performance
-- ------------------------------------------------------------
EXPLAIN (COSTS OFF)
SELECT first_name, job_title
FROM employee_directory
WHERE last_name = 'Chen';

-- Plan:
--   Seq Scan on employees
--     Filter: ((last_name)::text = 'Chen'::text)

-- ------------------------------------------------------------
-- Try It 1
-- Create a view named active_customers with the ID, name and city of
-- each active customer. Use it to list the ones in New York.
-- ------------------------------------------------------------
-- 1. A view of active customers
CREATE VIEW active_customers AS
SELECT customer_id, first_name, last_name, city
FROM customers
WHERE status = 'active';

SELECT first_name, last_name
FROM active_customers
WHERE city = 'New York'
ORDER BY customer_id;

-- Result:
--  first_name | last_name
-- ------------+-----------
--  Alice      | Brown
--  Charlie    | Evans
-- (2 rows)

-- ------------------------------------------------------------
-- Try It 2
-- Using order_summary, show how many orders each customer has placed
-- and their total value, leaving out cancelled orders.
-- ------------------------------------------------------------
-- 2. Orders and spending per customer
SELECT customer_name,
       COUNT(*) AS order_count,
       SUM(order_total) AS total_spent
FROM order_summary
WHERE status <> 'cancelled'
GROUP BY customer_id, customer_name
ORDER BY total_spent DESC;

-- Result:
--  customer_name | order_count | total_spent
-- ---------------+-------------+-------------
--  Alice Brown   |           2 |     3021.98
--  Charlie Evans |           1 |     1100.00
--  Bob Davis     |           1 |      800.00
--  Dana Kim      |           1 |      292.96
-- (4 rows)

-- ------------------------------------------------------------
-- Try It 3
-- In a transaction you roll back (Chapter 25), change Tom Wilson's
-- job title to Senior Data Analyst through employee_directory. Then
-- check the employees table.
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 3. An update through a view
UPDATE employee_directory
SET job_title = 'Senior Data Analyst'
WHERE employee_id = 8;

SELECT first_name, last_name, job_title,
       salary
FROM employees
WHERE employee_id = 8;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  first_name | last_name |      job_title      |  salary
-- ------------+-----------+---------------------+----------
--  Tom        | Wilson    | Senior Data Analyst | 71000.00
-- (1 row)

-- ------------------------------------------------------------
-- Example 19: Try It
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

DROP VIEW employee_directory, order_summary,
    electronic_products, active_customers;
DROP MATERIALIZED VIEW product_sales;

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Undo everything this file changed.
-- ------------------------------------------------------------
ROLLBACK;
