-- The Most Helpful SQL Guide, Second Edition
-- Chapter 23: Stored Procedures
--
-- Every example in this part of the book that runs on PostgreSQL,
-- in book order, with the result the book prints. Load
-- sample_db.sql first. To run the whole file in psql:
--   psql -d sqlguide -f chapters/ch23_stored_procedures.sql
-- It runs as one transaction and rolls back at the end, so your
-- database is left unchanged. Examples that change data or fail on
-- purpose are wrapped in a savepoint and undone, as in the book.
-- You can also copy any single example into a query window.

BEGIN;

-- ------------------------------------------------------------
-- Example 1: Returning rows from a function
-- Fails on purpose, to show the error.
-- ------------------------------------------------------------
SAVEPOINT example;

CREATE FUNCTION staff_in(dept_id INT)
RETURNS TABLE (employee_id INT,
               first_name VARCHAR(50))
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT employee_id, first_name
    FROM employees
    WHERE department_id = dept_id;
END;
$$;

SELECT employee_id, first_name
FROM staff_in(30)
ORDER BY employee_id;

ROLLBACK TO SAVEPOINT example;

-- Expected error:
--   ERROR:  column reference "employee_id" is ambiguous
--   DETAIL:  It could refer to either a PL/pgSQL variable or a table column.

-- ------------------------------------------------------------
-- Example 2: Returning rows from a function
-- ------------------------------------------------------------
CREATE FUNCTION employees_in(p_dept_id INT)
RETURNS TABLE (employee_id INT,
               first_name  VARCHAR(50),
               last_name   VARCHAR(50),
               salary      DECIMAL(10, 2))
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT e.employee_id, e.first_name,
           e.last_name, e.salary
    FROM employees e
    WHERE e.department_id = p_dept_id;
END;
$$;

-- Result: CREATE FUNCTION

-- ------------------------------------------------------------
-- Example 3: Returning rows from a function
-- ------------------------------------------------------------
SELECT employee_id, first_name, last_name, salary
FROM employees_in(30)
ORDER BY salary DESC, employee_id;

-- Result:
--  employee_id | first_name | last_name |  salary
-- -------------+------------+-----------+-----------
--            3 | Emily      | Johnson   | 105000.00
--            4 | Michael    | Williams  |  92000.00
--            5 | Sarah      | Chen      |  92000.00
-- (3 rows)

