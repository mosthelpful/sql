-- The Most Helpful SQL Guide, Second Edition
-- Chapter 29: Schemas
--
-- Every example in this chapter that runs on PostgreSQL,
-- in book order, with the result the book prints. Load
-- sample_db.sql first. To run the whole file in psql:
--   psql -d sqlguide -f chapters/ch29_schemas.sql
-- It runs as one transaction and rolls back at the end, so your
-- database is left unchanged. Examples that change data or fail on
-- purpose are wrapped in a savepoint and undone, as in the book.
-- You can also copy any single example into a query window.

BEGIN;

-- ------------------------------------------------------------
-- Example 1: Creating a Schema
-- ------------------------------------------------------------
CREATE SCHEMA archive;

CREATE TABLE archive.orders (
    order_id    INT PRIMARY KEY,
    customer_id INT NOT NULL,
    order_date  DATE NOT NULL,
    status      VARCHAR(12) NOT NULL,
    order_total DECIMAL(10, 2) NOT NULL
);

-- Result: CREATE TABLE

-- ------------------------------------------------------------
-- Example 2: Creating a Schema
-- ------------------------------------------------------------
INSERT INTO archive.orders
    (order_id, customer_id, order_date, status,
     order_total)
SELECT o.order_id, o.customer_id, o.order_date,
       o.status,
       SUM(oi.quantity * oi.unit_price)
FROM public.orders o
JOIN public.order_items oi
    ON oi.order_id = o.order_id
WHERE o.order_date < DATE '2024-02-01'
GROUP BY o.order_id, o.customer_id,
         o.order_date, o.status;

-- Result: INSERT 0 3

-- ------------------------------------------------------------
-- Example 3: Creating a Schema
-- ------------------------------------------------------------
SELECT 'public' AS schema_name,
       COUNT(*) AS order_count
FROM public.orders
UNION ALL
SELECT 'archive', COUNT(*)
FROM archive.orders
ORDER BY schema_name;

-- Result:
--  schema_name | order_count
-- -------------+-------------
--  archive     |           3
--  public      |           6
-- (2 rows)

-- ------------------------------------------------------------
-- Example 4: Creating a Schema
-- Fails on purpose, to show the error.
-- ------------------------------------------------------------
SAVEPOINT example;

DROP SCHEMA archive;

ROLLBACK TO SAVEPOINT example;

-- Expected error:
--   ERROR:  cannot drop schema archive because other objects depend on it
--   DETAIL:  table archive.orders depends on schema archive
--   HINT:  Use DROP ... CASCADE to drop the dependent objects too.

-- ------------------------------------------------------------
-- Example 5: The Search Path
-- ------------------------------------------------------------
SHOW search_path;

-- Result:
--    search_path
-- -----------------
--  "$user", public
-- (1 row)

-- ------------------------------------------------------------
-- Example 6: The Search Path
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

SET LOCAL search_path = archive, public;

SELECT current_schema() AS current_schema,
       COUNT(*) AS order_count
FROM orders;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  current_schema | order_count
-- ----------------+-------------
--  archive        |           3
-- (1 row)

-- ------------------------------------------------------------
-- Example 7: Listing Schemas
-- ------------------------------------------------------------
SELECT schema_name
FROM information_schema.schemata
WHERE schema_name NOT LIKE 'pg!_%' ESCAPE '!'
    AND schema_name <> 'information_schema'
ORDER BY schema_name;

-- Result:
--  schema_name
-- -------------
--  archive
--  public
-- (2 rows)

-- ------------------------------------------------------------
-- Try It 1
-- Create a schema named reporting, and in it a view named
-- department_payroll that shows each department's name, head count
-- and total salary. Query it by its qualified name.
-- ------------------------------------------------------------
-- 1. A view in its own schema. LEFT JOIN
--    keeps Legal, which has no employees.
CREATE SCHEMA reporting;

CREATE VIEW reporting.department_payroll AS
SELECT d.department_name,
       COUNT(e.employee_id) AS head_count,
       COALESCE(SUM(e.salary), 0.00)
           AS total_salary
FROM public.departments d
LEFT JOIN public.employees e
    ON e.department_id = d.department_id
GROUP BY d.department_name;

SELECT department_name, head_count,
       total_salary
FROM reporting.department_payroll
ORDER BY department_name;

-- Result:
--  department_name | head_count | total_salary
-- -----------------+------------+--------------
--  Engineering     |          3 |    289000.00
--  Executive       |          1 |    150000.00
--  Finance         |          2 |    155000.00
--  Legal           |          0 |         0.00
--  Sales           |          1 |     58000.00
-- (5 rows)

-- ------------------------------------------------------------
-- Try It 2
-- Set the search path so that orders means archive.orders, and list
-- the archived orders with their totals.
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 2. Archive first on the search path
SET LOCAL search_path = archive, public;

SELECT order_id, order_date, order_total
FROM orders
ORDER BY order_id;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  order_id | order_date | order_total
-- ----------+------------+-------------
--       101 | 2024-01-15 |     1221.98
--       102 | 2024-01-16 |      800.00
--       103 | 2024-01-17 |      900.00
-- (3 rows)

-- ------------------------------------------------------------
-- Try It 3
-- List every table and view in the archive and reporting schemas.
-- ------------------------------------------------------------
-- 3. Tables and views in two schemas
SELECT table_schema, table_name, table_type
FROM information_schema.tables
WHERE table_schema IN ('archive', 'reporting')
ORDER BY table_schema, table_name;

-- Result:
--  table_schema |     table_name     | table_type
-- --------------+--------------------+------------
--  archive      | orders             | BASE TABLE
--  reporting    | department_payroll | VIEW
-- (2 rows)

-- ------------------------------------------------------------
-- Example 8: Try It
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

DROP SCHEMA archive, reporting CASCADE;

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Undo everything this file changed.
-- ------------------------------------------------------------
ROLLBACK;
