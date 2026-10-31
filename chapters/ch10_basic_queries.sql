-- The Most Helpful SQL Guide, Second Edition
-- Chapter 10: Basic SQL Queries
--
-- Every example in this part of the book that runs on PostgreSQL,
-- in book order, with the result the book prints. Load
-- sample_db.sql first. To run the whole file in psql:
--   psql -d sqlguide -f chapters/ch10_basic_queries.sql
-- It runs as one transaction and rolls back at the end, so your
-- database is left unchanged. Examples that change data or fail on
-- purpose are wrapped in a savepoint and undone, as in the book.
-- You can also copy any single example into a query window.

BEGIN;

-- ------------------------------------------------------------
-- Example 1: Choosing Columns with SELECT
-- ------------------------------------------------------------
SELECT first_name, last_name, job_title
FROM employees
ORDER BY employee_id;

-- Result:
--  first_name | last_name |      job_title
-- ------------+-----------+----------------------
--  John       | Doe       | Managing Director
--  Jane       | Smith     | Finance Manager
--  Emily      | Johnson   | Engineering Manager
--  Michael    | Williams  | Software Engineer
--  Sarah      | Chen      | Software Engineer
--  David      | Brown     | Accountant
--  Priya      | Patel     | Sales Representative
--  Tom        | Wilson    | Data Analyst
-- (8 rows)

-- ------------------------------------------------------------
-- Example 2: Expressions and column aliases
-- ------------------------------------------------------------
SELECT product_name, price, stock,
       price * stock AS stock_value
FROM products
ORDER BY product_id;

-- Result:
--  product_name |  price  | stock | stock_value
-- --------------+---------+-------+-------------
--  Laptop       | 1200.00 |    15 |    18000.00
--  Smartphone   |  800.00 |    40 |    32000.00
--  Tablet       |  450.00 |    25 |    11250.00
--  Monitor      |  300.00 |    30 |     9000.00
--  Coffee Mug   |   10.99 |   100 |     1099.00
--  Desk Chair   |  249.00 |     8 |     1992.00
-- (6 rows)

-- ------------------------------------------------------------
-- Example 3: Removing duplicates with DISTINCT
-- ------------------------------------------------------------
SELECT DISTINCT category
FROM products
ORDER BY category;

-- Result:
--   category
-- -------------
--  Electronics
--  Furniture
--  Kitchen
-- (3 rows)

-- ------------------------------------------------------------
-- Example 4: Comparison operators
-- ------------------------------------------------------------
SELECT product_name, category, price
FROM products
WHERE category <> 'Electronics'
ORDER BY product_id;

-- Result:
--  product_name | category  | price
-- --------------+-----------+--------
--  Coffee Mug   | Kitchen   |  10.99
--  Desk Chair   | Furniture | 249.00
-- (2 rows)

-- ------------------------------------------------------------
-- Example 5: Comparison operators
-- ------------------------------------------------------------
SELECT first_name, last_name, hire_date
FROM employees
WHERE hire_date >= DATE '2020-01-01'
ORDER BY hire_date;

-- Result:
--  first_name | last_name | hire_date
-- ------------+-----------+------------
--  Sarah      | Chen      | 2020-02-03
--  Priya      | Patel     | 2021-08-30
--  Tom        | Wilson    | 2024-01-08
-- (3 rows)

-- ------------------------------------------------------------
-- Example 6: AND, OR and NOT
-- ------------------------------------------------------------
SELECT first_name, last_name, department_id,
       salary
FROM employees
WHERE department_id = 20
    OR department_id = 30
    AND salary > 90000
ORDER BY employee_id;

-- Result:
--  first_name | last_name | department_id |  salary
-- ------------+-----------+---------------+-----------
--  Jane       | Smith     |            20 |  88000.00
--  Emily      | Johnson   |            30 | 105000.00
--  Michael    | Williams  |            30 |  92000.00
--  Sarah      | Chen      |            30 |  92000.00
--  David      | Brown     |            20 |  67000.00
-- (5 rows)

-- ------------------------------------------------------------
-- Example 7: AND, OR and NOT
-- ------------------------------------------------------------
SELECT first_name, last_name, department_id,
       salary
FROM employees
WHERE (department_id = 20
       OR department_id = 30)
    AND salary > 90000
ORDER BY employee_id;

-- Result:
--  first_name | last_name | department_id |  salary
-- ------------+-----------+---------------+-----------
--  Emily      | Johnson   |            30 | 105000.00
--  Michael    | Williams  |            30 |  92000.00
--  Sarah      | Chen      |            30 |  92000.00
-- (3 rows)

-- ------------------------------------------------------------
-- Example 8: IN
-- ------------------------------------------------------------
SELECT first_name, last_name, department_id
FROM employees
WHERE department_id NOT IN (20, 30)
ORDER BY employee_id;

-- Result:
--  first_name | last_name | department_id
-- ------------+-----------+---------------
--  John       | Doe       |            10
--  Priya      | Patel     |            40
-- (2 rows)

-- ------------------------------------------------------------
-- Example 9: BETWEEN
-- ------------------------------------------------------------
SELECT product_name, price
FROM products
WHERE price BETWEEN 300 AND 800
ORDER BY price;

