-- The Most Helpful SQL Guide, Second Edition
-- Chapter 38: Troubleshooting
--
-- Every example in this chapter that runs on PostgreSQL,
-- in book order, with the result the book prints. Load
-- sample_db.sql first. To run the whole file in psql:
--   psql -d sqlguide -f chapters/ch38_troubleshooting.sql
-- It runs as one transaction and rolls back at the end, so your
-- database is left unchanged. Examples that change data or fail on
-- purpose are wrapped in a savepoint and undone, as in the book.
-- You can also copy any single example into a query window.

BEGIN;

-- ------------------------------------------------------------
-- Example 1: Syntax errors
-- Fails on purpose, to show the error.
-- ------------------------------------------------------------
SAVEPOINT example;

SELECT first_name,
       last_name,
FROM employees;

ROLLBACK TO SAVEPOINT example;

-- Expected error:
--   ERROR:  syntax error at or near "FROM"

-- ------------------------------------------------------------
-- Example 2: Syntax errors
-- ------------------------------------------------------------
SELECT first_name
       last_name
FROM employees
WHERE department_id = 30
ORDER BY employee_id;

-- Result:
--  last_name
-- -----------
--  Emily
--  Michael
--  Sarah
-- (3 rows)

-- ------------------------------------------------------------
-- Example 3: Names that don't exist
-- Fails on purpose, to show the error.
-- ------------------------------------------------------------
SAVEPOINT example;

SELECT first_name, lastname
FROM employees;

ROLLBACK TO SAVEPOINT example;

-- Expected error:
--   ERROR:  column "lastname" does not exist
--   HINT:  Perhaps you meant to reference the column "employees.last_name".

-- ------------------------------------------------------------
-- Example 4: Names that don't exist
-- Fails on purpose, to show the error.
-- ------------------------------------------------------------
SAVEPOINT example;

SELECT first_name, last_name
FROM customers
WHERE status = "active";

ROLLBACK TO SAVEPOINT example;

-- Expected error:
--   ERROR:  column "active" does not exist

-- ------------------------------------------------------------
-- Example 5: Ambiguous columns
-- Fails on purpose, to show the error.
-- ------------------------------------------------------------
SAVEPOINT example;

SELECT department_id, department_name,
       first_name
FROM employees e
JOIN departments d
    ON d.department_id = e.department_id;

ROLLBACK TO SAVEPOINT example;

-- Expected error:
--   ERROR:  column reference "department_id" is ambiguous

-- ------------------------------------------------------------
-- Example 6: Columns missing from GROUP BY
-- Fails on purpose, to show the error.
-- ------------------------------------------------------------
SAVEPOINT example;

SELECT e.department_id, d.department_name,
       COUNT(*) AS staff
FROM employees e
JOIN departments d
    ON d.department_id = e.department_id
GROUP BY e.department_id;

ROLLBACK TO SAVEPOINT example;

-- Expected error:
--   ERROR:  column "d.department_name" must appear in the GROUP BY clause or be used in an aggregate function

-- ------------------------------------------------------------
-- Example 7: Type mismatches
-- Fails on purpose, to show the error.
-- ------------------------------------------------------------
SAVEPOINT example;

SELECT order_id, order_date
FROM orders
WHERE order_id LIKE '10%';

ROLLBACK TO SAVEPOINT example;

-- Expected error:
--   ERROR:  operator does not exist: integer ~~ unknown
--   HINT:  No operator matches the given name and argument types. You might need to add explicit type casts.

-- ------------------------------------------------------------
-- Example 8: Constraint violations
-- Fails on purpose, to show the error.
-- ------------------------------------------------------------
SAVEPOINT example;

DELETE FROM customers
WHERE customer_id = 2;

ROLLBACK TO SAVEPOINT example;

-- Expected error:
--   ERROR:  update or delete on table "customers" violates foreign key constraint "orders_customer_id_fkey" on table "orders"
--   DETAIL:  Key (customer_id)=(2) is still referenced from table "orders".

-- ------------------------------------------------------------
-- Example 9: Wrong Results
-- ------------------------------------------------------------
SELECT COUNT(*) AS joined_rows,
       COUNT(DISTINCT o.order_id) AS orders
FROM orders o
JOIN order_items oi
    ON oi.order_id = o.order_id;

-- Result:
--  joined_rows | orders
-- -------------+--------
--           10 |      6
-- (1 row)

