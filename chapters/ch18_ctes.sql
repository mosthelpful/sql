-- The Most Helpful SQL Guide, Second Edition
-- Chapter 18: Common Table Expressions (CTEs)
--
-- Every example in this part of the book that runs on PostgreSQL,
-- in book order, with the result the book prints. Load
-- sample_db.sql first. To run the whole file in psql:
--   psql -d sqlguide -f chapters/ch18_ctes.sql
-- It runs as one transaction and rolls back at the end, so your
-- database is left unchanged. Examples that change data or fail on
-- purpose are wrapped in a savepoint and undone, as in the book.
-- You can also copy any single example into a query window.

BEGIN;

-- ------------------------------------------------------------
-- Example 1: The WITH Clause
-- ------------------------------------------------------------
WITH dept_salaries AS (
    SELECT department_id,
           SUM(salary) AS total_salary
    FROM employees
    GROUP BY department_id
)
SELECT d.department_name, ds.total_salary
FROM dept_salaries ds
JOIN departments d
    ON d.department_id = ds.department_id
WHERE ds.total_salary > 150000
ORDER BY ds.total_salary DESC;

-- Result:
--  department_name | total_salary
-- -----------------+--------------
--  Engineering     |    289000.00
--  Finance         |    155000.00
-- (2 rows)

-- ------------------------------------------------------------
-- Example 2: Several CTEs in One Query
-- ------------------------------------------------------------
WITH order_totals AS (
    SELECT o.order_id, o.customer_id,
           SUM(oi.quantity * oi.unit_price)
               AS order_total
    FROM orders o
    JOIN order_items oi
        ON oi.order_id = o.order_id
    WHERE o.status <> 'cancelled'
    GROUP BY o.order_id, o.customer_id
),
customer_totals AS (
    SELECT customer_id,
           COUNT(*) AS order_count,
           SUM(order_total) AS total_spent
    FROM order_totals
    GROUP BY customer_id
),
overall AS (
    SELECT AVG(total_spent) AS avg_spent
    FROM customer_totals
)
SELECT c.first_name, c.last_name,
       ct.order_count, ct.total_spent,
       ROUND(ov.avg_spent, 2) AS avg_spent
FROM customer_totals ct
JOIN customers c
    ON c.customer_id = ct.customer_id
CROSS JOIN overall ov
WHERE ct.total_spent > ov.avg_spent
ORDER BY ct.total_spent DESC;

-- Result:
--  first_name | last_name | order_count | total_spent | avg_spent
-- ------------+-----------+-------------+-------------+-----------
--  Alice      | Brown     |           2 |     3021.98 |   1303.74
-- (1 row)

-- ------------------------------------------------------------
-- Example 3: Recursive CTEs
-- ------------------------------------------------------------
WITH RECURSIVE org AS (
    -- Anchor member: where to start
    SELECT employee_id, first_name, manager_id,
           1 AS depth
    FROM employees
    WHERE employee_id = 1

    UNION ALL

    -- Recursive member: one level further down
    SELECT e.employee_id, e.first_name,
           e.manager_id, o.depth + 1
    FROM employees e
    JOIN org o
        ON e.manager_id = o.employee_id
)
SELECT employee_id, first_name, manager_id, depth
FROM org
ORDER BY depth, employee_id;

-- Result:
--  employee_id | first_name | manager_id | depth
-- -------------+------------+------------+-------
--            1 | John       |       NULL |     1
--            2 | Jane       |          1 |     2
--            3 | Emily      |          1 |     2
--            7 | Priya      |          1 |     2
--            4 | Michael    |          3 |     3
--            5 | Sarah      |          3 |     3
--            6 | David      |          2 |     3
--            8 | Tom        |          3 |     3
-- (8 rows)

-- ------------------------------------------------------------
-- Example 4: Guarding against cycles
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

-- Bad data: John now reports to Tom
UPDATE employees
SET manager_id = 8
WHERE employee_id = 1;

WITH RECURSIVE org AS (
    SELECT employee_id, first_name,
           1 AS depth
    FROM employees
    WHERE employee_id = 1
    UNION ALL
    SELECT e.employee_id, e.first_name,
           o.depth + 1
    FROM employees e
    JOIN org o
        ON e.manager_id = o.employee_id
) CYCLE employee_id SET is_cycle USING path
SELECT employee_id, first_name, depth, is_cycle
FROM org
ORDER BY depth, employee_id;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  employee_id | first_name | depth | is_cycle
-- -------------+------------+-------+----------
--            1 | John       |     1 | false
--            2 | Jane       |     2 | false
--            3 | Emily      |     2 | false
--            7 | Priya      |     2 | false
--            4 | Michael    |     3 | false
--            5 | Sarah      |     3 | false
--            6 | David      |     3 | false
--            8 | Tom        |     3 | false
--            1 | John       |     4 | true
-- (9 rows)

-- ------------------------------------------------------------
-- Try It 1
-- Using a CTE, list the employees who earn more than the average
-- salary in their own department. (Tom, with no department, is left
-- out.)
-- ------------------------------------------------------------
-- 1. Above their department's average
WITH dept_avg AS (
    SELECT department_id,
           AVG(salary) AS avg_salary
    FROM employees
    GROUP BY department_id
)
SELECT e.first_name, e.last_name, e.salary,
       ROUND(da.avg_salary, 2) AS dept_avg
FROM employees e
JOIN dept_avg da
    ON da.department_id = e.department_id
WHERE e.salary > da.avg_salary
ORDER BY e.employee_id;

-- Result:
--  first_name | last_name |  salary   | dept_avg
-- ------------+-----------+-----------+----------
--  Jane       | Smith     |  88000.00 | 77500.00
--  Emily      | Johnson   | 105000.00 | 96333.33
-- (2 rows)

-- ------------------------------------------------------------
-- Try It 2
-- Starting from Tom Wilson (employee 8), walk up the management
-- chain to the top. Show each person and how many levels above Tom
-- they are.
-- ------------------------------------------------------------
-- 2. To go up, join on the manager_id
--    of the previous row
WITH RECURSIVE chain AS (
    SELECT employee_id, first_name, manager_id,
           0 AS levels_up
    FROM employees
    WHERE employee_id = 8
    UNION ALL
    SELECT m.employee_id, m.first_name,
           m.manager_id, c.levels_up + 1
    FROM employees m
    JOIN chain c
        ON m.employee_id = c.manager_id
)
SELECT employee_id, first_name, levels_up
FROM chain
ORDER BY levels_up;

-- Result:
--  employee_id | first_name | levels_up
-- -------------+------------+-----------
--            8 | Tom        |         0
--            3 | Emily      |         1
--            1 | John       |         2
-- (3 rows)

-- ------------------------------------------------------------
-- Undo everything this file changed.
-- ------------------------------------------------------------
ROLLBACK;
