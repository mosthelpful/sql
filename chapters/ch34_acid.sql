-- The Most Helpful SQL Guide, Second Edition
-- Chapter 34: ACID
--
-- Every example in this part of the book that runs on PostgreSQL,
-- in book order, with the result the book prints. Load
-- sample_db.sql first. To run the whole file in psql:
--   psql -d sqlguide -f chapters/ch34_acid.sql
-- It runs as one transaction and rolls back at the end, so your
-- database is left unchanged. Examples that change data or fail on
-- purpose are wrapped in a savepoint and undone, as in the book.
-- You can also copy any single example into a query window.

BEGIN;

-- ------------------------------------------------------------
-- Example 1: Atomicity
-- Fails on purpose, to show the error.
-- ------------------------------------------------------------
SAVEPOINT example;

UPDATE products
SET stock = stock - 10;

ROLLBACK TO SAVEPOINT example;

-- Expected error:
--   ERROR:  new row for relation "products" violates check constraint "products_stock_check"
--   DETAIL:  Failing row contains (6, Desk Chair, Furniture, 249.00, -2).

-- ------------------------------------------------------------
-- Example 2: Atomicity
-- ------------------------------------------------------------
SELECT product_id, product_name, stock
FROM products
ORDER BY product_id;

-- Result:
--  product_id | product_name | stock
-- ------------+--------------+-------
--           1 | Laptop       |    15
--           2 | Smartphone   |    40
--           3 | Tablet       |    25
--           4 | Monitor      |    30
--           5 | Coffee Mug   |   100
--           6 | Desk Chair   |     8
-- (6 rows)

-- ------------------------------------------------------------
-- Example 3: Anomalies
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

UPDATE employees
SET salary = 104000
WHERE employee_id = 4;

UPDATE employees
SET salary = 100000
WHERE employee_id = 3;

SELECT e.first_name, e.salary,
       m.first_name AS manager,
       m.salary AS manager_salary
FROM employees e
JOIN employees m
    ON m.employee_id = e.manager_id
WHERE e.salary > m.salary;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  first_name |  salary   | manager | manager_salary
-- ------------+-----------+---------+----------------
--  Michael    | 104000.00 | Emily   |      100000.00
-- (1 row)

-- ------------------------------------------------------------
-- Example 4: Isolation levels in PostgreSQL
-- ------------------------------------------------------------
SHOW transaction_isolation;

-- Result:
--  transaction_isolation
-- -----------------------
--  read committed
-- (1 row)

-- ------------------------------------------------------------
-- Example 5: Trading durability for speed
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

SET synchronous_commit = off;

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Try It 1
-- One UPDATE tries to sell 20 Laptops and 20 Smartphones. What
-- happens to the Smartphone stock?
-- Fails on purpose, to show the error.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 1. Nothing: the Laptop would fall to -5,
--    so the whole statement is undone, and
--    Smartphones stay at 40.
UPDATE products
SET stock = stock - 20
WHERE product_id IN (1, 2);

ROLLBACK TO SAVEPOINT example;

-- Expected error:
--   ERROR:  new row for relation "products" violates check constraint "products_stock_check"
--   DETAIL:  Failing row contains (1, Laptop, Electronics, 1200.00, -5).

-- ------------------------------------------------------------
-- Try It 2
-- At READ COMMITTED, two sessions run UPDATE products SET stock =
-- stock - 5 WHERE product_id = 6 AND stock >= 5; at the same moment.
-- What is the Desk Chair's final stock? Run the statement twice in a
-- row, in a transaction you roll back, to check.
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 2. One session sells 5 (8 to 3). The other
--    waits, re-checks stock >= 5 against 3,
--    and changes nothing. At REPEATABLE READ
--    it would fail with SQLSTATE 40001.
UPDATE products
SET stock = stock - 5
WHERE product_id = 6
    AND stock >= 5;

UPDATE products
SET stock = stock - 5
WHERE product_id = 6
    AND stock >= 5;

SELECT product_id, product_name, stock
FROM products
WHERE product_id = 6;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  product_id | product_name | stock
-- ------------+--------------+-------
--           6 | Desk Chair   |     3
-- (1 row)

-- ------------------------------------------------------------
-- Undo everything this file changed.
-- ------------------------------------------------------------
ROLLBACK;