-- ------------------------------------------------------------
-- Example 10: Finding the blocker
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

SELECT pid,
       usename,
       state,
       wait_event_type,
       xact_start,
       LEFT(query, 40) AS query
FROM pg_stat_activity
WHERE backend_type = 'client backend'
ORDER BY xact_start;

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Example 11: Finding the blocker
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

SELECT pid,
       pg_blocking_pids(pid) AS blocked_by,
       wait_event_type,
       LEFT(query, 40) AS query
FROM pg_stat_activity
WHERE cardinality(pg_blocking_pids(pid)) > 0
ORDER BY pid;

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Example 12: Finding the blocker
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

SELECT pid, locktype, mode, granted,
       relation::regclass AS relation
FROM pg_locks
WHERE NOT granted
ORDER BY pid;

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Example 13: Timeouts
-- Fails on purpose, to show the error.
-- ------------------------------------------------------------
SAVEPOINT example;

SET statement_timeout = '1s';
SELECT pg_sleep(2);

ROLLBACK TO SAVEPOINT example;

-- Expected error:
--   ERROR:  canceling statement due to statement timeout

-- ------------------------------------------------------------
-- Example 14: Timeouts
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

SET lock_timeout = '5s';
ALTER TABLE customers
    ADD COLUMN phone VARCHAR(20);

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Example 15: Connection and Server Problems
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

SELECT state, COUNT(*) AS sessions
FROM pg_stat_activity
WHERE backend_type = 'client backend'
GROUP BY state
ORDER BY sessions DESC;

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Example 16: Connection and Server Problems
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

SELECT pg_current_logfile();

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Example 17: Try It
-- ------------------------------------------------------------
SELECT c.first_name,
       COUNT(o.order_id) AS shipped
FROM customers c
LEFT JOIN orders o
    ON o.customer_id = c.customer_id
WHERE o.status = 'shipped'
GROUP BY c.customer_id, c.first_name
ORDER BY c.customer_id;

-- Result:
--  first_name | shipped
-- ------------+---------
--  Alice      |       2
--  Bob        |       1
--  Charlie    |       1
-- (3 rows)

-- ------------------------------------------------------------
-- Try It 1
-- Fix the query from "Columns missing from GROUP BY".
-- ------------------------------------------------------------
-- 1. Group by the departments columns.
--    PostgreSQL also accepts d.department_id
--    alone, because it's the primary key.
SELECT d.department_id, d.department_name,
       COUNT(*) AS staff
FROM employees e
JOIN departments d
    ON d.department_id = e.department_id
GROUP BY d.department_id, d.department_name
ORDER BY d.department_id;

-- Result:
--  department_id | department_name | staff
-- ---------------+-----------------+-------
--             10 | Executive       |     1
--             20 | Finance         |     2
--             30 | Engineering     |     3
--             40 | Sales           |     1
-- (4 rows)

-- ------------------------------------------------------------
-- Try It 2
-- List the sessions that have been idle in a transaction for more
-- than five minutes.
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 2. state_change is when the session
--    became idle
SELECT pid, usename, state_change,
       LEFT(query, 40) AS last_query
FROM pg_stat_activity
WHERE state = 'idle in transaction'
    AND state_change
        < now() - INTERVAL '5 minutes'
ORDER BY state_change;

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Try It 3
-- This query should list every customer with their number of shipped
-- orders, but returns only three customers. Fix it.
-- ------------------------------------------------------------
-- 3. Move the status test into ON, so it
--    picks which orders attach (Chapter 11)
SELECT c.first_name,
       COUNT(o.order_id) AS shipped
FROM customers c
LEFT JOIN orders o
    ON o.customer_id = c.customer_id
    AND o.status = 'shipped'
GROUP BY c.customer_id, c.first_name
ORDER BY c.customer_id;

-- Result:
--  first_name | shipped
-- ------------+---------
--  Alice      |       2
--  Bob        |       1
--  Charlie    |       1
--  Dana       |       0
--  Ethan      |       0
-- (5 rows)

-- ------------------------------------------------------------
-- Example 18: Try It
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

ALTER TABLE customers
    DROP COLUMN IF EXISTS phone;
RESET statement_timeout;
RESET lock_timeout;

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Undo everything this file changed.
-- ------------------------------------------------------------
ROLLBACK;
