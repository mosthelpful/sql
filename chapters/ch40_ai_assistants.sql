-- The Most Helpful SQL Guide, Second Edition
-- Chapter 40: Working with AI SQL Assistants
--
-- Every example in this chapter that runs on PostgreSQL,
-- in book order, with the result the book prints. Load
-- sample_db.sql first. To run the whole file in psql:
--   psql -d sqlguide -f chapters/ch40_ai_assistants.sql
-- It runs as one transaction and rolls back at the end, so your
-- database is left unchanged. Examples that change data or fail on
-- purpose are wrapped in a savepoint and undone, as in the book.
-- You can also copy any single example into a query window.

BEGIN;

-- ------------------------------------------------------------
-- Example 1: Giving the Assistant Context
-- ------------------------------------------------------------
SELECT table_name,
       STRING_AGG(column_name || ' '
                  || data_type, ', '
                  ORDER BY ordinal_position)
           AS columns
FROM information_schema.columns
WHERE table_schema = 'public'
    AND table_name IN ('orders', 'order_items')
GROUP BY table_name
ORDER BY table_name;

-- Result:
--  table_name  |                                     columns
-- -------------+----------------------------------------------------------------------------------
--  order_items | order_id integer, product_id integer, quantity integer, unit_price numeric
--  orders      | order_id integer, customer_id integer, order_date date, status character varying
-- (2 rows)

-- ------------------------------------------------------------
-- Example 2: A clause that doesn't exist
-- Fails on purpose, to show the error.
-- ------------------------------------------------------------
SAVEPOINT example;

SELECT p.category, p.product_name,
       SUM(oi.quantity) AS units
FROM products p
JOIN order_items oi
    ON oi.product_id = p.product_id
GROUP BY p.category, p.product_name
ORDER BY units DESC
LIMIT 1 PER p.category;

ROLLBACK TO SAVEPOINT example;

-- Expected error:
--   ERROR:  syntax error at or near "PER"

-- ------------------------------------------------------------
-- Example 3: A clause that doesn't exist
-- ------------------------------------------------------------
WITH product_units AS (
    SELECT p.category, p.product_name,
           SUM(oi.quantity) AS units
    FROM products p
    JOIN order_items oi
        ON oi.product_id = p.product_id
    GROUP BY p.category, p.product_name
),
ranked AS (
    SELECT category, product_name, units,
           ROW_NUMBER() OVER (
               PARTITION BY category
               ORDER BY units DESC, product_name
           ) AS row_num
    FROM product_units
)
SELECT category, product_name, units
FROM ranked
WHERE row_num = 1
ORDER BY category;

-- Result:
--   category   | product_name | units
-- -------------+--------------+-------
--  Electronics | Monitor      |     3
--  Furniture   | Desk Chair   |     1
--  Kitchen     | Coffee Mug   |     6
-- (3 rows)

-- ------------------------------------------------------------
-- Example 4: A window function inside an aggregate
-- Fails on purpose, to show the error.
-- ------------------------------------------------------------
SAVEPOINT example;

SELECT customer_id,
       AVG(order_date - LAG(order_date) OVER (
               PARTITION BY customer_id
               ORDER BY order_date))
           AS avg_days_between
FROM orders
GROUP BY customer_id
ORDER BY customer_id;

ROLLBACK TO SAVEPOINT example;

-- Expected error:
--   ERROR:  aggregate function calls cannot contain window function calls

-- ------------------------------------------------------------
-- Example 5: A window function inside an aggregate
-- ------------------------------------------------------------
WITH gaps AS (
    SELECT customer_id,
           order_date - LAG(order_date) OVER (
               PARTITION BY customer_id
               ORDER BY order_date)
               AS days_between
    FROM orders
)
SELECT customer_id,
       ROUND(AVG(days_between), 1)
           AS avg_days_between
FROM gaps
GROUP BY customer_id
ORDER BY customer_id;

-- Result:
--  customer_id | avg_days_between
-- -------------+------------------
--            1 |             19.0
--            2 |             NULL
--            3 |             48.0
--            4 |             NULL
-- (4 rows)

