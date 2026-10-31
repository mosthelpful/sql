-- The Most Helpful SQL Guide, Second Edition
-- Chapter 11: Joins and Set Operations
--
-- Every example in this chapter that runs on PostgreSQL,
-- in book order, with the result the book prints. Load
-- sample_db.sql first. To run the whole file in psql:
--   psql -d sqlguide -f chapters/ch11_joins.sql
-- It runs as one transaction and rolls back at the end, so your
-- database is left unchanged. Examples that change data or fail on
-- purpose are wrapped in a savepoint and undone, as in the book.
-- You can also copy any single example into a query window.

BEGIN;

-- ------------------------------------------------------------
-- Example 1
-- ------------------------------------------------------------
SELECT department_id, department_name
FROM departments
ORDER BY department_id;

-- Result:
--  department_id | department_name
-- ---------------+-----------------
--             10 | Executive
--             20 | Finance
--             30 | Engineering
--             40 | Sales
--             50 | Legal
-- (5 rows)

-- ------------------------------------------------------------
-- Example 2
-- ------------------------------------------------------------
SELECT employee_id, first_name, last_name,
       department_id
FROM employees
ORDER BY employee_id;

-- Result:
--  employee_id | first_name | last_name | department_id
-- -------------+------------+-----------+---------------
--            1 | John       | Doe       |            10
--            2 | Jane       | Smith     |            20
--            3 | Emily      | Johnson   |            30
--            4 | Michael    | Williams  |            30
--            5 | Sarah      | Chen      |            30
--            6 | David      | Brown     |            20
--            7 | Priya      | Patel     |            40
--            8 | Tom        | Wilson    |          NULL
-- (8 rows)

-- ------------------------------------------------------------
-- Example 3: INNER JOIN
-- ------------------------------------------------------------
SELECT e.employee_id, e.first_name, e.last_name,
       d.department_name
FROM employees e
INNER JOIN departments d
    ON e.department_id = d.department_id
ORDER BY e.employee_id;

-- Result:
--  employee_id | first_name | last_name | department_name
-- -------------+------------+-----------+-----------------
--            1 | John       | Doe       | Executive
--            2 | Jane       | Smith     | Finance
--            3 | Emily      | Johnson   | Engineering
--            4 | Michael    | Williams  | Engineering
--            5 | Sarah      | Chen      | Engineering
--            6 | David      | Brown     | Finance
--            7 | Priya      | Patel     | Sales
-- (7 rows)

-- ------------------------------------------------------------
-- Example 4: Joining with USING
-- ------------------------------------------------------------
SELECT department_id, e.first_name,
       d.department_name
FROM employees e
INNER JOIN departments d
    USING (department_id)
WHERE department_id = 20
ORDER BY e.employee_id;

-- Result:
--  department_id | first_name | department_name
-- ---------------+------------+-----------------
--             20 | Jane       | Finance
--             20 | David      | Finance
-- (2 rows)

-- ------------------------------------------------------------
-- Example 5: LEFT JOIN
-- ------------------------------------------------------------
SELECT e.employee_id, e.first_name, e.last_name,
       d.department_name
FROM employees e
LEFT JOIN departments d
    ON e.department_id = d.department_id
ORDER BY e.employee_id;

-- Result:
--  employee_id | first_name | last_name | department_name
-- -------------+------------+-----------+-----------------
--            1 | John       | Doe       | Executive
--            2 | Jane       | Smith     | Finance
--            3 | Emily      | Johnson   | Engineering
--            4 | Michael    | Williams  | Engineering
--            5 | Sarah      | Chen      | Engineering
--            6 | David      | Brown     | Finance
--            7 | Priya      | Patel     | Sales
--            8 | Tom        | Wilson    | NULL
-- (8 rows)

-- ------------------------------------------------------------
-- Example 6: Finding rows with no match
-- ------------------------------------------------------------
SELECT d.department_id, d.department_name
FROM departments d
LEFT JOIN employees e
    ON e.department_id = d.department_id
WHERE e.employee_id IS NULL;

-- Result:
--  department_id | department_name
-- ---------------+-----------------
--             50 | Legal
-- (1 row)

-- ------------------------------------------------------------
-- Example 7: RIGHT JOIN
-- ------------------------------------------------------------
SELECT e.first_name, e.last_name,
       d.department_name
FROM employees e
RIGHT JOIN departments d
    ON e.department_id = d.department_id
ORDER BY d.department_id, e.employee_id;

-- Result:
--  first_name | last_name | department_name
-- ------------+-----------+-----------------
--  John       | Doe       | Executive
--  Jane       | Smith     | Finance
--  David      | Brown     | Finance
--  Emily      | Johnson   | Engineering
--  Michael    | Williams  | Engineering
--  Sarah      | Chen      | Engineering
--  Priya      | Patel     | Sales
--  NULL       | NULL      | Legal
-- (8 rows)

