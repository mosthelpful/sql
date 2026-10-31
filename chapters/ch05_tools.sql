-- The Most Helpful SQL Guide, Second Edition
-- Chapter 5: Tools and Software
--
-- Every example in this part of the book that runs on PostgreSQL,
-- in book order, with the result the book prints. Load
-- sample_db.sql first. To run the whole file in psql:
--   psql -d sqlguide -f chapters/ch05_tools.sql
-- It runs as one transaction and rolls back at the end, so your
-- database is left unchanged. Examples that change data or fail on
-- purpose are wrapped in a savepoint and undone, as in the book.
-- You can also copy any single example into a query window.

BEGIN;

-- ------------------------------------------------------------
-- Example 1: Setting Up for This Book
-- ------------------------------------------------------------
SELECT COUNT(*) AS employee_count
FROM employees;

-- Result:
--  employee_count
-- ----------------
--               8
-- (1 row)

-- ------------------------------------------------------------
-- Undo everything this file changed.
-- ------------------------------------------------------------
ROLLBACK;
