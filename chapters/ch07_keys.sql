-- The Most Helpful SQL Guide, Second Edition
-- Chapter 7: Keys
--
-- Every example in this chapter that runs on PostgreSQL,
-- in book order, with the result the book prints. Load
-- sample_db.sql first. To run the whole file in psql:
--   psql -d sqlguide -f chapters/ch07_keys.sql
-- It runs as one transaction and rolls back at the end, so your
-- database is left unchanged. Examples that change data or fail on
-- purpose are wrapped in a savepoint and undone, as in the book.
-- You can also copy any single example into a query window.

BEGIN;

-- ------------------------------------------------------------
-- Example 1: Primary Keys
-- Fails on purpose, to show the error.
-- ------------------------------------------------------------
SAVEPOINT example;

INSERT INTO departments
    (department_id, department_name)
VALUES (20, 'Marketing');

ROLLBACK TO SAVEPOINT example;

-- Expected error:
--   ERROR:  duplicate key value violates unique constraint "departments_pkey"
--   DETAIL:  Key (department_id)=(20) already exists.

-- ------------------------------------------------------------
-- Example 2: Foreign Keys
-- Fails on purpose, to show the error.
-- ------------------------------------------------------------
SAVEPOINT example;

INSERT INTO employees
    (employee_id, first_name, last_name, email,
     job_title, department_id, hire_date, salary)
VALUES
    (9, 'Lena', 'Park', 'lena.park@example.com',
     'Paralegal', 99, DATE '2024-06-03', 52000);

ROLLBACK TO SAVEPOINT example;

-- Expected error:
--   ERROR:  insert or update on table "employees" violates foreign key constraint "employees_department_id_fkey"
--   DETAIL:  Key (department_id)=(99) is not present in table "departments".

-- ------------------------------------------------------------
-- Example 3: Foreign Keys
-- Fails on purpose, to show the error.
-- ------------------------------------------------------------
SAVEPOINT example;

DELETE FROM departments
WHERE department_id = 20;

ROLLBACK TO SAVEPOINT example;

-- Expected error:
--   ERROR:  update or delete on table "departments" violates foreign key constraint "employees_department_id_fkey" on table "employees"
--   DETAIL:  Key (department_id)=(20) is still referenced from table "employees".

-- ------------------------------------------------------------
-- Example 4: Composite Keys
-- ------------------------------------------------------------
SELECT order_id, product_id, quantity
FROM order_items
WHERE order_id = 101
    OR product_id = 1
ORDER BY order_id, product_id;

-- Result:
--  order_id | product_id | quantity
-- ----------+------------+----------
--       101 |          1 |        1
--       101 |          5 |        2
--       104 |          1 |        1
-- (3 rows)

-- ------------------------------------------------------------
-- Example 5: Generated Keys
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

CREATE TABLE tickets (
    ticket_id INT GENERATED ALWAYS AS IDENTITY
              PRIMARY KEY,
    subject   VARCHAR(100) NOT NULL
);

INSERT INTO tickets (subject)
VALUES ('Printer jammed'),
       ('Password reset');

SELECT ticket_id, subject
FROM tickets
ORDER BY ticket_id;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  ticket_id |    subject
-- -----------+----------------
--          1 | Printer jammed
--          2 | Password reset
-- (2 rows)

-- ------------------------------------------------------------
-- Try It 1
-- List the employees who report to Emily Johnson (employee 3).
-- ------------------------------------------------------------
-- 1. Emily's direct reports
SELECT employee_id, first_name, last_name
FROM employees
WHERE manager_id = 3
ORDER BY employee_id;

-- Result:
--  employee_id | first_name | last_name
-- -------------+------------+-----------
--            4 | Michael    | Williams
--            5 | Sarah      | Chen
--            8 | Tom        | Wilson
-- (3 rows)

-- ------------------------------------------------------------
-- Try It 2
-- Assign Tom Wilson (employee 8) to Engineering (30), then show his
-- row. Why does this work when department 99 failed?
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 2. Department 30 exists, so the foreign
--    key is satisfied
UPDATE employees
SET department_id = 30
WHERE employee_id = 8;

SELECT employee_id, first_name, department_id
FROM employees
WHERE employee_id = 8;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  employee_id | first_name | department_id
-- -------------+------------+---------------
--            8 | Tom        |            30
-- (1 row)

-- ------------------------------------------------------------
-- Try It 3
-- Create a throwaway project_members table linking employees to
-- projects, with a composite primary key and a foreign key on each
-- column. Add Michael (4) to the Mobile App (2), then select the
-- row.
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 3. A linking table with a composite key
CREATE TABLE project_members (
    employee_id INT
        REFERENCES employees (employee_id),
    project_id  INT
        REFERENCES projects (project_id),
    PRIMARY KEY (employee_id, project_id)
);

INSERT INTO project_members
    (employee_id, project_id)
VALUES (4, 2);

SELECT employee_id, project_id
FROM project_members;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  employee_id | project_id
-- -------------+------------
--            4 |          2
-- (1 row)

-- ------------------------------------------------------------
-- Example 6: Try It
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

DROP TABLE IF EXISTS tickets, project_members;

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Undo everything this file changed.
-- ------------------------------------------------------------
ROLLBACK;
