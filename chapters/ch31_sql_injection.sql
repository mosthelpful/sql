-- The Most Helpful SQL Guide, Second Edition
-- Chapter 31: SQL Injection
--
-- Every example in this chapter that runs on PostgreSQL,
-- in book order, with the result the book prints. Load
-- sample_db.sql first. To run the whole file in psql:
--   psql -d sqlguide -f chapters/ch31_sql_injection.sql
-- It runs as one transaction and rolls back at the end, so your
-- database is left unchanged. Examples that change data or fail on
-- purpose are wrapped in a savepoint and undone, as in the book.
-- You can also copy any single example into a query window.

BEGIN;

-- ------------------------------------------------------------
-- Example 1: Changing the condition
-- ------------------------------------------------------------
SELECT customer_id, first_name
FROM customers
WHERE city = '' OR '1'='1' AND status = 'active'
ORDER BY customer_id;

-- Result:
--  customer_id | first_name
-- -------------+------------
--            1 | Alice
--            3 | Charlie
--            4 | Dana
--            5 | Ethan
-- (4 rows)

-- ------------------------------------------------------------
-- Example 2: Commenting out the rest
-- ------------------------------------------------------------
SELECT customer_id, first_name
FROM customers
WHERE city = 'Chicago' --' AND status = 'active'
ORDER BY customer_id;

-- Result:
--  customer_id | first_name
-- -------------+------------
--            2 | Bob
-- (1 row)

-- ------------------------------------------------------------
-- Example 3: What attackers do next
-- ------------------------------------------------------------
SELECT customer_id, first_name
FROM customers
WHERE city = ''
UNION
SELECT employee_id, last_name || ': ' || salary
FROM employees --' AND status = 'active'
ORDER BY customer_id;

-- Result:
--  customer_id |     first_name
-- -------------+--------------------
--            1 | Doe: 150000.00
--            2 | Smith: 88000.00
--            3 | Johnson: 105000.00
--            4 | Williams: 92000.00
--            5 | Chen: 92000.00
--            6 | Brown: 67000.00
--            7 | Patel: 58000.00
--            8 | Wilson: 71000.00
-- (8 rows)

-- ------------------------------------------------------------
-- Example 4: Defense 1: Parameterized Queries
-- ------------------------------------------------------------
PREPARE find_customers(TEXT) AS
SELECT customer_id, first_name
FROM customers
WHERE city = $1 AND status = 'active'
ORDER BY customer_id;

EXECUTE find_customers('New York');

-- Result:
--  customer_id | first_name
-- -------------+------------
--            1 | Alice
--            3 | Charlie
-- (2 rows)

-- ------------------------------------------------------------
-- Example 5: Defense 1: Parameterized Queries
-- ------------------------------------------------------------
EXECUTE find_customers(''' OR ''1''=''1');

DEALLOCATE find_customers;

-- Result:
--  customer_id | first_name
-- -------------+------------
-- (0 rows)

-- ------------------------------------------------------------
-- Example 6: Defense 2: Safe Identifiers
-- ------------------------------------------------------------
CREATE FUNCTION count_customers(col TEXT,
                                val TEXT)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    n BIGINT;
BEGIN
    EXECUTE format(
        'SELECT COUNT(*) FROM customers
         WHERE %I = $1', col)
        INTO n
        USING val;
    RETURN n;
END;
$$;

SELECT count_customers('city', 'New York')
           AS new_york,
       count_customers('status', 'inactive')
           AS inactive;

-- Result:
--  new_york | inactive
-- ----------+----------
--         2 |        1
-- (1 row)

-- ------------------------------------------------------------
-- Example 7: Defense 2: Safe Identifiers
-- Fails on purpose, to show the error.
-- ------------------------------------------------------------
SAVEPOINT example;

SELECT count_customers('1=1 --', 'x');

ROLLBACK TO SAVEPOINT example;

-- Expected error:
--   ERROR:  column "1=1 --" does not exist

-- ------------------------------------------------------------
-- Try It 1
-- Prepare a statement that lists the orders with a given status,
-- execute it for shipped orders, then deallocate it.
-- ------------------------------------------------------------
-- 1. Orders by status, as a parameter
PREPARE orders_by_status(TEXT) AS
SELECT order_id, customer_id, order_date
FROM orders
WHERE status = $1
ORDER BY order_id;

EXECUTE orders_by_status('shipped');

DEALLOCATE orders_by_status;

-- Result:
--  order_id | customer_id | order_date
-- ----------+-------------+------------
--       101 |           1 | 2024-01-15
--       102 |           2 | 2024-01-16
--       104 |           1 | 2024-02-03
--       106 |           3 | 2024-03-05
-- (4 rows)

-- ------------------------------------------------------------
-- Try It 2
-- Use format() to build the text of a query that counts the rows of
-- a table whose name is given as text. What does it produce for the
-- name orders; DROP TABLE orders?
-- ------------------------------------------------------------
-- 2. %I turns the input into one quoted name
SELECT format('SELECT COUNT(*) FROM %I',
              'orders; DROP TABLE orders')
           AS query;

-- Result:
--                       query
-- --------------------------------------------------
--  SELECT COUNT(*) FROM "orders; DROP TABLE orders"
-- (1 row)

-- ------------------------------------------------------------
-- Try It 3
-- Write a function distinct_values(col) that returns the number of
-- distinct values in a column of customers, allowing only city and
-- status. Call it for city.
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 3. An allow-list, then %I. COUNT(DISTINCT)
--    skips Ethan's NULL city (Chapter 12).
CREATE FUNCTION distinct_values(col TEXT)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    n BIGINT;
BEGIN
    IF col NOT IN ('city', 'status') THEN
        RAISE EXCEPTION 'column % not allowed',
            col;
    END IF;
    EXECUTE format(
        'SELECT COUNT(DISTINCT %I)
         FROM customers', col)
        INTO n;
    RETURN n;
END;
$$;

SELECT distinct_values('city') AS cities;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  cities
-- --------
--       3
-- (1 row)

-- ------------------------------------------------------------
-- Example 8: Try It
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

DROP FUNCTION count_customers;
DROP FUNCTION IF EXISTS distinct_values;

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Undo everything this file changed.
-- ------------------------------------------------------------
ROLLBACK;
