-- The Most Helpful SQL Guide, Second Edition
-- Chapter 8: Comments and Formatting
--
-- Every example in this chapter that runs on PostgreSQL,
-- in book order, with the result the book prints. Load
-- sample_db.sql first. To run the whole file in psql:
--   psql -d sqlguide -f chapters/ch08_comments_formatting.sql
-- It runs as one transaction and rolls back at the end, so your
-- database is left unchanged. Examples that change data or fail on
-- purpose are wrapped in a savepoint and undone, as in the book.
-- You can also copy any single example into a query window.

BEGIN;

-- ------------------------------------------------------------
-- Example 1: Comments
-- ------------------------------------------------------------
/* Products to reorder. The supplier needs
   two weeks' notice, and 20 units is about
   two weeks of sales. */
SELECT product_name, category, stock
FROM products
WHERE stock < 20
--  AND category = 'Electronics'
ORDER BY stock;

-- Result:
--  product_name |  category   | stock
-- --------------+-------------+-------
--  Desk Chair   | Furniture   |     8
--  Laptop       | Electronics |    15
-- (2 rows)

-- ------------------------------------------------------------
-- Example 2: Formatting
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

select first_name, last_name, city from
customers where status = 'active' and
created_on < date '2023-01-01' order by
last_name;

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Example 3: Formatting
-- ------------------------------------------------------------
SELECT first_name,
       last_name,
       city
FROM customers
WHERE status = 'active'
    AND created_on < DATE '2023-01-01'
ORDER BY last_name;

-- Result:
--  first_name | last_name |   city
-- ------------+-----------+----------
--  Alice      | Brown     | New York
--  Charlie    | Evans     | New York
-- (2 rows)

-- ------------------------------------------------------------
-- Undo everything this file changed.
-- ------------------------------------------------------------
ROLLBACK;
