-- The Most Helpful SQL Guide, Second Edition
-- Chapter 12: Aggregates
--
-- Every example in this chapter that runs on PostgreSQL,
-- in book order, with the result the book prints. Load
-- sample_db.sql first. To run the whole file in psql:
--   psql -d sqlguide -f chapters/ch12_aggregates.sql
-- It runs as one transaction and rolls back at the end, so your
-- database is left unchanged. Examples that change data or fail on
-- purpose are wrapped in a savepoint and undone, as in the book.
-- You can also copy any single example into a query window.

BEGIN;

-- ------------------------------------------------------------
-- Example 1: Counting Rows with COUNT
-- ------------------------------------------------------------
SELECT COUNT(*) AS all_rows,
       COUNT(department_id) AS with_department,
       COUNT(DISTINCT department_id)
           AS departments
FROM employees;

-- Result:
--  all_rows | with_department | departments
-- ----------+-----------------+-------------
--         8 |               7 |           4
-- (1 row)

-- ------------------------------------------------------------
-- Example 2: Counting Rows with COUNT
-- ------------------------------------------------------------
SELECT COUNT(*) AS all_rows,
       COUNT(city) AS with_city,
       COUNT(DISTINCT city) AS cities
FROM customers;

-- Result:
--  all_rows | with_city | cities
-- ----------+-----------+--------
--         5 |         4 |      3
-- (1 row)

-- ------------------------------------------------------------
-- Example 3: SUM, AVG, MIN and MAX
-- ------------------------------------------------------------
SELECT SUM(quantity * unit_price) AS revenue,
       MIN(unit_price) AS lowest_price,
       MAX(unit_price) AS highest_price
FROM order_items;

-- Result:
--  revenue | lowest_price | highest_price
-- ---------+--------------+---------------
--  6114.94 |        10.99 |       1200.00
-- (1 row)

-- ------------------------------------------------------------
-- Example 4: SUM, AVG, MIN and MAX
-- ------------------------------------------------------------
SELECT AVG(salary) AS avg_salary,
       ROUND(AVG(salary), 2) AS rounded,
       MIN(hire_date) AS first_hire,
       MAX(hire_date) AS latest_hire
FROM employees;

-- Result:
--      avg_salary     | rounded  | first_hire | latest_hire
-- --------------------+----------+------------+-------------
--  90375.000000000000 | 90375.00 | 2015-06-15 | 2024-01-08
-- (1 row)

-- ------------------------------------------------------------
-- Example 5: Averages of integers
-- ------------------------------------------------------------
SELECT SUM(quantity) AS total_quantity,
       COUNT(*) AS order_lines,
       AVG(quantity) AS avg_quantity,
       SUM(quantity) / COUNT(*) AS divided
FROM order_items;

-- Result:
--  total_quantity | order_lines |    avg_quantity    | divided
-- ----------------+-------------+--------------------+---------
--              16 |          10 | 1.6000000000000000 |       1
-- (1 row)

-- ------------------------------------------------------------
-- Example 6: Aggregates Ignore NULLs
-- ------------------------------------------------------------
SELECT COUNT(*) AS staff,
       SUM(salary) AS payroll
FROM employees
WHERE department_id = 50;

-- Result:
--  staff | payroll
-- -------+---------
--      0 | NULL
-- (1 row)

-- ------------------------------------------------------------
-- Example 7: Grouping with GROUP BY
-- ------------------------------------------------------------
SELECT department_id,
       COUNT(*) AS staff,
       SUM(salary) AS payroll
FROM employees
GROUP BY department_id
ORDER BY department_id;

-- Result:
--  department_id | staff |  payroll
-- ---------------+-------+-----------
--             10 |     1 | 150000.00
--             20 |     2 | 155000.00
--             30 |     3 | 289000.00
--             40 |     1 |  58000.00
--           NULL |     1 |  71000.00
-- (5 rows)

-- ------------------------------------------------------------
-- Example 8: Every column must be grouped or aggregated
-- Fails on purpose, to show the error.
-- ------------------------------------------------------------
SAVEPOINT example;

SELECT department_id, first_name,
       COUNT(*) AS staff
FROM employees
GROUP BY department_id;

ROLLBACK TO SAVEPOINT example;

-- Expected error:
--   ERROR:  column "employees.first_name" must appear in the GROUP BY clause or be used in an aggregate function

-- ------------------------------------------------------------
-- Example 9: Grouping by several columns
-- ------------------------------------------------------------
SELECT department_id, job_title,
       COUNT(*) AS staff
FROM employees
GROUP BY department_id, job_title
ORDER BY department_id, job_title;

-- Result:
--  department_id |      job_title       | staff
-- ---------------+----------------------+-------
--             10 | Managing Director    |     1
--             20 | Accountant           |     1
--             20 | Finance Manager      |     1
--             30 | Engineering Manager  |     1
--             30 | Software Engineer    |     2
--             40 | Sales Representative |     1
--           NULL | Data Analyst         |     1
-- (7 rows)

-- ------------------------------------------------------------
-- Example 10: Filtering Groups with HAVING
-- ------------------------------------------------------------
SELECT department_id, COUNT(*) AS staff
FROM employees
GROUP BY department_id
HAVING COUNT(*) > 1
ORDER BY department_id;

-- Result:
--  department_id | staff
-- ---------------+-------
--             20 |     2
--             30 |     3
-- (2 rows)

-- ------------------------------------------------------------
-- Example 11: Filtering Groups with HAVING
-- ------------------------------------------------------------
SELECT p.product_name,
       SUM(oi.quantity * oi.unit_price)
           AS revenue