-- ------------------------------------------------------------
-- Example 6: A limit on the whole result
-- ------------------------------------------------------------
SELECT category, product_name, price
FROM products
ORDER BY category, price DESC
LIMIT 3;

-- Result:
--   category   | product_name |  price
-- -------------+--------------+---------
--  Electronics | Laptop       | 1200.00
--  Electronics | Smartphone   |  800.00
--  Electronics | Tablet       |  450.00
-- (3 rows)

-- ------------------------------------------------------------
-- Example 7: A limit on the whole result
-- ------------------------------------------------------------
WITH ranked AS (
    SELECT category, product_name, price,
           ROW_NUMBER() OVER (
               PARTITION BY category
               ORDER BY price DESC, product_id
           ) AS row_num
    FROM products
)
SELECT category, product_name, price
FROM ranked
WHERE row_num <= 3
ORDER BY category, price DESC;

-- Result:
--   category   | product_name |  price
-- -------------+--------------+---------
--  Electronics | Laptop       | 1200.00
--  Electronics | Smartphone   |  800.00
--  Electronics | Tablet       |  450.00
--  Furniture   | Desk Chair   |  249.00
--  Kitchen     | Coffee Mug   |   10.99
-- (5 rows)

-- ------------------------------------------------------------
-- Example 8: Islands that never split
-- ------------------------------------------------------------
WITH numbered AS (
    SELECT order_date,
           ROW_NUMBER() OVER (ORDER BY order_date)
               AS rn1,
           ROW_NUMBER() OVER (ORDER BY order_date)
               AS rn2
    FROM orders
)
SELECT MIN(order_date) AS streak_start,
       MAX(order_date) AS streak_end,
       COUNT(*) AS days
FROM numbered
GROUP BY rn1 - rn2
ORDER BY streak_start;

-- Result:
--  streak_start | streak_end | days
-- --------------+------------+------
--  2024-01-15   | 2024-03-05 |    6
-- (1 row)

-- ------------------------------------------------------------
-- Example 9: Islands that never split
-- ------------------------------------------------------------
WITH numbered AS (
    SELECT order_date,
           order_date - CAST(DENSE_RANK() OVER (
               ORDER BY order_date) AS INT)
               AS grp
    FROM orders
)
SELECT MIN(order_date) AS streak_start,
       MAX(order_date) AS streak_end,
       COUNT(*) AS days
FROM numbered
GROUP BY grp
ORDER BY streak_start;

-- Result:
--  streak_start | streak_end | days
-- --------------+------------+------
--  2024-01-15   | 2024-01-17 |    3
--  2024-02-03   | 2024-02-03 |    1
--  2024-02-10   | 2024-02-10 |    1
--  2024-03-05   | 2024-03-05 |    1
-- (4 rows)

-- ------------------------------------------------------------
-- Example 10: A number compared with a name
-- Fails on purpose, to show the error.
-- ------------------------------------------------------------
SAVEPOINT example;

SELECT first_name, last_name
FROM employees
WHERE department_id = 'Engineering'
ORDER BY employee_id;

ROLLBACK TO SAVEPOINT example;

-- Expected error:
--   ERROR:  invalid input syntax for type integer: "Engineering"

-- ------------------------------------------------------------
-- Example 11: A number compared with a name
-- ------------------------------------------------------------
SELECT e.first_name, e.last_name
FROM employees e
JOIN departments d
    ON d.department_id = e.department_id
WHERE d.department_name = 'Engineering'
ORDER BY e.employee_id;

-- Result:
--  first_name | last_name
-- ------------+-----------
--  Emily      | Johnson
--  Michael    | Williams
--  Sarah      | Chen
-- (3 rows)

-- ------------------------------------------------------------
-- Example 12: A result nobody ran
-- ------------------------------------------------------------
SELECT SUM(oi.quantity * oi.unit_price)
           AS revenue
FROM orders o
JOIN order_items oi
    ON oi.order_id = o.order_id
WHERE o.status <> 'cancelled'
    AND o.order_date >= DATE '2024-01-01'
    AND o.order_date < DATE '2024-02-01';

