-- The Most Helpful SQL Guide, Second Edition
-- Chapter 6: Data Types
--
-- Every example in this chapter that runs on PostgreSQL,
-- in book order, with the result the book prints. Load
-- sample_db.sql first. To run the whole file in psql:
--   psql -d sqlguide -f chapters/ch06_data_types.sql
-- It runs as one transaction and rolls back at the end, so your
-- database is left unchanged. Examples that change data or fail on
-- purpose are wrapped in a savepoint and undone, as in the book.
-- You can also copy any single example into a query window.

BEGIN;

-- ------------------------------------------------------------
-- Example 1: Why the Right Type Matters
-- Fails on purpose, to show the error.
-- ------------------------------------------------------------
SAVEPOINT example;

UPDATE employees
SET hire_date = DATE '2024-02-30'
WHERE employee_id = 8;

ROLLBACK TO SAVEPOINT example;

-- Expected error:
--   ERROR:  date/time field value out of range: "2024-02-30"

-- ------------------------------------------------------------
-- Example 2: Floating Point
-- ------------------------------------------------------------
SELECT 0.1 + 0.2 AS decimal_sum,
       CAST(0.1 AS DOUBLE PRECISION)
           + CAST(0.2 AS DOUBLE PRECISION)
           AS float_sum;

-- Result:
--  decimal_sum |      float_sum
-- -------------+---------------------
--          0.3 | 0.30000000000000004
-- (1 row)

-- ------------------------------------------------------------
-- Example 3: Boolean
-- ------------------------------------------------------------
SELECT first_name,
       status = 'active' AS is_active
FROM customers
ORDER BY customer_id;

-- Result:
--  first_name | is_active
-- ------------+-----------
--  Alice      | true
--  Bob        | false
--  Charlie    | true
--  Dana       | true
--  Ethan      | true
-- (5 rows)

-- ------------------------------------------------------------
-- Try It 1
-- List the customers who signed up on or after January 1, 2023.
-- ------------------------------------------------------------
-- 1. Customers who signed up in 2023 or later
SELECT customer_id, first_name, created_on
FROM customers
WHERE created_on >= DATE '2023-01-01'
ORDER BY created_on;

-- Result:
--  customer_id | first_name | created_on
-- -------------+------------+------------
--            4 | Dana       | 2023-03-02
--            5 | Ethan      | 2024-05-20
-- (2 rows)

-- ------------------------------------------------------------
-- Try It 2
-- Write a CREATE TABLE statement for a throwaway product_reviews
-- table with a review ID, the product ID, a rating from 1 to 5, the
-- review text, whether the purchase was verified and when the review
-- was posted. Each column is a name followed by its type; Chapter 9
-- covers the rest.
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 2. One reasonable choice of types
CREATE TABLE product_reviews (
    review_id   BIGINT,
    product_id  INTEGER,
    rating      SMALLINT,
    review_text TEXT,
    is_verified BOOLEAN,
    posted_at   TIMESTAMP WITH TIME ZONE
);

DROP TABLE product_reviews;

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Undo everything this file changed.
-- ------------------------------------------------------------
ROLLBACK;
