-- The Most Helpful SQL Guide, Second Edition
-- Chapter 36: System Functions
--
-- Every example in this part of the book that runs on PostgreSQL,
-- in book order, with the result the book prints. Load
-- sample_db.sql first. To run the whole file in psql:
--   psql -d sqlguide -f chapters/ch36_system_functions.sql
-- It runs as one transaction and rolls back at the end, so your
-- database is left unchanged. Examples that change data or fail on
-- purpose are wrapped in a savepoint and undone, as in the book.
-- You can also copy any single example into a query window.

BEGIN;

-- ------------------------------------------------------------
-- Example 1: Who and where you are
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

SELECT current_database() AS database_name,
       current_schema AS schema_name,
       current_user AS acting_as,
       session_user AS logged_in_as;

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Example 2: The server version
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

SELECT version();

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Example 3: The server version
-- ------------------------------------------------------------
SELECT current_setting('server_version_num')::INT
           >= 150000 AS has_merge;

-- Result:
--  has_merge
-- -----------
--  true
-- (1 row)

-- ------------------------------------------------------------
-- Example 4: Settings
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

SET statement_timeout = '30s';

SELECT current_setting('statement_timeout')
           AS timeout;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  timeout
-- ---------
--  30s
-- (1 row)

-- ------------------------------------------------------------
-- Example 5: Types and Sizes
-- ------------------------------------------------------------
SELECT pg_typeof(7 / 2) AS division,
       pg_typeof(SUM(stock)) AS total,
       pg_typeof(AVG(stock)) AS average,
       pg_typeof(COUNT(*)) AS row_count
FROM products;

-- Result:
--  division | total  | average | row_count
-- ----------+--------+---------+-----------
--  integer  | bigint | numeric | bigint
-- (1 row)

-- ------------------------------------------------------------
-- Example 6: Types and Sizes
-- ------------------------------------------------------------
SELECT product_name, price,
       pg_column_size(product_name) AS name_bytes,
       pg_column_size(price) AS price_bytes,
       pg_column_size(stock) AS stock_bytes
FROM products
ORDER BY product_id;

-- Result:
--  product_name |  price  | name_bytes | price_bytes | stock_bytes
-- --------------+---------+------------+-------------+-------------
--  Laptop       | 1200.00 |          7 |           5 |           4
--  Smartphone   |  800.00 |         11 |           5 |           4
--  Tablet       |  450.00 |          7 |           5 |           4
--  Monitor      |  300.00 |          8 |           5 |           4
--  Coffee Mug   |   10.99 |         11 |           7 |           4
--  Desk Chair   |  249.00 |         11 |           5 |           4
-- (6 rows)

-- ------------------------------------------------------------
-- Example 7: Getting Generated Keys
-- ------------------------------------------------------------
DROP TABLE IF EXISTS tickets;

CREATE TABLE tickets (
    ticket_id INT GENERATED ALWAYS AS IDENTITY
              PRIMARY KEY,
    subject   VARCHAR(100) NOT NULL
);

INSERT INTO tickets (subject)
VALUES ('Printer jammed'),
       ('Password reset')
RETURNING ticket_id, subject;

-- Result:
--  ticket_id |    subject
-- -----------+----------------
--          1 | Printer jammed
--          2 | Password reset
-- (2 rows)

-- ------------------------------------------------------------
-- Example 8: Getting Generated Keys
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

UPDATE products
SET price = price * 1.10
WHERE category = 'Kitchen'
RETURNING product_id, product_name, price;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  product_id | product_name | price
-- ------------+--------------+-------
--           5 | Coffee Mug   | 12.09
-- (1 row)

-- ------------------------------------------------------------
-- Example 9: currval and lastval
-- ------------------------------------------------------------
INSERT INTO tickets (subject)
VALUES ('Screen flickers');

SELECT currval(pg_get_serial_sequence(
                   'tickets', 'ticket_id'))
           AS current_id,
       lastval() AS last_id;

-- Result:
--  current_id | last_id
-- ------------+---------
--           3 |       3
-- (1 row)

-- ------------------------------------------------------------
-- Example 10: Counting Affected Rows
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

CREATE FUNCTION restock_below(p_below INT,
                              p_add   INT)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    n BIGINT;
BEGIN
    UPDATE products
    SET stock = stock + p_add
    WHERE stock < p_below;

    GET DIAGNOSTICS n = ROW_COUNT;
    RETURN n;
END;
$$;

SELECT restock_below(20, 50) AS rows_changed;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  rows_changed
-- --------------
--             2
-- (1 row)

-- ------------------------------------------------------------
-- Try It 1
-- Use pg_typeof() to find the data types of EXTRACT(YEAR FROM
-- order_date) and order_date - DATE '2024-01-01', for order 101.
-- ------------------------------------------------------------
-- 1. EXTRACT returns NUMERIC, and date
--    minus date an integer number of days
SELECT pg_typeof(EXTRACT(YEAR FROM order_date))
           AS extract_type,
       pg_typeof(order_date - DATE '2024-01-01')
           AS difference_type
FROM orders
WHERE order_id = 101;

-- Result:
--  extract_type | difference_type
-- --------------+-----------------
--  numeric      | integer
-- (1 row)

-- ------------------------------------------------------------
-- Try It 2
-- In a transaction you roll back (Chapter 25), raise the price of
-- every Furniture product by 5%, and return each changed product's
-- name and new price in the same statement.
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 2. UPDATE with RETURNING
UPDATE products
SET price = price * 1.05
WHERE category = 'Furniture'
RETURNING product_name, price;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  product_name | price
-- --------------+--------
--  Desk Chair   | 261.45
-- (1 row)

-- ------------------------------------------------------------
-- Try It 3
-- Write a function cancel_stale_orders(p_before DATE) that cancels
-- the orders still processing that were placed before a date, and
-- returns how many it cancelled. Then, in a transaction you roll
-- back, call it for March 1, 2024.
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 3. GET DIAGNOSTICS counts the changed rows
CREATE FUNCTION cancel_stale_orders(
    p_before DATE)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    n BIGINT;
BEGIN
    UPDATE orders
    SET status = 'cancelled'
    WHERE status = 'processing'
        AND order_date < p_before;

    GET DIAGNOSTICS n = ROW_COUNT;
    RETURN n;
END;
$$;

SELECT cancel_stale_orders(DATE '2024-03-01')
           AS cancelled;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  cancelled
-- -----------
--          1
-- (1 row)

-- ------------------------------------------------------------
-- Example 11: Try It
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

DROP TABLE IF EXISTS tickets;
DROP FUNCTION IF EXISTS restock_below,
    cancel_stale_orders;
RESET statement_timeout;

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Undo everything this file changed.
-- ------------------------------------------------------------
ROLLBACK;
