-- The Most Helpful SQL Guide, Second Edition
-- Chapter 4: What Is SQL?
--
-- Every example in this chapter that runs on PostgreSQL,
-- in book order, with the result the book prints. Load
-- sample_db.sql first. To run the whole file in psql:
--   psql -d sqlguide -f chapters/ch04_what_is_sql.sql
-- It runs as one transaction and rolls back at the end, so your
-- database is left unchanged. Examples that change data or fail on
-- purpose are wrapped in a savepoint and undone, as in the book.
-- You can also copy any single example into a query window.

BEGIN;

-- ------------------------------------------------------------
-- Example 1: How a Statement Is Built
-- ------------------------------------------------------------
SELECT first_name, last_name, salary
FROM employees
WHERE department_id = 30
ORDER BY last_name;

-- Result:
--  first_name | last_name |  salary
-- ------------+-----------+-----------
--  Sarah      | Chen      |  92000.00
--  Emily      | Johnson   | 105000.00
--  Michael    | Williams  |  92000.00
-- (3 rows)

-- ------------------------------------------------------------
-- Example 2: Data Definition Language (DDL)
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

CREATE TABLE suppliers (
    supplier_id   INT PRIMARY KEY,
    supplier_name VARCHAR(50) NOT NULL
);

ALTER TABLE suppliers
    ADD COLUMN phone VARCHAR(20);

DROP TABLE suppliers;

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Example 3: Data Manipulation Language (DML)
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

INSERT INTO departments
    (department_id, department_name)
VALUES (60, 'Marketing');

UPDATE departments
SET department_name = 'Corporate Finance'
WHERE department_id = 20;

DELETE FROM departments
WHERE department_id = 50;

SELECT department_id, department_name
FROM departments
ORDER BY department_id;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  department_id |  department_name
-- ---------------+-------------------
--             10 | Executive
--             20 | Corporate Finance
--             30 | Engineering
--             40 | Sales
--             60 | Marketing
-- (5 rows)

-- ------------------------------------------------------------
-- Example 4: Example: the first N rows
-- ------------------------------------------------------------
SELECT first_name, last_name, hire_date
FROM employees
ORDER BY hire_date
LIMIT 3;

-- Result:
--  first_name | last_name | hire_date
-- ------------+-----------+------------
--  John       | Doe       | 2015-06-15
--  Jane       | Smith     | 2016-09-23
--  Emily      | Johnson   | 2017-03-11
-- (3 rows)

-- ------------------------------------------------------------
-- Example 5: Example: the first N rows
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

SELECT first_name, last_name, hire_date
FROM employees
ORDER BY hire_date
FETCH FIRST 3 ROWS ONLY;

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Try It 1
-- List the three most expensive products with their prices.
-- ------------------------------------------------------------
-- 1. The three most expensive products
SELECT product_name, price
FROM products
ORDER BY price DESC
LIMIT 3;

-- Result:
--  product_name |  price
-- --------------+---------
--  Laptop       | 1200.00
--  Smartphone   |  800.00
--  Tablet       |  450.00
-- (3 rows)

-- ------------------------------------------------------------
-- Try It 2
-- Change the price of the Coffee Mug (product_id 5) to 12.99, then
-- show that product.
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 2. Change the Coffee Mug's price
UPDATE products
SET price = 12.99
WHERE product_id = 5;

SELECT product_name, price
FROM products
WHERE product_id = 5;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  product_name | price
-- --------------+-------
--  Coffee Mug   | 12.99
-- (1 row)

-- ------------------------------------------------------------
-- Undo everything this file changed.
-- ------------------------------------------------------------
ROLLBACK;
