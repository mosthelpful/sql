-- The Most Helpful SQL Guide, Second Edition
-- Chapter 32: Data Modeling
--
-- Every example in this part of the book that runs on PostgreSQL,
-- in book order, with the result the book prints. Load
-- sample_db.sql first. To run the whole file in psql:
--   psql -d sqlguide -f chapters/ch32_data_modeling.sql
-- It runs as one transaction and rolls back at the end, so your
-- database is left unchanged. Examples that change data or fail on
-- purpose are wrapped in a savepoint and undone, as in the book.
-- You can also copy any single example into a query window.

BEGIN;

-- ------------------------------------------------------------
-- Example 1: Optionality
-- ------------------------------------------------------------
SELECT d.department_name,
       (SELECT COUNT(*)
        FROM employees e
        WHERE e.department_id
              = d.department_id) AS employees,
       (SELECT COUNT(*)
        FROM projects p
        WHERE p.department_id
              = d.department_id) AS projects
FROM departments d
ORDER BY d.department_id;

-- Result:
--  department_name | employees | projects
-- -----------------+-----------+----------
--  Executive       |         1 |        0
--  Finance         |         2 |        1
--  Engineering     |         3 |        2
--  Sales           |         1 |        1
--  Legal           |         0 |        0
-- (5 rows)

-- ------------------------------------------------------------
-- Example 2: Many-to-Many Relationships
-- ------------------------------------------------------------
SELECT p.product_name,
       STRING_AGG(CAST(oi.order_id AS VARCHAR),
                  ', ' ORDER BY oi.order_id)
           AS order_ids
FROM products p
JOIN order_items oi
    ON oi.product_id = p.product_id
GROUP BY p.product_id, p.product_name
ORDER BY p.product_id;

-- Result:
--  product_name | order_ids
-- --------------+-----------
--  Laptop       | 101, 104
--  Smartphone   | 102, 106
--  Tablet       | 103
--  Monitor      | 104, 106
--  Coffee Mug   | 101, 105
--  Desk Chair   | 105
-- (6 rows)

-- ------------------------------------------------------------
-- Example 3: Price at the time of sale
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

UPDATE products
SET price = 1299.00
WHERE product_id = 1;

SELECT oi.order_id, oi.unit_price,
       p.price AS current_price
FROM order_items oi
JOIN products p
    ON p.product_id = oi.product_id
WHERE oi.product_id = 1
ORDER BY oi.order_id;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  order_id | unit_price | current_price
-- ----------+------------+---------------
--       101 |    1200.00 |       1299.00
--       104 |    1200.00 |       1299.00
-- (2 rows)

-- ------------------------------------------------------------
-- Example 4: One-to-One Relationships
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

CREATE TABLE employee_payroll (
    employee_id  INT PRIMARY KEY
        REFERENCES employees (employee_id),
    bank_account VARCHAR(34) NOT NULL
);

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Example 5: CASCADE: the child is part of the parent
-- Fails on purpose, to show the error.
-- ------------------------------------------------------------
SAVEPOINT example;

DELETE FROM orders
WHERE order_id = 103;

ROLLBACK TO SAVEPOINT example;

-- Expected error:
--   ERROR:  update or delete on table "orders" violates foreign key constraint "order_items_order_id_fkey" on table "order_items"
--   DETAIL:  Key (order_id)=(103) is still referenced from table "order_items".

-- ------------------------------------------------------------
-- Example 6: CASCADE: the child is part of the parent
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

ALTER TABLE order_items
    DROP CONSTRAINT order_items_order_id_fkey,
    ADD CONSTRAINT order_items_order_id_fkey
        FOREIGN KEY (order_id)
        REFERENCES orders (order_id)
        ON DELETE CASCADE;

DELETE FROM orders
WHERE order_id = 103;

SELECT order_id, COUNT(*) AS line_count
FROM order_items
GROUP BY order_id
ORDER BY order_id;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  order_id | line_count
-- ----------+------------
--       101 |          2
--       102 |          1
--       104 |          2
--       105 |          2
--       106 |          2
-- (5 rows)

-- ------------------------------------------------------------
-- Example 7: SET NULL: the link is optional
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

ALTER TABLE employees
    DROP CONSTRAINT employees_manager_id_fkey,
    ADD CONSTRAINT employees_manager_id_fkey
        FOREIGN KEY (manager_id)
        REFERENCES employees (employee_id)
        ON DELETE SET NULL;

DELETE FROM employees
WHERE employee_id = 3;

SELECT employee_id, first_name, manager_id
FROM employees
ORDER BY employee_id;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  employee_id | first_name | manager_id
-- -------------+------------+------------
--            1 | John       |       NULL
--            2 | Jane       |          1
--            4 | Michael    |       NULL
--            5 | Sarah      |       NULL
--            6 | David      |          2
--            7 | Priya      |          1
--            8 | Tom        |       NULL
-- (7 rows)

-- ------------------------------------------------------------
-- Try It 1
-- List the employees who manage nobody.
-- ------------------------------------------------------------
-- 1. Employees with no direct reports
SELECT e.employee_id, e.first_name, e.last_name
FROM employees e
WHERE NOT EXISTS (
    SELECT 1
    FROM employees r
    WHERE r.manager_id = e.employee_id
)
ORDER BY e.employee_id;

-- Result:
--  employee_id | first_name | last_name
-- -------------+------------+-----------
--            4 | Michael    | Williams
--            5 | Sarah      | Chen
--            6 | David      | Brown
--            7 | Priya      | Patel
--            8 | Tom        | Wilson
-- (5 rows)

-- ------------------------------------------------------------
-- Try It 2
-- Create a throwaway project_assignments table linking employees to
-- projects, with an hours_per_week column. Deleting a project should
-- delete its assignments. Assign Michael (4) and Sarah (5) to the
-- Mobile App (2), and Sarah to the Data Platform (3). Then, in a
-- transaction you roll back, delete the Mobile App and list the
-- remaining assignments.
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 2. Assignments go with their project
CREATE TABLE project_assignments (
    employee_id    INT NOT NULL
        REFERENCES employees (employee_id),
    project_id     INT NOT NULL
        REFERENCES projects (project_id)
        ON DELETE CASCADE,
    hours_per_week INT NOT NULL,
    PRIMARY KEY (employee_id, project_id)
);

INSERT INTO project_assignments
    (employee_id, project_id, hours_per_week)
VALUES
    (4, 2, 20),
    (5, 2, 10),
    (5, 3, 25);

DELETE FROM projects
WHERE project_id = 2;

SELECT employee_id, project_id, hours_per_week
FROM project_assignments
ORDER BY employee_id, project_id;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  employee_id | project_id | hours_per_week
-- -------------+------------+----------------
--            5 |          3 |             25
-- (1 row)

-- ------------------------------------------------------------
-- Example 8: Try It
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

DROP TABLE IF EXISTS project_assignments,
    employee_payroll;

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Undo everything this file changed.
-- ------------------------------------------------------------
ROLLBACK;