-- Result:
--  product_name | price
-- --------------+--------
--  Monitor      | 300.00
--  Tablet       | 450.00
--  Smartphone   | 800.00
-- (3 rows)

-- ------------------------------------------------------------
-- Example 10: Sorting with ORDER BY
-- ------------------------------------------------------------
SELECT first_name, last_name, salary
FROM employees
ORDER BY salary DESC, last_name;

-- Result:
--  first_name | last_name |  salary
-- ------------+-----------+-----------
--  John       | Doe       | 150000.00
--  Emily      | Johnson   | 105000.00
--  Sarah      | Chen      |  92000.00
--  Michael    | Williams  |  92000.00
--  Jane       | Smith     |  88000.00
--  Tom        | Wilson    |  71000.00
--  David      | Brown     |  67000.00
--  Priya      | Patel     |  58000.00
-- (8 rows)

-- ------------------------------------------------------------
-- Example 11: Limiting Rows
-- ------------------------------------------------------------
SELECT first_name, last_name, salary
FROM employees
ORDER BY salary DESC, employee_id
LIMIT 3;

-- Result:
--  first_name | last_name |  salary
-- ------------+-----------+-----------
--  John       | Doe       | 150000.00
--  Emily      | Johnson   | 105000.00
--  Michael    | Williams  |  92000.00
-- (3 rows)

-- ------------------------------------------------------------
-- Example 12: Limiting Rows
-- ------------------------------------------------------------
SELECT first_name, last_name, salary
FROM employees
ORDER BY salary DESC, employee_id
OFFSET 3 ROWS
FETCH FIRST 3 ROWS ONLY;

-- Result:
--  first_name | last_name |  salary
-- ------------+-----------+----------
--  Sarah      | Chen      | 92000.00
--  Jane       | Smith     | 88000.00
--  Tom        | Wilson    | 71000.00
-- (3 rows)

-- ------------------------------------------------------------
-- Example 13: The Order a Query Runs In
-- Fails on purpose, to show the error.
-- ------------------------------------------------------------
SAVEPOINT example;

SELECT product_name,
       price * stock AS stock_value
FROM products
WHERE stock_value > 10000;

ROLLBACK TO SAVEPOINT example;

-- Expected error:
--   ERROR:  column "stock_value" does not exist

-- ------------------------------------------------------------
-- Example 14: The Order a Query Runs In
-- ------------------------------------------------------------
SELECT product_name,
       price * stock AS stock_value
FROM products
WHERE price * stock > 10000
ORDER BY stock_value DESC;

-- Result:
--  product_name | stock_value
-- --------------+-------------
--  Smartphone   |    32000.00
--  Laptop       |    18000.00
--  Tablet       |    11250.00
-- (3 rows)

-- ------------------------------------------------------------
-- Example 15: Table Aliases
-- ------------------------------------------------------------
SELECT e.first_name, e.last_name, e.job_title
FROM employees e
WHERE e.department_id = 30
ORDER BY e.employee_id;

-- Result:
--  first_name | last_name |      job_title
-- ------------+-----------+---------------------
--  Emily      | Johnson   | Engineering Manager
--  Michael    | Williams  | Software Engineer
--  Sarah      | Chen      | Software Engineer
-- (3 rows)

-- ------------------------------------------------------------
-- Example 16: INSERT
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

INSERT INTO products
    (product_id, product_name, category,
     price, stock)
VALUES (7, 'Desk Lamp', 'Furniture', 39.99, 20);

SELECT product_id, product_name, price, stock
FROM products
ORDER BY product_id;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  product_id | product_name |  price  | stock
-- ------------+--------------+---------+-------
--           1 | Laptop       | 1200.00 |    15
--           2 | Smartphone   |  800.00 |    40
--           3 | Tablet       |  450.00 |    25
--           4 | Monitor      |  300.00 |    30
--           5 | Coffee Mug   |   10.99 |   100
--           6 | Desk Chair   |  249.00 |     8
--           7 | Desk Lamp    |   39.99 |    20
-- (7 rows)

-- ------------------------------------------------------------
-- Example 17: INSERT
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

INSERT INTO departments
    (department_id, department_name)
VALUES
    (60, 'Marketing'),
    (70, 'Support');

SELECT department_id, department_name
FROM departments
ORDER BY department_id;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  department_id | department_name
-- ---------------+-----------------
--             10 | Executive
--             20 | Finance
--             30 | Engineering
--             40 | Sales
--             50 | Legal
--             60 | Marketing
--             70 | Support
-- (7 rows)

-- ------------------------------------------------------------
-- Example 18: UPDATE
-- ------------------------------------------------------------
SELECT product_id, product_name, stock
FROM products
WHERE stock < 20
ORDER BY product_id;

-- Result:
--  product_id | product_name | stock
-- ------------+--------------+-------
--           1 | Laptop       |    15
--           6 | Desk Chair   |     8
-- (2 rows)

-- ------------------------------------------------------------
-- Example 19: UPDATE
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