-- ------------------------------------------------------------
-- Example 8: FULL OUTER JOIN
-- ------------------------------------------------------------
SELECT e.first_name, e.last_name,
       d.department_name
FROM employees e
FULL OUTER JOIN departments d
    ON e.department_id = d.department_id
ORDER BY d.department_id, e.employee_id;

-- Result:
--  first_name | last_name | department_name
-- ------------+-----------+-----------------
--  John       | Doe       | Executive
--  Jane       | Smith     | Finance
--  David      | Brown     | Finance
--  Emily      | Johnson   | Engineering
--  Michael    | Williams  | Engineering
--  Sarah      | Chen      | Engineering
--  Priya      | Patel     | Sales
--  NULL       | NULL      | Legal
--  Tom        | Wilson    | NULL
-- (9 rows)

-- ------------------------------------------------------------
-- Example 9: CROSS JOIN
-- ------------------------------------------------------------
SELECT COUNT(*) AS row_count
FROM employees
CROSS JOIN departments;

-- Result:
--  row_count
-- -----------
--         40
-- (1 row)

-- ------------------------------------------------------------
-- Example 10: Self Joins
-- ------------------------------------------------------------
SELECT e.first_name AS employee,
       e.job_title,
       m.first_name AS manager
FROM employees e
LEFT JOIN employees m
    ON e.manager_id = m.employee_id
ORDER BY e.employee_id;

-- Result:
--  employee |      job_title       | manager
-- ----------+----------------------+---------
--  John     | Managing Director    | NULL
--  Jane     | Finance Manager      | John
--  Emily    | Engineering Manager  | John
--  Michael  | Software Engineer    | Emily
--  Sarah    | Software Engineer    | Emily
--  David    | Accountant           | Jane
--  Priya    | Sales Representative | John
--  Tom      | Data Analyst         | Emily
-- (8 rows)

-- ------------------------------------------------------------
-- Example 11: Joining More Than Two Tables
-- ------------------------------------------------------------
SELECT o.order_id,
       o.order_date,
       c.first_name AS customer,
       p.product_name,
       oi.quantity
FROM orders o
INNER JOIN customers c
    ON c.customer_id = o.customer_id
INNER JOIN order_items oi
    ON oi.order_id = o.order_id
INNER JOIN products p
    ON p.product_id = oi.product_id
ORDER BY o.order_id, p.product_name;

-- Result:
--  order_id | order_date | customer | product_name | quantity
-- ----------+------------+----------+--------------+----------
--       101 | 2024-01-15 | Alice    | Coffee Mug   |        2
--       101 | 2024-01-15 | Alice    | Laptop       |        1
--       102 | 2024-01-16 | Bob      | Smartphone   |        1
--       103 | 2024-01-17 | Charlie  | Tablet       |        2
--       104 | 2024-02-03 | Alice    | Laptop       |        1
--       104 | 2024-02-03 | Alice    | Monitor      |        2
--       105 | 2024-02-10 | Dana     | Coffee Mug   |        4
--       105 | 2024-02-10 | Dana     | Desk Chair   |        1
--       106 | 2024-03-05 | Charlie  | Monitor      |        1
--       106 | 2024-03-05 | Charlie  | Smartphone   |        1
-- (10 rows)

-- ------------------------------------------------------------
-- Example 12: 1. Filtering an outer join in the WHERE clause
-- ------------------------------------------------------------
SELECT d.department_name, e.first_name, e.salary
FROM departments d
LEFT JOIN employees e
    ON e.department_id = d.department_id
WHERE e.salary > 90000
ORDER BY d.department_id, e.employee_id;

-- Result:
--  department_name | first_name |  salary
-- -----------------+------------+-----------
--  Executive       | John       | 150000.00
--  Engineering     | Emily      | 105000.00
--  Engineering     | Michael    |  92000.00
--  Engineering     | Sarah      |  92000.00
-- (4 rows)

-- ------------------------------------------------------------
-- Example 13: 1. Filtering an outer join in the WHERE clause
-- ------------------------------------------------------------
SELECT d.department_name, e.first_name, e.salary
FROM departments d
LEFT JOIN employees e
    ON e.department_id = d.department_id
    AND e.salary > 90000
ORDER BY d.department_id, e.employee_id;

-- Result:
--  department_name | first_name |  salary
-- -----------------+------------+-----------
--  Executive       | John       | 150000.00
--  Finance         | NULL       |      NULL
--  Engineering     | Emily      | 105000.00
--  Engineering     | Michael    |  92000.00
--  Engineering     | Sarah      |  92000.00
--  Sales           | NULL       |      NULL
--  Legal           | NULL       |      NULL
-- (7 rows)