FROM order_items oi
JOIN orders o
    ON o.order_id = oi.order_id
JOIN products p
    ON p.product_id = oi.product_id
WHERE o.status <> 'cancelled'
GROUP BY p.product_id, p.product_name
HAVING SUM(oi.quantity * oi.unit_price) > 500
ORDER BY revenue DESC;

-- Result:
--  product_name | revenue
-- --------------+---------
--  Laptop       | 2400.00
--  Smartphone   | 1600.00
--  Monitor      |  900.00
-- (3 rows)

-- ------------------------------------------------------------
-- Example 12: Aggregating Across Joins
-- ------------------------------------------------------------
SELECT c.first_name,
       COUNT(*) AS order_lines,
       COUNT(DISTINCT o.order_id) AS orders,
       SUM(oi.quantity * oi.unit_price)
           AS spent
FROM customers c
JOIN orders o
    ON o.customer_id = c.customer_id
JOIN order_items oi
    ON oi.order_id = o.order_id
GROUP BY c.customer_id, c.first_name
ORDER BY c.customer_id;

-- Result:
--  first_name | order_lines | orders |  spent
-- ------------+-------------+--------+---------
--  Alice      |           4 |      2 | 3021.98
--  Bob        |           1 |      1 |  800.00
--  Charlie    |           3 |      2 | 2000.00
--  Dana       |           2 |      1 |  292.96
-- (4 rows)

-- ------------------------------------------------------------
-- Example 13: Aggregating Across Joins
-- ------------------------------------------------------------
SELECT c.first_name,
       COUNT(*) AS rows_counted,
       COUNT(o.order_id) AS orders
FROM customers c
LEFT JOIN orders o
    ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name
ORDER BY c.customer_id;

-- Result:
--  first_name | rows_counted | orders
-- ------------+--------------+--------
--  Alice      |            2 |      2
--  Bob        |            1 |      1
--  Charlie    |            2 |      2
--  Dana       |            1 |      1
--  Ethan      |            1 |      0
-- (5 rows)

-- ------------------------------------------------------------
-- Example 14: Combining Values into a String
-- ------------------------------------------------------------
SELECT d.department_name,
       STRING_AGG(e.first_name, ', '
                  ORDER BY e.first_name)
           AS staff
FROM departments d
JOIN employees e
    ON e.department_id = d.department_id
GROUP BY d.department_id, d.department_name
ORDER BY d.department_id;

-- Result:
--  department_name |         staff
-- -----------------+-----------------------
--  Executive       | John
--  Finance         | David, Jane
--  Engineering     | Emily, Michael, Sarah
--  Sales           | Priya
-- (4 rows)

-- ------------------------------------------------------------
-- Example 15: Conditional Aggregation
-- ------------------------------------------------------------
SELECT COUNT(*) AS all_orders,
       COUNT(*) FILTER (
           WHERE status = 'shipped')
           AS shipped,
       COUNT(*) FILTER (
           WHERE status = 'cancelled')
           AS cancelled
FROM orders;

-- Result:
--  all_orders | shipped | cancelled
-- ------------+---------+-----------
--           6 |       4 |         1
-- (1 row)

-- ------------------------------------------------------------
-- Try It 1
-- For each product category, show the number of products and the
-- average price, rounded to two decimal places.
-- ------------------------------------------------------------
-- 1. Products and average price per category
SELECT category,
       COUNT(*) AS products,
       ROUND(AVG(price), 2) AS avg_price
FROM products
GROUP BY category
ORDER BY category;

-- Result:
--   category   | products | avg_price
-- -------------+----------+-----------
--  Electronics |        4 |    687.50
--  Furniture   |        1 |    249.00
--  Kitchen     |        1 |     10.99
-- (3 rows)

-- ------------------------------------------------------------
-- Try It 2
-- For each product, count how many different customers have ordered
-- it.
-- ------------------------------------------------------------
-- 2. Different customers per product
SELECT p.product_name,
       COUNT(DISTINCT o.customer_id)
           AS customers
FROM products p
JOIN order_items oi
    ON oi.product_id = p.product_id
JOIN orders o
    ON o.order_id = oi.order_id
GROUP BY p.product_id, p.product_name
ORDER BY p.product_id;

-- Result:
--  product_name | customers
-- --------------+-----------
--  Laptop       |         1
--  Smartphone   |         2
--  Tablet       |         1
--  Monitor      |         2
--  Coffee Mug   |         2
--  Desk Chair   |         1
-- (6 rows)

-- ------------------------------------------------------------
-- Try It 3
-- List the customers who have spent more than 1,000 in total, not
-- counting cancelled orders.
-- ------------------------------------------------------------
-- 3. Customers who spent more than 1,000
SELECT c.first_name, c.last_name,
       SUM(oi.quantity * oi.unit_price)
           AS spent
FROM customers c
JOIN orders o
    ON o.customer_id = c.customer_id
JOIN order_items oi
    ON oi.order_id = o.order_id
WHERE o.status <> 'cancelled'
GROUP BY c.customer_id, c.first_name,
         c.last_name
HAVING SUM(oi.quantity * oi.unit_price) > 1000
ORDER BY c.customer_id;

-- Result:
--  first_name | last_name |  spent
-- ------------+-----------+---------
--  Alice      | Brown     | 3021.98
--  Charlie    | Evans     | 1100.00
-- (2 rows)

-- ------------------------------------------------------------
-- Undo everything this file changed.
-- ------------------------------------------------------------
ROLLBACK;