-- Result:
--  revenue
-- ---------
--  2021.98
-- (1 row)

-- ------------------------------------------------------------
-- Example 13: Read-only, and only what it needs
-- Fails on purpose, to show the error.
-- ------------------------------------------------------------
SAVEPOINT example;

SET LOCAL transaction_read_only = on;

UPDATE products
SET price = 0
WHERE product_id = 1;

ROLLBACK TO SAVEPOINT example;

-- Expected error:
--   ERROR:  cannot execute UPDATE in a read-only transaction

-- ------------------------------------------------------------
-- Example 14: Log everything it runs
-- ------------------------------------------------------------
SET application_name = 'report-agent';

SELECT current_setting('application_name')
           AS app;

-- Result:
--      app
-- --------------
--  report-agent
-- (1 row)

-- ------------------------------------------------------------
-- Example 15: Try It
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 1. Each department's payroll and number
--    of projects
SELECT d.department_name,
       SUM(e.salary) AS payroll,
       COUNT(p.project_id) AS projects
FROM departments d
JOIN employees e
    ON e.department_id = d.department_id
LEFT JOIN projects p
    ON p.department_id = d.department_id
GROUP BY d.department_id, d.department_name
ORDER BY d.department_id;

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Example 16: Try It
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 2. Employees who don't manage anyone
SELECT first_name, last_name
FROM employees
WHERE employee_id NOT IN (SELECT manager_id
                          FROM employees)
ORDER BY employee_id;

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Example 17: Try It
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 3. The percentage of orders cancelled
SELECT COUNT(*) FILTER (
           WHERE status = 'cancelled')
       / COUNT(*) * 100 AS pct_cancelled
FROM orders;

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Try It 1
-- ------------------------------------------------------------
-- 1. Fan-out: 3 engineers x 2 projects made
--    6 rows. Total each table first; LEFT
--    JOINs also keep Legal.
WITH payroll AS (
    SELECT department_id,
           SUM(salary) AS payroll
    FROM employees
    GROUP BY department_id
),
project_counts AS (
    SELECT department_id,
           COUNT(*) AS projects
    FROM projects
    GROUP BY department_id
)
SELECT d.department_name,
       COALESCE(pr.payroll, 0.00) AS payroll,
       COALESCE(pc.projects, 0) AS projects
FROM departments d
LEFT JOIN payroll pr
    ON pr.department_id = d.department_id
LEFT JOIN project_counts pc
    ON pc.department_id = d.department_id
ORDER BY d.department_id;

-- Result:
--  department_name |  payroll  | projects
-- -----------------+-----------+----------
--  Executive       | 150000.00 |        0
--  Finance         | 155000.00 |        1
--  Engineering     | 289000.00 |        2
--  Sales           |  58000.00 |        1
--  Legal           |      0.00 |        0
-- (5 rows)

-- ------------------------------------------------------------
-- Try It 2
-- ------------------------------------------------------------
-- 2. John's manager_id is NULL, so NOT IN
--    returned no rows. Use NOT EXISTS.
SELECT e.first_name, e.last_name
FROM employees e
WHERE NOT EXISTS (
    SELECT 1
    FROM employees r
    WHERE r.manager_id = e.employee_id
)
ORDER BY e.employee_id;

-- Result:
--  first_name | last_name
-- ------------+-----------
--  Michael    | Williams
--  Sarah      | Chen
--  David      | Brown
--  Priya      | Patel
--  Tom        | Wilson
-- (5 rows)

-- ------------------------------------------------------------
-- Try It 3
-- ------------------------------------------------------------
-- 3. Integer division made 1 / 6 = 0.
--    Multiply by 100.0 first.
SELECT ROUND(100.0 * COUNT(*) FILTER (
                 WHERE status = 'cancelled')
             / COUNT(*), 1) AS pct_cancelled
FROM orders;

-- Result:
--  pct_cancelled
-- ---------------
--           16.7
-- (1 row)

-- ------------------------------------------------------------
-- Undo everything this file changed.
-- ------------------------------------------------------------
ROLLBACK;
