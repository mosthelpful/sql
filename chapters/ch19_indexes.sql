-- The Most Helpful SQL Guide, Second Edition
-- Chapter 19: Indexes
--
-- Every example in this chapter that runs on PostgreSQL,
-- in book order, with the result the book prints. Load
-- sample_db.sql first. To run the whole file in psql:
--   psql -d sqlguide -f chapters/ch19_indexes.sql
-- It runs as one transaction and rolls back at the end, so your
-- database is left unchanged. Examples that change data or fail on
-- purpose are wrapped in a savepoint and undone, as in the book.
-- You can also copy any single example into a query window.

BEGIN;

-- ------------------------------------------------------------
-- Example 1: Seeing an Index at Work
-- ------------------------------------------------------------
CREATE TABLE order_history (
    order_id    INT PRIMARY KEY,
    customer_id INT NOT NULL,
    order_date  DATE NOT NULL,
    total       DECIMAL(10, 2) NOT NULL
);

INSERT INTO order_history
    (order_id, customer_id, order_date, total)
SELECT n,
       n % 1000 + 1,
       DATE '2020-01-01' + n / 10,
       n % 500 + 9.99
FROM generate_series(1, 20000) n;

ANALYZE order_history;

SELECT COUNT(*) AS orders,
       COUNT(DISTINCT customer_id) AS customers,
       MIN(order_date) AS first_date,
       MAX(order_date) AS last_date
FROM order_history;

-- Result:
--  orders | customers | first_date | last_date
-- --------+-----------+------------+------------
--   20000 |      1000 | 2020-01-01 | 2025-06-23
-- (1 row)

-- ------------------------------------------------------------
-- Example 2: Seeing an Index at Work
-- ------------------------------------------------------------
EXPLAIN (COSTS OFF)
SELECT order_id, order_date, total
FROM order_history
WHERE customer_id = 42;

-- Plan:
--   Seq Scan on order_history
--     Filter: (customer_id = 42)

-- ------------------------------------------------------------
-- Example 3: Seeing an Index at Work
-- ------------------------------------------------------------
CREATE INDEX idx_order_history_customer
    ON order_history (customer_id);

EXPLAIN (COSTS OFF)
SELECT order_id, order_date, total
FROM order_history
WHERE customer_id = 42;

-- Plan:
--   Bitmap Heap Scan on order_history
--     Recheck Cond: (customer_id = 42)
--     ->  Bitmap Index Scan on idx_order_history_customer
--           Index Cond: (customer_id = 42)

-- ------------------------------------------------------------
-- Example 4: Seeing an Index at Work
-- ------------------------------------------------------------
EXPLAIN (COSTS OFF)
SELECT order_date, total
FROM order_history
WHERE order_id = 42;

-- Plan:
--   Index Scan using order_history_pkey on order_history
--     Index Cond: (order_id = 42)

-- ------------------------------------------------------------
-- Example 5: Composite Indexes
-- ------------------------------------------------------------
DROP INDEX idx_order_history_customer;

CREATE INDEX idx_order_history_cust_date
    ON order_history (customer_id, order_date);

EXPLAIN (COSTS OFF)
SELECT order_id, total
FROM order_history
WHERE customer_id = 42
    AND order_date >= DATE '2024-01-01';

-- Plan:
--   Bitmap Heap Scan on order_history
--     Recheck Cond: ((customer_id = 42) AND (order_date >= '2024-01-01'::date))
--     ->  Bitmap Index Scan on idx_order_history_cust_date
--           Index Cond: ((customer_id = 42) AND (order_date >= '2024-01-01'::date))

-- ------------------------------------------------------------
-- Example 6: Composite Indexes
-- ------------------------------------------------------------
EXPLAIN (COSTS OFF)
SELECT order_id, total
FROM order_history
WHERE order_date = DATE '2024-06-01';

-- Plan:
--   Seq Scan on order_history
--     Filter: (order_date = '2024-06-01'::date)

-- ------------------------------------------------------------
-- Example 7: Indexing Foreign Keys
-- ------------------------------------------------------------
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'order_items';

-- Result:
--     indexname     |                                           indexdef
-- ------------------+-----------------------------------------------------------------------------------------------
--  order_items_pkey | CREATE UNIQUE INDEX order_items_pkey ON public.order_items USING btree (order_id, product_id)
-- (1 row)

-- ------------------------------------------------------------
-- Example 8: Indexing Foreign Keys
-- ------------------------------------------------------------
CREATE INDEX idx_order_items_product
    ON order_items (product_id);

-- Result: CREATE INDEX

-- ------------------------------------------------------------
-- Example 9: Conditions an Index Can Use
-- ------------------------------------------------------------
CREATE INDEX idx_order_history_date
    ON order_history (order_date);

