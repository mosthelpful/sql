-- The Most Helpful SQL Guide, Second Edition
-- Chapter 26: Error Handling
--
-- Every example in this part of the book that runs on PostgreSQL,
-- in book order, with the result the book prints. Load
-- sample_db.sql first. To run the whole file in psql:
--   psql -d sqlguide -f chapters/ch26_error_handling.sql
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

SELCT first_name, last_name
FROM employees;

ROLLBACK TO SAVEPOINT example;

-- Expected error:
--   ERROR:  syntax error at or near "SELCT"

-- ------------------------------------------------------------
-- Example 2: Constraint violations
-- Fails on purpose, to show the error.
-- ------------------------------------------------------------
SAVEPOINT example;

INSERT INTO departments
    (department_id, department_name)
VALUES (60, NULL);

ROLLBACK TO SAVEPOINT example;

-- Expected error:
--   ERROR:  null value in column "department_name" of relation "departments" violates not-null constraint
--   DETAIL:  Failing row contains (60, null).

-- ------------------------------------------------------------
-- Example 3: Data type errors
-- Fails on purpose, to show the error.
-- ------------------------------------------------------------
SAVEPOINT example;

UPDATE products
SET price = 123456789.00
WHERE product_id = 1;

ROLLBACK TO SAVEPOINT example;

-- Expected error:
--   ERROR:  numeric field overflow
--   DETAIL:  A field with precision 10, scale 2 must round to an absolute value less than 10^8.

-- ------------------------------------------------------------
-- Example 4: Division by zero
-- Fails on purpose, to show the error.
-- ------------------------------------------------------------
SAVEPOINT example;

SELECT 12000 / COUNT(*) AS per_person
FROM employees
WHERE department_id = 50;

ROLLBACK TO SAVEPOINT example;

-- Expected error:
--   ERROR:  division by zero

-- ------------------------------------------------------------
-- Example 5: Mistakes that don't raise errors
-- ------------------------------------------------------------
SELECT LENGTH('one\ntwo') AS backslash_n,
       LENGTH(E'one\ntwo') AS e_string,
       LENGTH('one' || CHR(10) || 'two')
           AS with_chr;

-- Result:
--  backslash_n | e_string | with_chr
-- -------------+----------+----------
--            8 |        7 |        7
-- (1 row)

-- ------------------------------------------------------------
-- Example 6: Handling Errors in PL/pgSQL
-- ------------------------------------------------------------
CREATE FUNCTION safe_add_department(
    p_id   INT,
    p_name VARCHAR(50))
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_constraint TEXT;
BEGIN
    INSERT INTO departments
        (department_id, department_name)
    VALUES (p_id, p_name);
    RETURN 'added';
EXCEPTION
    WHEN unique_violation THEN
        GET STACKED DIAGNOSTICS
            v_constraint = CONSTRAINT_NAME;
        RETURN 'exists: ' || v_constraint;
END;
$$;

-- Result: CREATE FUNCTION

-- ------------------------------------------------------------
-- Example 7: Handling Errors in PL/pgSQL
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

SELECT v.call_no, v.dept_id, v.dept_name,
       safe_add_department(v.dept_id,
                           v.dept_name) AS result
FROM (VALUES (1, 60, 'Marketing'),
             (2, 60, 'Marketing'),
             (3, 70, 'Finance'))
     v (call_no, dept_id, dept_name)
ORDER BY v.call_no;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  call_no | dept_id | dept_name |                 result
-- ---------+---------+-----------+-----------------------------------------
--        1 |      60 | Marketing | added
--        2 |      60 | Marketing | exists: departments_pkey
--        3 |      70 | Finance   | exists: departments_department_name_key
-- (3 rows)

-- ------------------------------------------------------------
-- Try It 1
-- Try to set Tom Wilson's (employee 8) salary to 0. Which constraint
-- stops it, and what is the SQLSTATE?
-- Fails on purpose, to show the error.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 1. employees_salary_check, the CHECK
--    (salary > 0): SQLSTATE 23514,
--    check_violation
UPDATE employees
SET salary = 0
WHERE employee_id = 8;

ROLLBACK TO SAVEPOINT example;

-- Expected error:
--   ERROR:  new row for relation "employees" violates check constraint "employees_salary_check"
--   DETAIL:  Failing row contains (8, Tom, Wilson, tom.wilson@example.com, Data Analyst, null, 3, 2024-01-08, 0.00).

-- ------------------------------------------------------------
-- Try It 2
-- Write a function set_salary(p_employee_id, p_salary) that returns
-- 'updated', 'no such employee' or 'invalid salary' (by catching
-- check_violation). Call it for employee 8 with 75,000, employee 8
-- with 0 and employee 99.
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 2. FOUND is false if no row was updated
CREATE FUNCTION set_salary(p_employee_id INT,
                           p_salary DECIMAL)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE employees
    SET salary = p_salary
    WHERE employee_id = p_employee_id;

    IF NOT FOUND THEN
        RETURN 'no such employee';
    END IF;
    RETURN 'updated';
EXCEPTION
    WHEN check_violation THEN
        RETURN 'invalid salary';
END;
$$;

SELECT v.call_no, v.emp_id, v.amount,
       set_salary(v.emp_id, v.amount) AS result
FROM (VALUES (1, 8, 75000),
             (2, 8, 0),
             (3, 99, 75000))
     v (call_no, emp_id, amount)
ORDER BY v.call_no;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  call_no | emp_id | amount |      result
-- ---------+--------+--------+------------------
--        1 |      8 |  75000 | updated
--        2 |      8 |      0 | invalid salary
--        3 |     99 |  75000 | no such employee
-- (3 rows)

-- ------------------------------------------------------------
-- Example 8: Try It
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

DROP FUNCTION safe_add_department;
DROP FUNCTION IF EXISTS set_salary;

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Undo everything this file changed.
-- ------------------------------------------------------------
ROLLBACK;
