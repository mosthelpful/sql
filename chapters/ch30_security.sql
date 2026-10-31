-- The Most Helpful SQL Guide, Second Edition
-- Chapter 30: Security
--
-- Every example in this part of the book that runs on PostgreSQL,
-- in book order, with the result the book prints. Load
-- sample_db.sql first. To run the whole file in psql:
--   psql -d sqlguide -f chapters/ch30_security.sql
-- It runs as one transaction and rolls back at the end, so your
-- database is left unchanged. Examples that change data or fail on
-- purpose are wrapped in a savepoint and undone, as in the book.
-- You can also copy any single example into a query window.

BEGIN;

-- ------------------------------------------------------------
-- Example 1: Least Privilege
-- ------------------------------------------------------------
CREATE ROLE ch30_reporting;

GRANT SELECT (employee_id, first_name,
              last_name, job_title,
              department_id)
    ON employees TO ch30_reporting;

-- Result: GRANT

-- ------------------------------------------------------------
-- Example 2: Least Privilege
-- ------------------------------------------------------------
SET LOCAL ROLE ch30_reporting;

SELECT first_name, last_name, job_title
FROM employees
ORDER BY employee_id;

RESET ROLE;

-- Result:
--  first_name | last_name |      job_title
-- ------------+-----------+----------------------
--  John       | Doe       | Managing Director
--  Jane       | Smith     | Finance Manager
--  Emily      | Johnson   | Engineering Manager
--  Michael    | Williams  | Software Engineer
--  Sarah      | Chen      | Software Engineer
--  David      | Brown     | Accountant
--  Priya      | Patel     | Sales Representative
--  Tom        | Wilson    | Data Analyst
-- (8 rows)

-- ------------------------------------------------------------
-- Example 3: Least Privilege
-- Fails on purpose, to show the error.
-- ------------------------------------------------------------
SAVEPOINT example;

SET LOCAL ROLE ch30_reporting;

SELECT first_name, salary
FROM employees
ORDER BY employee_id;

ROLLBACK TO SAVEPOINT example;
RESET ROLE;

-- Expected error:
--   ERROR:  permission denied for table employees

-- ------------------------------------------------------------
-- Example 4: Roles as groups
-- ------------------------------------------------------------
CREATE ROLE ch30_maria LOGIN;
GRANT ch30_reporting TO ch30_maria;

SET LOCAL ROLE ch30_maria;

SELECT COUNT(*) AS employees_visible
FROM employees;

RESET ROLE;

-- Result:
--  employees_visible
-- -------------------
--                  8
-- (1 row)

-- ------------------------------------------------------------
-- Example 5: Row-Level Security
-- ------------------------------------------------------------
CREATE ROLE ch30_engineering;
GRANT SELECT ON employees
    TO ch30_engineering;

ALTER TABLE employees
    ENABLE ROW LEVEL SECURITY;

CREATE POLICY engineering_rows ON employees
    FOR SELECT
    TO ch30_engineering
    USING (department_id = 30);

-- Result: CREATE POLICY

-- ------------------------------------------------------------
-- Example 6: Row-Level Security
-- ------------------------------------------------------------
SET LOCAL ROLE ch30_engineering;

SELECT employee_id, first_name, last_name,
       department_id
FROM employees
ORDER BY employee_id;

RESET ROLE;

-- Result:
--  employee_id | first_name | last_name | department_id
-- -------------+------------+-----------+---------------
--            3 | Emily      | Johnson   |            30
--            4 | Michael    | Williams  |            30
--            5 | Sarah      | Chen      |            30
-- (3 rows)

-- ------------------------------------------------------------
-- Example 7: Storing Passwords
-- ------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TEMPORARY TABLE app_users (
    user_name     VARCHAR(50) PRIMARY KEY,
    password_hash TEXT NOT NULL
);

INSERT INTO app_users (user_name, password_hash)
VALUES ('alice',
        crypt('correct horse battery staple',
              gen_salt('bf', 12)));

-- Result: INSERT 0 1

-- ------------------------------------------------------------
-- Example 8: Storing Passwords
-- ------------------------------------------------------------
SELECT user_name,
       password_hash = crypt(
           'correct horse battery staple',
           password_hash) AS right_password,
       password_hash = crypt(
           'correct horse battery',
           password_hash) AS wrong_password
FROM app_users;

-- Result:
--  user_name | right_password | wrong_password
-- -----------+----------------+----------------
--  alice     | true           | false
-- (1 row)

-- ------------------------------------------------------------
-- Example 9: Encryption
-- ------------------------------------------------------------
SELECT pgp_sym_decrypt(
           pgp_sym_encrypt('123-45-6789',
                           'demo-key'),
           'demo-key') AS decrypted,
       pgp_sym_encrypt('123-45-6789',
                       'demo-key')
           = pgp_sym_encrypt('123-45-6789',
                             'demo-key')
           AS same_ciphertext;

-- Result:
--   decrypted  | same_ciphertext
-- -------------+-----------------
--  123-45-6789 | false
-- (1 row)

-- ------------------------------------------------------------
-- Try It 1
-- Create a role ch30_warehouse that can read products but change
-- only the stock column. As that role, add 10 to the Desk Chair's
-- stock, then show its new level.
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 1. Read products, change only stock
CREATE ROLE ch30_warehouse;
GRANT SELECT ON products TO ch30_warehouse;
GRANT UPDATE (stock) ON products
    TO ch30_warehouse;

SET LOCAL ROLE ch30_warehouse;

UPDATE products
SET stock = stock + 10
WHERE product_id = 6;

SELECT product_name, stock
FROM products
WHERE product_id = 6;

RESET ROLE;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  product_name | stock
-- --------------+-------
--  Desk Chair   |    18
-- (1 row)

-- ------------------------------------------------------------
-- Try It 2
-- Turn on row-level security for orders, and create a role
-- ch30_alice that can see only customer 1's orders. List the orders
-- it sees.
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 2. A role that sees only customer 1's orders
CREATE ROLE ch30_alice;
GRANT SELECT ON orders TO ch30_alice;

ALTER TABLE orders
    ENABLE ROW LEVEL SECURITY;

CREATE POLICY alice_orders ON orders
    FOR SELECT
    TO ch30_alice
    USING (customer_id = 1);

SET LOCAL ROLE ch30_alice;

SELECT order_id, order_date, status
FROM orders
ORDER BY order_id;

RESET ROLE;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  order_id | order_date | status
-- ----------+------------+---------
--       101 | 2024-01-15 | shipped
--       104 | 2024-02-03 | shipped
-- (2 rows)

-- ------------------------------------------------------------
-- Undo everything this file changed.
-- ------------------------------------------------------------
ROLLBACK;
