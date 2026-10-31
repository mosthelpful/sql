-- The Most Helpful SQL Guide, Second Edition
-- Chapter 13: Subqueries
--
-- Every example in this part of the book that runs on PostgreSQL,
-- in book order, with the result the book prints. Load
-- sample_db.sql first. To run the whole file in psql:
--   psql -d sqlguide -f chapters/ch13_subqueries.sql
-- It runs as one transaction and rolls back at the end, so your
-- database is left unchanged. Examples that change data or fail on
-- purpose are wrapped in a savepoint and undone, as in the book.
-- You can also copy any single example into a query window.

BEGIN;

-- ------------------------------------------------------------
-- Example 1: In WHERE
-- ------------------------------------------------------------
SELECT first_name, last_name, salary
FROM employees
WHERE salary > (SELECT AVG(salary)
                FROM employees)
ORDER BY salary DESC, employee_id;

-- Result:
--  first_name | last_name |  salary
-- ------------+-----------+-----------
--  John       | Doe       | 150000.00
--  Emily      | Johnson   | 105000.00
--  Michael    | Williams  |  92000.00
--  Sarah      | Chen      |  92000.00
-- (4 rows)

-- ------------------------------------------------------------
-- Example 2: In SELECT
-- ------------------------------------------------------------
SELECT project_name, budget,
       ROUND(100 * budget
             / (SELECT SUM(budget)
                FROM projects), 1)
           AS pct_of_total
FROM projects
ORDER BY project_id;

-- Result:
--   project_name   |  budget  | pct_of_total
-- -----------------+----------+--------------
--  Payroll Upgrade | 50000.00 |         21.7
--  Mobile App      | 75000.00 |         32.6
--  Data Platform   | 60000.00 |         26.1
--  Brand Refresh   | 45000.00 |         19.6
-- (4 rows)

-- ------------------------------------------------------------
-- Example 3: IN with a Subquery
-- ------------------------------------------------------------
SELECT first_name, last_name, department_id
FROM employees
WHERE department_id IN (SELECT department_id
                        FROM projects)
ORDER BY employee_id;

-- Result:
--  first_name | last_name | department_id
-- ------------+-----------+---------------
--  Jane       | Smith     |            20
--  Emily      | Johnson   |            30
--  Michael    | Williams  |            30
--  Sarah      | Chen      |            30
--  David      | Brown     |            20
--  Priya      | Patel     |            40
-- (6 rows)

-- ------------------------------------------------------------
-- Example 4: EXISTS and NOT EXISTS
-- ------------------------------------------------------------
SELECT c.customer_id, c.first_name, c.last_name
FROM customers c
WHERE NOT EXISTS (
    SELECT 1
    FROM orders o
    WHERE o.customer_id = c.customer_id
)
ORDER BY c.customer_id;

-- Result:
--  customer_id | first_name | last_name
-- -------------+------------+-----------
--            5 | Ethan      | Ruiz
-- (1 row)

-- ------------------------------------------------------------
-- Example 5: Correlated Subqueries
-- ------------------------------------------------------------
SELECT e.first_name, e.department_id,
       e.salary,
       (SELECT ROUND(AVG(e2.salary), 2)
        FROM employees e2
        WHERE e2.department_id
              = e.department_id) AS dept_avg
FROM employees e
ORDER BY e.employee_id;

-- Result:
--  first_name | department_id |  salary   | dept_avg
-- ------------+---------------+-----------+-----------
--  John       |            10 | 150000.00 | 150000.00
--  Jane       |            20 |  88000.00 |  77500.00
--  Emily      |            30 | 105000.00 |  96333.33
--  Michael    |            30 |  92000.00 |  96333.33
--  Sarah      |            30 |  92000.00 |  96333.33
--  David      |            20 |  67000.00 |  77500.00
--  Priya      |            40 |  58000.00 |  58000.00
--  Tom        |          NULL |  71000.00 |      NULL
-- (8 rows)