EXPLAIN (COSTS OFF)
SELECT COUNT(*)
FROM order_history
WHERE EXTRACT(YEAR FROM order_date) = 2024;

-- Plan:
--   Aggregate
--     ->  Seq Scan on order_history
--           Filter: (EXTRACT(year FROM order_date) = '2024'::numeric)

-- ------------------------------------------------------------
-- Example 10: Conditions an Index Can Use
-- ------------------------------------------------------------
EXPLAIN (COSTS OFF)
SELECT COUNT(*)
FROM order_history
WHERE order_date >= DATE '2024-01-01'
    AND order_date < DATE '2025-01-01';

-- Plan:
--   Aggregate
--     ->  Index Only Scan using idx_order_history_date on order_history
--           Index Cond: ((order_date >= '2024-01-01'::date) AND (order_date < '2025-01-01'::date))

-- ------------------------------------------------------------
-- Example 11: Unique Indexes
-- ------------------------------------------------------------
CREATE UNIQUE INDEX uq_customers_email_lower
    ON customers (LOWER(email));

-- Result: CREATE INDEX

-- ------------------------------------------------------------
-- Example 12: Unique Indexes
-- Fails on purpose, to show the error.
-- ------------------------------------------------------------
SAVEPOINT example;

INSERT INTO customers
    (customer_id, first_name, last_name, email,
     status, created_on)
VALUES (6, 'Alice', 'Brown', 'ALICE@example.com',
        'active', DATE '2024-06-01');

ROLLBACK TO SAVEPOINT example;

-- Expected error:
--   ERROR:  duplicate key value violates unique constraint "uq_customers_email_lower"
--   DETAIL:  Key (lower(email::text))=(alice@example.com) already exists.

-- ------------------------------------------------------------
-- Example 13: Covering and Partial Indexes
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

CREATE INDEX idx_order_history_cust_cover
    ON order_history (customer_id, order_date)
    INCLUDE (total);

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Example 14: Covering and Partial Indexes
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

CREATE INDEX idx_customers_active_city
    ON customers (city)
    WHERE status = 'active';

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Example 15: Maintaining Indexes
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

SELECT relname AS table_name,
       indexrelname AS index_name,
       idx_scan, last_idx_scan
FROM pg_stat_user_indexes
WHERE idx_scan = 0
ORDER BY relname, indexrelname;

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Example 16: Maintaining Indexes
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

REINDEX INDEX idx_order_history_date;

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Try It 1
-- Add the index that the foreign key orders.customer_id needs, then
-- list the indexes on orders.
-- ------------------------------------------------------------
-- 1. Index the foreign key column
CREATE INDEX idx_orders_customer
    ON orders (customer_id);

SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'orders'
ORDER BY indexname;

-- Result:
--       indexname      |                                  indexdef
-- ---------------------+-----------------------------------------------------------------------------
--  idx_orders_customer | CREATE INDEX idx_orders_customer ON public.orders USING btree (customer_id)
--  orders_pkey         | CREATE UNIQUE INDEX orders_pkey ON public.orders USING btree (order_id)
-- (2 rows)

-- ------------------------------------------------------------
-- Try It 2
-- A query lists the order_id and total of order_history's February
-- 2024 orders with WHERE EXTRACT(MONTH FROM order_date) = 2 AND
-- EXTRACT(YEAR FROM order_date) = 2024. Rewrite the condition so
-- that EXPLAIN (COSTS OFF) shows idx_order_history_date in use.
-- ------------------------------------------------------------
-- 2. February 2024 as a range
EXPLAIN (COSTS OFF)
SELECT order_id, total
FROM order_history
WHERE order_date >= DATE '2024-02-01'
    AND order_date < DATE '2024-03-01';

-- Plan:
--   Index Scan using idx_order_history_date on order_history
--     Index Cond: ((order_date >= '2024-02-01'::date) AND (order_date < '2024-03-01'::date))

-- ------------------------------------------------------------
-- Try It 3
-- Does the order of the conditions in WHERE matter to a composite
-- index? EXPLAIN a query on order_history that tests order_date
-- first and customer_id second.
-- ------------------------------------------------------------
-- 3. No: only the column order in the
--    index matters
EXPLAIN (COSTS OFF)
SELECT order_id, total
FROM order_history
WHERE order_date = DATE '2024-06-01'
    AND customer_id = 42;

-- Plan:
--   Index Scan using idx_order_history_cust_date on order_history
--     Index Cond: ((customer_id = 42) AND (order_date = '2024-06-01'::date))

-- ------------------------------------------------------------
-- Example 17: Try It
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

DROP TABLE IF EXISTS order_history;

DROP INDEX IF EXISTS
    idx_order_items_product,
    idx_customers_email_lower,
    uq_customers_email_lower,
    idx_customers_active_city,
    idx_orders_customer;

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Undo everything this file changed.
-- ------------------------------------------------------------
ROLLBACK;