-- ------------------------------------------------------------
-- Example 14: 2. Row multiplication ("fan-out")
-- ------------------------------------------------------------
SELECT c.first_name, o.order_id, p.product_name
FROM customers c
INNER JOIN orders o
    ON o.customer_id = c.customer_id
INNER JOIN order_items oi
    ON oi.order_id = o.order_id
INNER JOIN products p
    ON p.product_id = oi.product_id
WHERE c.customer_id = 1
ORDER BY o.order_id, p.product_name;

-- Result:
--  first_name | order_id | product_name
-- ------------+----------+--------------
--  Alice      |      101 | Coffee Mug
--  Alice      |      101 | Laptop
--  Alice      |      104 | Laptop
--  Alice      |      104 | Monitor
-- (4 rows)

-- ------------------------------------------------------------
-- Example 15: UNION
-- ------------------------------------------------------------
SELECT customer_id FROM customers
WHERE status = 'active'
UNION
SELECT customer_id FROM orders
ORDER BY customer_id;

-- Result:
--  customer_id
-- -------------
--            1
--            2
--            3
--            4
--            5
-- (5 rows)

-- ------------------------------------------------------------
-- Example 16: UNION ALL
-- ------------------------------------------------------------
SELECT customer_id FROM customers
WHERE status = 'active'
UNION ALL
SELECT customer_id FROM orders
ORDER BY customer_id;

-- Result:
--  customer_id
-- -------------
--            1
--            1
--            1
--            2
--            3
--            3
--            3
--            4
--            4
--            5
-- (10 rows)

-- ------------------------------------------------------------
-- Example 17: INTERSECT
-- ------------------------------------------------------------
SELECT customer_id FROM customers
WHERE status = 'active'
INTERSECT
SELECT customer_id FROM orders
ORDER BY customer_id;

-- Result:
--  customer_id
-- -------------
--            1
--            3
--            4
-- (3 rows)

-- ------------------------------------------------------------
-- Example 18: EXCEPT
-- ------------------------------------------------------------
SELECT customer_id FROM customers
WHERE status = 'active'
EXCEPT
SELECT customer_id FROM orders;

-- Result:
--  customer_id
-- -------------
--            5
-- (1 row)

-- ------------------------------------------------------------
-- Try It 1
-- List every cancelled order with the customer's first and last
-- name.
-- ------------------------------------------------------------
-- 1. Cancelled orders with customer names
SELECT o.order_id, c.first_name, c.last_name
FROM orders o
INNER JOIN customers c
    ON c.customer_id = o.customer_id
WHERE o.status = 'cancelled';

-- Result:
--  order_id | first_name | last_name
-- ----------+------------+-----------
--       103 | Charlie    | Evans
-- (1 row)

-- ------------------------------------------------------------
-- Try It 2
-- Make one contact list of every employee's and customer's email
-- address, with a column that says which each one is, sorted by
-- email.
-- ------------------------------------------------------------
-- 2. Employees' and customers' emails
SELECT email, 'employee' AS contact_type
FROM employees
UNION ALL
SELECT email, 'customer'
FROM customers
ORDER BY email;

-- Result:
--            email           | contact_type
-- ---------------------------+--------------
--  alice@example.com         | customer
--  bob@example.com           | customer
--  charlie@example.com       | customer
--  dana@example.com          | customer
--  david.brown@example.com   | employee
--  emily.johnson@example.com | employee
--  ethan@example.com         | customer
--  jane.smith@example.com    | employee
--  john.doe@example.com      | employee
--  michael.w@example.com     | employee
--  priya.patel@example.com   | employee
--  sarah.chen@example.com    | employee
--  tom.wilson@example.com    | employee
-- (13 rows)

-- ------------------------------------------------------------
-- Try It 3
-- List every department with the name of each of its projects.
-- Include departments with no projects.
-- ------------------------------------------------------------
-- 3. Departments and their projects,
--    including departments with none
SELECT d.department_name, p.project_name
FROM departments d
LEFT JOIN projects p
    ON p.department_id = d.department_id
ORDER BY d.department_id, p.project_name;

-- Result:
--  department_name |  project_name
-- -----------------+-----------------
--  Executive       | NULL
--  Finance         | Payroll Upgrade
--  Engineering     | Data Platform
--  Engineering     | Mobile App
--  Sales           | Brand Refresh
--  Legal           | NULL
-- (6 rows)

-- ------------------------------------------------------------
-- Undo everything this file changed.
-- ------------------------------------------------------------
ROLLBACK;
