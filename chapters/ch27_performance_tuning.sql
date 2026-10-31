-- The Most Helpful SQL Guide, Second Edition
-- Chapter 27: Performance Tuning
--
-- Every example in this chapter that runs on PostgreSQL,
-- in book order, with the result the book prints. Load
-- sample_db.sql first. To run the whole file in psql:
--   psql -d sqlguide -f chapters/ch27_performance_tuning.sql
-- It runs as one transaction and rolls back at the end, so your
-- database is left unchanged. Examples that change data or fail on
-- purpose are wrapped in a savepoint and undone, as in the book.
-- You can also copy any single example into a query window.

BEGIN;

-- ------------------------------------------------------------
-- Example 1: Statistics and Maintenance
-- ------------------------------------------------------------
CREATE TABLE post_likes (
    post_id INT PRIMARY KEY,
    likes   INT NOT NULL
);

INSERT INTO post_likes (post_id, likes)
SELECT n, 0
FROM generate_series(1, 10000) n;

SELECT pg_size_pretty(
           pg_relation_size('post_likes')
       ) AS table_size;

-- Result:
--  table_size
-- ------------
--  360 kB
-- (1 row)

-- ------------------------------------------------------------
-- Example 2: Statistics and Maintenance
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

UPDATE post_likes
SET likes = likes + 1;

SELECT pg_size_pretty(
           pg_relation_size('post_likes')
       ) AS table_size;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  table_size
-- ------------
--  712 kB
-- (1 row)

-- ------------------------------------------------------------
-- Example 3: Partitioning
-- Fails on purpose, to show the error.
-- ------------------------------------------------------------
SAVEPOINT example;

CREATE TABLE order_archive (
    order_id   INT PRIMARY KEY,
    order_date DATE NOT NULL,
    total      DECIMAL(10, 2) NOT NULL
) PARTITION BY RANGE (order_date);

ROLLBACK TO SAVEPOINT example;

-- Expected error:
--   ERROR:  unique constraint on partitioned table must include all partitioning columns
--   DETAIL:  PRIMARY KEY constraint on table "order_archive" lacks column "order_date" which is part of the partition key.

-- ------------------------------------------------------------
-- Example 4: Partitioning
-- ------------------------------------------------------------
CREATE TABLE order_archive (
    order_id   INT NOT NULL,
    order_date DATE NOT NULL,
    total      DECIMAL(10, 2) NOT NULL,
    PRIMARY KEY (order_id, order_date)
) PARTITION BY RANGE (order_date);

CREATE TABLE order_archive_2023
    PARTITION OF order_archive
    FOR VALUES FROM (DATE '2023-01-01')
               TO (DATE '2024-01-01');
CREATE TABLE order_archive_2024
    PARTITION OF order_archive
    FOR VALUES FROM (DATE '2024-01-01')
               TO (DATE '2025-01-01');
CREATE TABLE order_archive_2025
    PARTITION OF order_archive
    FOR VALUES FROM (DATE '2025-01-01')
               TO (DATE '2026-01-01');

INSERT INTO order_archive
    (order_id, order_date, total)
SELECT n,
       DATE '2023-01-01' + (n - 1) / 10,
       n % 500 + 9.99
FROM generate_series(1, 10960) n;

ANALYZE order_archive;

SELECT tableoid::regclass::text AS partition,
       COUNT(*) AS orders
FROM order_archive
GROUP BY tableoid
ORDER BY partition;

-- Result:
--      partition      | orders
-- --------------------+--------
--  order_archive_2023 |   3650
--  order_archive_2024 |   3660
--  order_archive_2025 |   3650
-- (3 rows)

-- ------------------------------------------------------------
-- Example 5: Partitioning
-- ------------------------------------------------------------
EXPLAIN (COSTS OFF)
SELECT COUNT(*)
FROM order_archive
WHERE order_date >= DATE '2024-03-01'
    AND order_date < DATE '2024-04-01';

-- Plan:
--   Aggregate
--     ->  Seq Scan on order_archive_2024 order_archive
--           Filter: ((order_date >= '2024-03-01'::date) AND (order_date < '2024-04-01'::date))

-- ------------------------------------------------------------
-- Example 6: Partitioning
-- ------------------------------------------------------------
EXPLAIN (COSTS OFF)
SELECT order_date, total
FROM order_archive
WHERE order_id = 5000;

-- Plan:
--   Append
--     ->  Index Scan using order_archive_2023_pkey on order_archive_2023 order_archive_1
--           Index Cond: (order_id = 5000)
--     ->  Index Scan using order_archive_2024_pkey on order_archive_2024 order_archive_2
--           Index Cond: (order_id = 5000)
--     ->  Index Scan using order_archive_2025_pkey on order_archive_2025 order_archive_3
--           Index Cond: (order_id = 5000)

-- ------------------------------------------------------------
-- Example 7: Rows with no partition
-- Fails on purpose, to show the error.
-- ------------------------------------------------------------
SAVEPOINT example;

INSERT INTO order_archive
    (order_id, order_date, total)
VALUES (10961, DATE '2026-01-05', 49.99);

ROLLBACK TO SAVEPOINT example;

-- Expected error:
--   ERROR:  no partition of relation "order_archive" found for row
--   DETAIL:  Partition key of the failing row contains (order_date) = (2026-01-05).

-- ------------------------------------------------------------
-- Example 8: Rows with no partition
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