UPDATE products
SET stock = stock + 50
WHERE stock < 20;

SELECT product_id, product_name, stock
FROM products
ORDER BY product_id;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  product_id | product_name | stock
-- ------------+--------------+-------
--           1 | Laptop       |    65
--           2 | Smartphone   |    40
--           3 | Tablet       |    25
--           4 | Monitor      |    30
--           5 | Coffee Mug   |   100
--           6 | Desk Chair   |    58
-- (6 rows)

-- ------------------------------------------------------------
-- Example 20: DELETE
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

DELETE FROM customers
WHERE customer_id = 5;

SELECT customer_id, first_name, last_name
FROM customers
ORDER BY customer_id;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  customer_id | first_name | last_name
-- -------------+------------+-----------
--            1 | Alice      | Brown
--            2 | Bob        | Davis
--            3 | Charlie    | Evans
--            4 | Dana       | Kim
-- (4 rows)

-- ------------------------------------------------------------
-- Example 21: MERGE
-- ------------------------------------------------------------
DROP TABLE IF EXISTS price_changes;

CREATE TEMPORARY TABLE price_changes (
    product_id   INT PRIMARY KEY,
    product_name VARCHAR(50)    NOT NULL,
    category     VARCHAR(30)    NOT NULL,
    price        DECIMAL(10, 2) NOT NULL
);

INSERT INTO price_changes
    (product_id, product_name, category, price)
VALUES
    (3, 'Tablet', 'Electronics', 399.00),
    (7, 'Desk Lamp', 'Furniture', 39.99);

-- Result: INSERT 0 2

-- ------------------------------------------------------------
-- Example 22: MERGE
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

MERGE INTO products p
USING price_changes pc
    ON (p.product_id = pc.product_id)
WHEN MATCHED THEN
    UPDATE SET price = pc.price
WHEN NOT MATCHED THEN
    INSERT (product_id, product_name, category,
            price, stock)
    VALUES (pc.product_id, pc.product_name,
            pc.category, pc.price, 0);

SELECT product_id, product_name, price, stock
FROM products
ORDER BY product_id;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  product_id | product_name |  price  | stock
-- ------------+--------------+---------+-------
--           1 | Laptop       | 1200.00 |    15
--           2 | Smartphone   |  800.00 |    40
--           3 | Tablet       |  399.00 |    25
--           4 | Monitor      |  300.00 |    30
--           5 | Coffee Mug   |   10.99 |   100
--           6 | Desk Chair   |  249.00 |     8
--           7 | Desk Lamp    |   39.99 |     0
-- (7 rows)

-- ------------------------------------------------------------
-- Example 23: Copying rows with INSERT … SELECT
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

INSERT INTO price_changes
    (product_id, product_name, category, price)
SELECT product_id, product_name, category,
       price * 1.10
FROM products
WHERE product_id IN (5, 6);

SELECT product_id, product_name, price
FROM price_changes
ORDER BY product_id;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  product_id | product_name | price
-- ------------+--------------+--------
--           3 | Tablet       | 399.00
--           5 | Coffee Mug   |  12.09
--           6 | Desk Chair   | 273.90
--           7 | Desk Lamp    |  39.99
-- (4 rows)

-- ------------------------------------------------------------
-- Try It 1
-- List the active customers who live in New York or Austin.
-- ------------------------------------------------------------
-- 1. Active customers in New York or Austin
SELECT customer_id, first_name, last_name, city
FROM customers
WHERE status = 'active'
    AND city IN ('New York', 'Austin')
ORDER BY customer_id;

-- Result:
--  customer_id | first_name | last_name |   city
-- -------------+------------+-----------+----------
--            1 | Alice      | Brown     | New York
--            3 | Charlie    | Evans     | New York
--            4 | Dana       | Kim       | Austin
-- (3 rows)

-- ------------------------------------------------------------
-- Try It 2
-- Show the three most recently hired employees and their hire dates.
-- ------------------------------------------------------------
-- 2. The three most recent hires
SELECT first_name, last_name, hire_date
FROM employees
ORDER BY hire_date DESC, employee_id
LIMIT 3;

-- Result:
--  first_name | last_name | hire_date
-- ------------+-----------+------------
--  Tom        | Wilson    | 2024-01-08
--  Priya      | Patel     | 2021-08-30
--  Sarah      | Chen      | 2020-02-03
-- (3 rows)

-- ------------------------------------------------------------
-- Try It 3
-- Give every Software Engineer a 5% raise. Then list the names and
-- salaries of everyone in Engineering (department 30).
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 3. A 5% raise for software engineers
UPDATE employees
SET salary = salary * 1.05
WHERE job_title = 'Software Engineer';

SELECT first_name, last_name, salary
FROM employees
WHERE department_id = 30
ORDER BY employee_id;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  first_name | last_name |  salary
-- ------------+-----------+-----------
--  Emily      | Johnson   | 105000.00
--  Michael    | Williams  |  96600.00
--  Sarah      | Chen      |  96600.00
-- (3 rows)

-- ------------------------------------------------------------
-- Undo everything this file changed.
-- ------------------------------------------------------------
ROLLBACK;
