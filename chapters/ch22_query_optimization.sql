-- The Most Helpful SQL Guide, Second Edition
-- Chapter 22: Query Optimization
--
-- Every example in this chapter that runs on PostgreSQL,
-- in book order, with the result the book prints. Load
-- sample_db.sql first. To run the whole file in psql:
--   psql -d sqlguide -f chapters/ch22_query_optimization.sql
-- It runs as one transaction and rolls back at the end, so your
-- database is left unchanged. Examples that change data or fail on
-- purpose are wrapped in a savepoint and undone, as in the book.
-- You can also copy any single example into a query window.

BEGIN;

-- ------------------------------------------------------------
-- Example 1: How the Optimizer Chooses a Plan
-- ------------------------------------------------------------
DROP TABLE IF EXISTS order_history;

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

CREATE TABLE customer_list (
    customer_id INT PRIMARY KEY,
    name        VARCHAR(50) NOT NULL,
    status      VARCHAR(10) NOT NULL
);

INSERT INTO customer_list
    (customer_id, name, status)
SELECT n,
       'Customer ' || n,
       CASE WHEN n % 10 = 0 THEN 'inactive'
            ELSE 'active' END
FROM generate_series(1, 1000) n;

CREATE INDEX idx_order_history_cust_date
    ON order_history (customer_id, order_date);

ANALYZE order_history;
ANALYZE customer_list;

SELECT status, COUNT(*) AS customers
FROM customer_list
GROUP BY status
ORDER BY status;

-- Result:
--   status  | customers
-- ----------+-----------
--  active   |       900
--  inactive |       100
-- (2 rows)

-- ------------------------------------------------------------
-- Example 2: Subqueries rewritten as joins
-- ------------------------------------------------------------
EXPLAIN (COSTS OFF)
SELECT c.customer_id, c.name
FROM customer_list c
WHERE c.status = 'inactive'
    AND EXISTS (
        SELECT 1
        FROM order_history o
        WHERE o.customer_id = c.customer_id
    )
ORDER BY c.customer_id;

-- Plan:
--   Sort
--     Sort Key: c.customer_id
--     ->  Nested Loop Semi Join
--           ->  Seq Scan on customer_list c
--                 Filter: ((status)::text = 'inactive'::text)
--           ->  Index Only Scan using idx_order_history_cust_date on order_history o
--                 Index Cond: (customer_id = c.customer_id)

-- ------------------------------------------------------------
-- Example 3: Join Strategies
-- ------------------------------------------------------------
EXPLAIN (COSTS OFF)
SELECT c.name, o.order_id, o.total
FROM customer_list c
JOIN order_history o
    ON o.customer_id = c.customer_id
WHERE c.customer_id <= 3;

-- Plan:
--   Nested Loop
--     ->  Index Scan using customer_list_pkey on customer_list c
--           Index Cond: (customer_id <= 3)
--     ->  Bitmap Heap Scan on order_history o
--           Recheck Cond: (c.customer_id = customer_id)
--           ->  Bitmap Index Scan on idx_order_history_cust_date
--                 Index Cond: (customer_id = c.customer_id)

-- ------------------------------------------------------------
-- Example 4: Join Strategies
-- ------------------------------------------------------------
EXPLAIN (COSTS OFF)
SELECT c.name, o.order_id, o.total
FROM order_history o
JOIN customer_list c
    ON c.customer_id = o.customer_id
WHERE o.order_date >= DATE '2025-01-01';

-- Plan:
--   Hash Join
--     Hash Cond: (o.customer_id = c.customer_id)
--     ->  Seq Scan on order_history o
--           Filter: (order_date >= '2025-01-01'::date)
--     ->  Hash
--           ->  Seq Scan on customer_list c

-- ------------------------------------------------------------
-- Example 5: Join Strategies
-- ------------------------------------------------------------
EXPLAIN (COSTS OFF)
SELECT c.name, o.order_id, o.total
FROM customer_list c
JOIN order_history o
    ON o.customer_id = c.customer_id
ORDER BY c.customer_id;

-- Plan:
--   Merge Join
--     Merge Cond: (c.customer_id = o.customer_id)
--     ->  Index Scan using customer_list_pkey on customer_list c
--     ->  Index Scan using idx_order_history_cust_date on order_history o

-- ------------------------------------------------------------
-- Example 6: EXPLAIN ANALYZE
-- ------------------------------------------------------------
INSERT INTO order_history
    (order_id, customer_id, order_date, total)
SELECT n,
       n % 1000 + 1,
       DATE '2020-01-01' + n / 10,
       n % 500 + 9.99
FROM generate_series(20001, 25000) n;

EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF,
         SUMMARY OFF)
SELECT c.name, o.order_id, o.total
FROM order_history o
JOIN customer_list c
    ON c.customer_id = o.customer_id
WHERE o.order_date >= DATE '2025-07-01';

-- Plan:
--   Nested Loop (actual rows=4921 loops=1)
--     ->  Seq Scan on order_history o (actual rows=4921 loops=1)
--           Filter: (order_date >= '2025-07-01'::date)
--           Rows Removed by Filter: 20079
--     ->  Index Scan using customer_list_pkey on customer_list c (actual rows=1 loops=4921)
--           Index Cond: (customer_id = o.customer_id)

-- ------------------------------------------------------------
-- Example 7: EXPLAIN ANALYZE
-- ------------------------------------------------------------
ANALYZE order_history;

EXPLAIN (COSTS OFF)
SELECT c.name, o.order_id, o.total
FROM order_history o
JOIN customer_list c
    ON c.customer_id = o.customer_id
WHERE o.order_date >= DATE '2025-07-01';