-- ------------------------------------------------------------
-- Example 6: Correlated Subqueries
-- ------------------------------------------------------------
SELECT e.first_name, e.department_id,
       e.salary
FROM employees e
WHERE e.salary > (
    SELECT AVG(e2.salary)
    FROM employees e2
    WHERE e2.department_id = e.department_id
)
ORDER BY e.employee_id;

-- Result:
--  first_name | department_id |  salary
-- ------------+---------------+-----------
--  Jane       |            20 |  88000.00
--  Emily      |            30 | 105000.00
-- (2 rows)

-- ------------------------------------------------------------
-- Example 7: Derived Tables
-- ------------------------------------------------------------
SELECT d.department_name, s.staff, b.budget
FROM departments d
LEFT JOIN (SELECT department_id,
                  COUNT(*) AS staff
           FROM employees
           GROUP BY department_id) s
    ON s.department_id = d.department_id
LEFT JOIN (SELECT department_id,
                  SUM(budget) AS budget
           FROM projects
           GROUP BY department_id) b
    ON b.department_id = d.department_id
ORDER BY d.department_id;

-- Result:
--  department_name | staff |  budget
-- -----------------+-------+-----------
--  Executive       |     1 |      NULL
--  Finance         |     2 |  50000.00
--  Engineering     |     3 | 135000.00
--  Sales           |     1 |  45000.00
--  Legal           |  NULL |      NULL
-- (5 rows)

-- ------------------------------------------------------------
-- Example 8: Subqueries in HAVING
-- ------------------------------------------------------------
SELECT department_id,
       ROUND(AVG(salary), 2) AS avg_salary
FROM employees
GROUP BY department_id
HAVING AVG(salary) > (SELECT AVG(salary)
                      FROM employees)
ORDER BY department_id;

-- Result:
--  department_id | avg_salary
-- ---------------+------------
--             10 |  150000.00
--             30 |   96333.33
-- (2 rows)

-- ------------------------------------------------------------
-- Example 9: The NOT IN Trap
-- ------------------------------------------------------------
SELECT department_id, department_name
FROM departments
WHERE department_id NOT IN (SELECT department_id
                            FROM employees)
ORDER BY department_id;

-- Result:
--  department_id | department_name
-- ---------------+-----------------
-- (0 rows)

-- ------------------------------------------------------------
-- Example 10: The NOT IN Trap
-- ------------------------------------------------------------
SELECT d.department_id, d.department_name
FROM departments d
WHERE NOT EXISTS (
    SELECT 1
    FROM employees e
    WHERE e.department_id = d.department_id
)
ORDER BY d.department_id;

-- Result:
--  department_id | department_name
-- ---------------+-----------------
--             50 | Legal
-- (1 row)

-- ------------------------------------------------------------
-- Example 11: LATERAL
-- ------------------------------------------------------------
SELECT c.first_name, lo.order_id,
       lo.order_date
FROM customers c
CROSS JOIN LATERAL (
    SELECT o.order_id, o.order_date
    FROM orders o
    WHERE o.customer_id = c.customer_id
    ORDER BY o.order_date DESC
    LIMIT 1
) lo
ORDER BY c.customer_id;

-- Result:
--  first_name | order_id | order_date
-- ------------+----------+------------
--  Alice      |      104 | 2024-02-03
--  Bob        |      102 | 2024-01-16
--  Charlie    |      106 | 2024-03-05
--  Dana       |      105 | 2024-02-10
-- (4 rows)

-- ------------------------------------------------------------
-- Example 12: Changing Rows Based on Other Tables
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

UPDATE products
SET price = 229.00
WHERE product_id = 6;

UPDATE order_items oi
SET unit_price = (
    SELECT p.price
    FROM products p
    WHERE p.product_id = oi.product_id
)
WHERE oi.order_id = 105;

SELECT order_id, product_id, quantity,
       unit_price