CREATE TABLE order_archive_default
    PARTITION OF order_archive DEFAULT;

INSERT INTO order_archive
    (order_id, order_date, total)
VALUES (10961, DATE '2026-01-05', 49.99);

SELECT tableoid::regclass::text AS partition,
       order_id, order_date
FROM order_archive
WHERE order_id = 10961;

ROLLBACK TO SAVEPOINT example;

-- Result:
--        partition       | order_id | order_date
-- -----------------------+----------+------------
--  order_archive_default |    10961 | 2026-01-05
-- (1 row)

-- ------------------------------------------------------------
-- Example 9: Rows with no partition
-- Fails on purpose, to show the error.
-- ------------------------------------------------------------
SAVEPOINT example;

CREATE TABLE order_archive_default
    PARTITION OF order_archive DEFAULT;

INSERT INTO order_archive
    (order_id, order_date, total)
VALUES (10961, DATE '2026-01-05', 49.99);

CREATE TABLE order_archive_2026
    PARTITION OF order_archive
    FOR VALUES FROM (DATE '2026-01-01')
               TO (DATE '2027-01-01');

ROLLBACK TO SAVEPOINT example;

-- Expected error:
--   ERROR:  updated partition constraint for default partition "order_archive_default" would be violated by some row

-- ------------------------------------------------------------
-- Example 10: Indexes on a partitioned table
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

CREATE INDEX ON order_archive (total);

SELECT tablename, indexname
FROM pg_indexes
WHERE tablename LIKE 'order_archive_%'
    AND indexname LIKE '%total%'
ORDER BY tablename;

ROLLBACK TO SAVEPOINT example;

-- Result:
--      tablename      |          indexname
-- --------------------+------------------------------
--  order_archive_2023 | order_archive_2023_total_idx
--  order_archive_2024 | order_archive_2024_total_idx
--  order_archive_2025 | order_archive_2025_total_idx
-- (3 rows)

-- ------------------------------------------------------------
-- Example 11: List and hash partitioning
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

CREATE TABLE customer_archive (
    customer_id INT NOT NULL,
    status      VARCHAR(10) NOT NULL,
    PRIMARY KEY (customer_id, status)
) PARTITION BY LIST (status);

CREATE TABLE customer_archive_active
    PARTITION OF customer_archive
    FOR VALUES IN ('active');
CREATE TABLE customer_archive_other
    PARTITION OF customer_archive
    FOR VALUES IN ('inactive', 'closed');

INSERT INTO customer_archive
SELECT customer_id, status
FROM customers;

SELECT tableoid::regclass::text AS partition,
       COUNT(*) AS customers
FROM customer_archive
GROUP BY tableoid
ORDER BY partition;

ROLLBACK TO SAVEPOINT example;

-- Result:
--         partition        | customers
-- -------------------------+-----------
--  customer_archive_active |         4
--  customer_archive_other  |         1
-- (2 rows)

-- ------------------------------------------------------------
-- Example 12: Removing old data
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

ALTER TABLE order_archive
    DETACH PARTITION order_archive_2023;

SELECT COUNT(*) AS orders
FROM order_archive;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  orders
-- --------
--    7310
-- (1 row)

-- ------------------------------------------------------------
-- Try It 1
-- Add a partition for 2026 to order_archive, insert an order dated
-- January 5, 2026, and show which partition holds it.
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 1. The row goes to the partition whose
--    range contains its order_date
CREATE TABLE order_archive_2026
    PARTITION OF order_archive
    FOR VALUES FROM (DATE '2026-01-01')
               TO (DATE '2027-01-01');

INSERT INTO order_archive
    (order_id, order_date, total)
VALUES (10961, DATE '2026-01-05', 49.99);

SELECT tableoid::regclass::text AS partition,
       order_id, order_date
FROM order_archive
WHERE order_id = 10961;

ROLLBACK TO SAVEPOINT example;

-- Result:
--      partition      | order_id | order_date
-- --------------------+----------+------------
--  order_archive_2026 |    10961 | 2026-01-05
-- (1 row)

-- ------------------------------------------------------------
-- Try It 2
-- EXPLAIN a count of the 2024 orders that uses EXTRACT(YEAR FROM
-- order_date) = 2024. Which partitions are scanned, and why?
-- ------------------------------------------------------------
-- 2. All three: the planner can't compare
--    EXTRACT's result with the partition
--    bounds. Use a range (Chapter 19).
EXPLAIN (COSTS OFF)
SELECT COUNT(*)
FROM order_archive
WHERE EXTRACT(YEAR FROM order_date) = 2024;

-- Plan:
--   Aggregate
--     ->  Append
--           ->  Seq Scan on order_archive_2023 order_archive_1
--                 Filter: (EXTRACT(year FROM order_date) = '2024'::numeric)
--           ->  Seq Scan on order_archive_2024 order_archive_2
--                 Filter: (EXTRACT(year FROM order_date) = '2024'::numeric)
--           ->  Seq Scan on order_archive_2025 order_archive_3
--                 Filter: (EXTRACT(year FROM order_date) = '2024'::numeric)

-- ------------------------------------------------------------
-- Example 13: Try It
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

DROP TABLE IF EXISTS post_likes,
    order_archive, order_archive_2023,
    customer_archive;

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Undo everything this file changed.
-- ------------------------------------------------------------
ROLLBACK;