-- Plan:
--   Hash Join
--     Hash Cond: (o.customer_id = c.customer_id)
--     ->  Seq Scan on order_history o
--           Filter: (order_date >= '2025-07-01'::date)
--     ->  Hash
--           ->  Seq Scan on customer_list c

-- ------------------------------------------------------------
-- Example 8: Filter early
-- ------------------------------------------------------------
EXPLAIN (COSTS OFF)
WITH totals AS MATERIALIZED (
    SELECT customer_id, SUM(total) AS spent
    FROM order_history
    GROUP BY customer_id
)
SELECT customer_id, spent
FROM totals
WHERE customer_id = 42;

-- Plan:
--   CTE Scan on totals
--     Filter: (customer_id = 42)
--     CTE totals
--       ->  HashAggregate
--             Group Key: order_history.customer_id
--             ->  Seq Scan on order_history

-- ------------------------------------------------------------
-- Example 9: Replace loops with one query
-- ------------------------------------------------------------
SELECT o.order_id, c.first_name, c.last_name
FROM orders o
JOIN customers c
    ON c.customer_id = o.customer_id
ORDER BY o.order_id;

-- Result:
--  order_id | first_name | last_name
-- ----------+------------+-----------
--       101 | Alice      | Brown
--       102 | Bob        | Davis
--       103 | Charlie    | Evans
--       104 | Alice      | Brown
--       105 | Dana       | Kim
--       106 | Charlie    | Evans
-- (6 rows)

-- ------------------------------------------------------------
-- Example 10: Prefer UNION ALL
-- ------------------------------------------------------------
EXPLAIN (COSTS OFF)
SELECT order_id, total
FROM order_history
WHERE order_date < DATE '2020-01-08'
UNION
SELECT order_id, total
FROM order_history
WHERE order_date >= DATE '2026-11-01';

-- Plan:
--   HashAggregate
--     Group Key: order_history.order_id, order_history.total
--     ->  Append
--           ->  Seq Scan on order_history
--                 Filter: (order_date < '2020-01-08'::date)
--           ->  Seq Scan on order_history order_history_1
--                 Filter: (order_date >= '2026-11-01'::date)

-- ------------------------------------------------------------
-- Example 11: Page with keyset pagination
-- ------------------------------------------------------------
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF,
         SUMMARY OFF)
SELECT order_id, order_date, total
FROM order_history
ORDER BY order_id
LIMIT 20 OFFSET 24000;

-- Plan:
--   Limit (actual rows=20 loops=1)
--     ->  Index Scan using order_history_pkey on order_history (actual rows=24020 loops=1)

-- ------------------------------------------------------------
-- Example 12: Page with keyset pagination
-- ------------------------------------------------------------
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF,
         SUMMARY OFF)
SELECT order_id, order_date, total
FROM order_history
WHERE order_id > 24000
ORDER BY order_id
LIMIT 20;

-- Plan:
--   Limit (actual rows=20 loops=1)
--     ->  Index Scan using order_history_pkey on order_history (actual rows=20 loops=1)
--           Index Cond: (order_id > 24000)

-- ------------------------------------------------------------
-- Try It 1
-- Rewrite the semi join example with IN instead of EXISTS, and
-- EXPLAIN it.
-- ------------------------------------------------------------
-- 1. The same Nested Loop Semi Join
EXPLAIN (COSTS OFF)
SELECT c.customer_id, c.name
FROM customer_list c
WHERE c.status = 'inactive'
    AND c.customer_id IN (
        SELECT o.customer_id
        FROM order_history o
    )
ORDER BY c.customer_id;

-- Plan:
--   Sort
--     Sort Key: c.customer_id
--     ->  Nested Loop Semi Join
--           ->  Seq Scan on customer_list c
--                 Filter: ((status)::text = 'inactive'::text)
--           ->  Index Only Scan using idx_order_history_cust_date on order_history o
--                 Index Cond: (customer_id = c.customer_id)

-- ------------------------------------------------------------
-- Try It 2
-- EXPLAIN the "Filter early" query without MATERIALIZED.
-- ------------------------------------------------------------
-- 2. The condition reaches the index
EXPLAIN (COSTS OFF)
WITH totals AS (
    SELECT customer_id, SUM(total) AS spent
    FROM order_history
    GROUP BY customer_id
)
SELECT customer_id, spent
FROM totals
WHERE customer_id = 42;

-- Plan:
--   GroupAggregate
--     ->  Bitmap Heap Scan on order_history
--           Recheck Cond: (customer_id = 42)
--           ->  Bitmap Index Scan on idx_order_history_cust_date
--                 Index Cond: (customer_id = 42)

-- ------------------------------------------------------------
-- Try It 3
-- A page of orders sorted by order_date, then order_id, ended with
-- order 19,785, dated June 1, 2025. Fetch the next five orders.
-- ------------------------------------------------------------
-- 3. Compare the pair, so order_id breaks
--    ties on order_date
SELECT order_id, order_date, total
FROM order_history
WHERE (order_date, order_id)
      > (DATE '2025-06-01', 19785)
ORDER BY order_date, order_id
LIMIT 5;

-- Result:
--  order_id | order_date | total
-- ----------+------------+--------
--     19786 | 2025-06-01 | 295.99
--     19787 | 2025-06-01 | 296.99
--     19788 | 2025-06-01 | 297.99
--     19789 | 2025-06-01 | 298.99
--     19790 | 2025-06-02 | 299.99
-- (5 rows)

-- ------------------------------------------------------------
-- Example 13: Try It
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

DROP TABLE IF EXISTS order_history, customer_list;

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Undo everything this file changed.
-- ------------------------------------------------------------
ROLLBACK;
