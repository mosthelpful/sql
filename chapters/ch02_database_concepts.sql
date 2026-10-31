-- The Most Helpful SQL Guide, Second Edition
-- Chapter 2: Fundamental Database Concepts
--
-- Every example in this chapter that runs on PostgreSQL,
-- in book order, with the result the book prints. Load
-- sample_db.sql first. To run the whole file in psql:
--   psql -d sqlguide -f chapters/ch02_database_concepts.sql
-- It runs as one transaction and rolls back at the end, so your
-- database is left unchanged. Examples that change data or fail on
-- purpose are wrapped in a savepoint and undone, as in the book.
-- You can also copy any single example into a query window.

BEGIN;

-- ------------------------------------------------------------
-- Example 1: Tables, rows and columns
-- ------------------------------------------------------------
SELECT customer_id, first_name, last_name, city
FROM customers
ORDER BY customer_id;

-- Result:
--  customer_id | first_name | last_name |   city
-- -------------+------------+-----------+----------
--            1 | Alice      | Brown     | New York
--            2 | Bob        | Davis     | Chicago
--            3 | Charlie    | Evans     | New York
--            4 | Dana       | Kim       | Austin
--            5 | Ethan      | Ruiz      | NULL
-- (5 rows)

-- ------------------------------------------------------------
-- Undo everything this file changed.
-- ------------------------------------------------------------
ROLLBACK;