FROM order_items
WHERE order_id = 105
ORDER BY product_id;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  order_id | product_id | quantity | unit_price
-- ----------+------------+----------+------------
--       105 |          5 |        4 |      10.99
--       105 |          6 |        1 |     229.00
-- (2 rows)

-- ------------------------------------------------------------
-- Example 13: Changing Rows Based on Other Tables
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

UPDATE products
SET price = 229.00
WHERE product_id = 6;

UPDATE order_items oi
SET unit_price = p.price
FROM products p
WHERE p.product_id = oi.product_id
    AND oi.order_id = 105;

SELECT order_id, product_id, unit_price
FROM order_items
WHERE order_id = 105
ORDER BY product_id;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  order_id | product_id | unit_price
-- ----------+------------+------------
--       105 |          5 |      10.99
--       105 |          6 |     229.00
-- (2 rows)

-- ------------------------------------------------------------
-- Example 14: Changing Rows Based on Other Tables
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

DELETE FROM customers c
WHERE NOT EXISTS (
    SELECT 1
    FROM orders o
    WHERE o.customer_id = c.customer_id
);

SELECT customer_id, first_name
FROM customers
ORDER BY customer_id;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  customer_id | first_name
-- -------------+------------
--            1 | Alice
--            2 | Bob
--            3 | Charlie
--            4 | Dana
-- (4 rows)

-- ------------------------------------------------------------
-- Example 15: Changing Rows Based on Other Tables
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

DELETE FROM order_items oi
USING orders o
WHERE o.order_id = oi.order_id
    AND o.status = 'cancelled';

SELECT order_id, COUNT(*) AS line_count
FROM order_items
GROUP BY order_id
ORDER BY order_id;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  order_id | line_count
-- ----------+------------
--       101 |          2
--       102 |          1
--       104 |          2
--       105 |          2
--       106 |          2
-- (5 rows)

-- ------------------------------------------------------------
-- Try It 1
-- List the products priced above the average product price.
-- ------------------------------------------------------------
-- 1. Products priced above the average
SELECT product_name, price
FROM products
WHERE price > (SELECT AVG(price)
               FROM products)
ORDER BY product_id;

-- Result:
--  product_name |  price
-- --------------+---------
--  Laptop       | 1200.00
--  Smartphone   |  800.00
-- (2 rows)

-- ------------------------------------------------------------
-- Try It 2
-- List the customers who have at least one shipped order, using
-- EXISTS.
-- ------------------------------------------------------------
-- 2. Customers with a shipped order
SELECT c.customer_id, c.first_name, c.last_name
FROM customers c
WHERE EXISTS (
    SELECT 1
    FROM orders o
    WHERE o.customer_id = c.customer_id
        AND o.status = 'shipped'
)
ORDER BY c.customer_id;

-- Result:
--  customer_id | first_name | last_name
-- -------------+------------+-----------
--            1 | Alice      | Brown
--            2 | Bob        | Davis
--            3 | Charlie    | Evans
-- (3 rows)

-- ------------------------------------------------------------
-- Try It 3
-- Find the highest-paid employee in each department, using a
-- correlated subquery. (Tom, with no department, is left out.)
-- ------------------------------------------------------------
-- 3. The highest-paid employee per department
SELECT e.first_name, e.last_name,
       e.department_id, e.salary
FROM employees e
WHERE e.salary = (
    SELECT MAX(e2.salary)
    FROM employees e2
    WHERE e2.department_id = e.department_id
)
ORDER BY e.department_id;

-- Result:
--  first_name | last_name | department_id |  salary
-- ------------+-----------+---------------+-----------
--  John       | Doe       |            10 | 150000.00
--  Jane       | Smith     |            20 |  88000.00
--  Emily      | Johnson   |            30 | 105000.00
--  Priya      | Patel     |            40 |  58000.00
-- (4 rows)

-- ------------------------------------------------------------
-- Undo everything this file changed.
-- ------------------------------------------------------------
ROLLBACK;