-- ------------------------------------------------------------
-- Example 4: Variables, conditions and loops
-- ------------------------------------------------------------
CREATE PROCEDURE ship_order(p_order_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_status VARCHAR(12);
    v_item   RECORD;
BEGIN
    SELECT status INTO v_status
    FROM orders
    WHERE order_id = p_order_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order % not found',
            p_order_id;
    END IF;

    CASE v_status
        WHEN 'processing' THEN
            NULL;  -- ready to ship
        WHEN 'shipped', 'cancelled' THEN
            RAISE EXCEPTION
                'Order % is already %',
                p_order_id, v_status;
    END CASE;

    FOR v_item IN
        SELECT oi.product_id, oi.quantity,
               p.product_name, p.stock
        FROM order_items oi
        JOIN products p
            ON p.product_id = oi.product_id
        WHERE oi.order_id = p_order_id
    LOOP
        IF v_item.quantity > v_item.stock THEN
            RAISE EXCEPTION
                'Not enough % in stock',
                v_item.product_name;
        END IF;

        UPDATE products
        SET stock = stock - v_item.quantity
        WHERE product_id = v_item.product_id;
    END LOOP;

    UPDATE orders
    SET status = 'shipped'
    WHERE order_id = p_order_id;
END;
$$;

-- Result: CREATE PROCEDURE

-- ------------------------------------------------------------
-- Example 5: Variables, conditions and loops
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

CALL ship_order(105);

SELECT o.order_id, o.status, p.product_name,
       oi.quantity, p.stock
FROM orders o
JOIN order_items oi
    ON oi.order_id = o.order_id
JOIN products p
    ON p.product_id = oi.product_id
WHERE o.order_id = 105
ORDER BY p.product_id;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  order_id | status  | product_name | quantity | stock
-- ----------+---------+--------------+----------+-------
--       105 | shipped | Coffee Mug   |        4 |    96
--       105 | shipped | Desk Chair   |        1 |     7
-- (2 rows)

-- ------------------------------------------------------------
-- Example 6: Validating input
-- ------------------------------------------------------------
CREATE PROCEDURE add_employee(
    p_employee_id INT,
    p_first_name  VARCHAR(50),
    p_last_name   VARCHAR(50),
    p_job_title   VARCHAR(50),
    p_dept_id     INT,
    p_salary      DECIMAL(10, 2))
LANGUAGE plpgsql
AS $$
DECLARE
    v_email VARCHAR(100);
BEGIN
    IF p_salary IS NULL OR p_salary <= 0 THEN
        RAISE EXCEPTION 'Salary must be positive';
    ELSIF NOT EXISTS (
        SELECT 1 FROM departments
        WHERE department_id = p_dept_id
    ) THEN
        RAISE EXCEPTION 'Department % not found',
            p_dept_id;
    END IF;

    v_email := LOWER(p_first_name || '.'
                     || p_last_name)
               || '@example.com';

    INSERT INTO employees
        (employee_id, first_name, last_name,
         email, job_title, department_id,
         hire_date, salary)
    VALUES
        (p_employee_id, p_first_name, p_last_name,
         v_email, p_job_title, p_dept_id,
         CURRENT_DATE, p_salary);
END;
$$;

-- Result: CREATE PROCEDURE

-- ------------------------------------------------------------
-- Example 7: Validating input
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

CALL add_employee(9, 'Lena', 'Park',
                  'Paralegal', 50, 52000);

SELECT employee_id, first_name, email,
       department_id, salary
FROM employees
WHERE department_id = 50;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  employee_id | first_name |         email         | department_id |  salary
-- -------------+------------+-----------------------+---------------+----------
--            9 | Lena       | lena.park@example.com |            50 | 52000.00
-- (1 row)

-- ------------------------------------------------------------
-- Example 8: Validating input
-- Fails on purpose, to show the error.
-- ------------------------------------------------------------
SAVEPOINT example;

CALL add_employee(9, 'Lena', 'Park',
                  'Paralegal', 99, 52000);

ROLLBACK TO SAVEPOINT example;

-- Expected error:
--   ERROR:  Department 99 not found

-- ------------------------------------------------------------
-- Example 9: A Repeatable Batch Job
-- ------------------------------------------------------------
CREATE TABLE daily_sales (
    sale_date   DATE PRIMARY KEY,
    order_count INT            NOT NULL,
    revenue     DECIMAL(12, 2) NOT NULL
);

-- Result: CREATE TABLE

-- ------------------------------------------------------------
-- Example 10: A Repeatable Batch Job
-- ------------------------------------------------------------
CREATE PROCEDURE refresh_daily_sales(
    p_from DATE,
    p_to   DATE)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO daily_sales
        (sale_date, order_count, revenue)
    SELECT o.order_date,
           COUNT(DISTINCT o.order_id),
           SUM(oi.quantity * oi.unit_price)
    FROM orders o
    JOIN order_items oi
        ON oi.order_id = o.order_id
    WHERE o.order_date >= p_from
        AND o.order_date < p_to
        AND o.status <> 'cancelled'
    GROUP BY o.order_date
    ON CONFLICT (sale_date) DO UPDATE
    SET order_count = EXCLUDED.order_count,
        revenue     = EXCLUDED.revenue;
END;
$$;

-- Result: CREATE PROCEDURE

-- ------------------------------------------------------------
-- Example 11: A Repeatable Batch Job
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

CALL refresh_daily_sales(DATE '2024-01-01',
                         DATE '2024-02-01');

UPDATE order_items
SET quantity = 2
WHERE order_id = 102;

CALL refresh_daily_sales(DATE '2024-01-01',
                         DATE '2024-02-01');

SELECT sale_date, order_count, revenue
FROM daily_sales
ORDER BY sale_date;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  sale_date  | order_count | revenue
-- ------------+-------------+---------
--  2024-01-15 |           1 | 1221.98
--  2024-01-16 |           1 | 1600.00
-- (2 rows)

-- ------------------------------------------------------------
-- Example 12: Security
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

ALTER PROCEDURE add_employee
    SECURITY DEFINER
    SET search_path = public, pg_temp;

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Try It 1
-- Use employees_in to list the Finance employees (department 20) who
-- earn more than 70,000.
-- ------------------------------------------------------------
-- 1. Finance employees earning over 70,000
SELECT employee_id, first_name, last_name, salary
FROM employees_in(20)
WHERE salary > 70000
ORDER BY employee_id;

-- Result:
--  employee_id | first_name | last_name |  salary
-- -------------+------------+-----------+----------
--            2 | Jane       | Smith     | 88000.00
-- (1 row)

-- ------------------------------------------------------------
-- Try It 2
-- Write a procedure restock(p_product_id, p_quantity) that adds
-- stock to a product. It should reject a quantity of zero or less,
-- and a product that doesn't exist. Use it to add 20 Desk Chairs
-- (product 6).
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 2. FOUND is false if the UPDATE changed
--    no rows
CREATE PROCEDURE restock(p_product_id INT,
                         p_quantity   INT)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_quantity IS NULL OR p_quantity <= 0 THEN
        RAISE EXCEPTION
            'Quantity must be positive';
    END IF;

    UPDATE products
    SET stock = stock + p_quantity
    WHERE product_id = p_product_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Product % not found',
            p_product_id;
    END IF;
END;
$$;

CALL restock(6, 20);

SELECT product_id, product_name, stock
FROM products
WHERE product_id = 6;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  product_id | product_name | stock
-- ------------+--------------+-------
--           6 | Desk Chair   |    28
-- (1 row)

-- ------------------------------------------------------------
-- Example 13: Try It
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

DROP PROCEDURE ship_order, add_employee,
    refresh_daily_sales;
DROP PROCEDURE IF EXISTS restock;
DROP FUNCTION employees_in;
DROP FUNCTION IF EXISTS staff_in;
DROP TABLE daily_sales;

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Undo everything this file changed.
-- ------------------------------------------------------------
ROLLBACK;
