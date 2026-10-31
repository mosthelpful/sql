-- The Most Helpful SQL Guide, Second Edition
-- Chapter 15: NULL
--
-- Every example in this part of the book that runs on PostgreSQL,
-- in book order, with the result the book prints. Load
-- sample_db.sql first. To run the whole file in psql:
--   psql -d sqlguide -f chapters/ch15_null.sql
-- It runs as one transaction and rolls back at the end, so your
-- database is left unchanged. Examples that change data or fail on
-- purpose are wrapped in a savepoint and undone, as in the book.
-- You can also copy any single example into a query window.

BEGIN;

-- ------------------------------------------------------------
-- Example 1: Three-Valued Logic
-- ------------------------------------------------------------
SELECT first_name, city,
       city = 'New York' AS in_new_york,
       city <> 'New York' AS elsewhere
FROM customers
ORDER BY customer_id;

-- Result:
--  first_name |   city   | in_new_york | elsewhere
-- ------------+----------+-------------+-----------
--  Alice      | New York | true        | false
--  Bob        | Chicago  | false       | true
--  Charlie    | New York | true        | false
--  Dana       | Austin   | false       | true
--  Ethan      | NULL     | NULL        | NULL
-- (5 rows)

-- ------------------------------------------------------------
-- Example 2: IS NULL and IS NOT NULL
-- ------------------------------------------------------------
SELECT first_name, last_name, job_title
FROM employees
WHERE manager_id IS NULL;

-- Result:
--  first_name | last_name |     job_title
-- ------------+-----------+-------------------
--  John       | Doe       | Managing Director
-- (1 row)

-- ------------------------------------------------------------
-- Example 3: Why NOT IN Dropped Tom
-- ------------------------------------------------------------
SELECT first_name, last_name, department_id
FROM employees
WHERE department_id NOT IN (20, 30)
    OR department_id IS NULL
ORDER BY employee_id;

-- Result:
--  first_name | last_name | department_id
-- ------------+-----------+---------------
--  John       | Doe       |            10
--  Priya      | Patel     |            40
--  Tom        | Wilson    |          NULL
-- (3 rows)

-- ------------------------------------------------------------
-- Example 4: IS DISTINCT FROM
-- ------------------------------------------------------------
SELECT first_name, city
FROM customers
WHERE city IS DISTINCT FROM 'New York'
ORDER BY customer_id;

-- Result:
--  first_name |  city
-- ------------+---------
--  Bob        | Chicago
--  Dana       | Austin
--  Ethan      | NULL
-- (3 rows)

-- ------------------------------------------------------------
-- Example 5: Replacing NULL with COALESCE
-- ------------------------------------------------------------
SELECT COUNT(*) AS staff,
       COALESCE(SUM(salary), 0) AS payroll
FROM employees
WHERE department_id = 50;

-- Result:
--  staff | payroll
-- -------+---------
--      0 |       0
-- (1 row)

-- ------------------------------------------------------------
-- Example 6: NULLIF
-- ------------------------------------------------------------
SELECT d.department_name,
       12000 / NULLIF(COUNT(e.employee_id), 0)
           AS per_person
FROM departments d
LEFT JOIN employees e
    ON e.department_id = d.department_id
GROUP BY d.department_id, d.department_name
ORDER BY d.department_id;

-- Result:
--  department_name | per_person
-- -----------------+------------
--  Executive       |      12000
--  Finance         |       6000
--  Engineering     |       4000
--  Sales           |      12000
--  Legal           |       NULL
-- (5 rows)

-- ------------------------------------------------------------
-- Example 7: Sorting NULLs
-- ------------------------------------------------------------
SELECT first_name, city
FROM customers
ORDER BY city DESC NULLS LAST, customer_id;

-- Result:
--  first_name |   city
-- ------------+----------
--  Alice      | New York
--  Charlie    | New York
--  Bob        | Chicago
--  Dana       | Austin
--  Ethan      | NULL
-- (5 rows)

-- ------------------------------------------------------------
-- Example 8: Empty Strings and Concatenation
-- ------------------------------------------------------------
SELECT '' IS NULL AS empty_is_null,
       LENGTH('') AS empty_length;

-- Result:
--  empty_is_null | empty_length
-- ---------------+--------------
--  false         |            0
-- (1 row)

-- ------------------------------------------------------------
-- Try It 1
-- List the customers who don't live in Chicago, including any whose
-- city is unknown.
-- ------------------------------------------------------------
-- 1. Customers outside Chicago, NULLs included
SELECT first_name, last_name, city
FROM customers
WHERE city IS DISTINCT FROM 'Chicago'
ORDER BY customer_id;

-- Result:
--  first_name | last_name |   city
-- ------------+-----------+----------
--  Alice      | Brown     | New York
--  Charlie    | Evans     | New York
--  Dana       | Kim       | Austin
--  Ethan      | Ruiz      | NULL
-- (4 rows)

-- ------------------------------------------------------------
-- Try It 2
-- List each employee with their manager's first name, showing 'None'
-- for anyone without a manager.
-- ------------------------------------------------------------
-- 2. Employees and their managers
SELECT e.first_name AS employee,
       COALESCE(m.first_name, 'None') AS manager
FROM employees e
LEFT JOIN employees m
    ON m.employee_id = e.manager_id
ORDER BY e.employee_id;

-- Result:
--  employee | manager
-- ----------+---------
--  John     | None
--  Jane     | John
--  Emily    | John
--  Michael  | Emily
--  Sarah    | Emily
--  David    | Jane
--  Priya    | John
--  Tom      | Emily
-- (8 rows)

-- ------------------------------------------------------------
-- Try It 3
-- List all employees in department_id order, with anyone who has no
-- department first.
-- ------------------------------------------------------------
-- 3. Employees with no department first
SELECT first_name, last_name, department_id
FROM employees
ORDER BY department_id NULLS FIRST, employee_id;

-- Result:
--  first_name | last_name | department_id
-- ------------+-----------+---------------
--  Tom        | Wilson    |          NULL
--  John       | Doe       |            10
--  Jane       | Smith     |            20
--  David      | Brown     |            20
--  Emily      | Johnson   |            30
--  Michael    | Williams  |            30
--  Sarah      | Chen      |            30
--  Priya      | Patel     |            40
-- (8 rows)

-- ------------------------------------------------------------
-- Undo everything this file changed.
-- ------------------------------------------------------------
ROLLBACK;
