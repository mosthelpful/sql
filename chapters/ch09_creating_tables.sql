-- The Most Helpful SQL Guide, Second Edition
-- Chapter 9: Creating a Table
--
-- Every example in this part of the book that runs on PostgreSQL,
-- in book order, with the result the book prints. Load
-- sample_db.sql first. To run the whole file in psql:
--   psql -d sqlguide -f chapters/ch09_creating_tables.sql
-- It runs as one transaction and rolls back at the end, so your
-- database is left unchanged. Examples that change data or fail on
-- purpose are wrapped in a savepoint and undone, as in the book.
-- You can also copy any single example into a query window.

BEGIN;

-- ------------------------------------------------------------
-- Example 1: The CREATE TABLE Statement
-- ------------------------------------------------------------
CREATE TABLE suppliers (
    supplier_id   INT PRIMARY KEY,
    supplier_name VARCHAR(50)  NOT NULL UNIQUE,
    email         VARCHAR(100),
    status        VARCHAR(10)  NOT NULL
                  DEFAULT 'active',
    added_on      DATE NOT NULL
                  DEFAULT CURRENT_DATE,
    CONSTRAINT chk_suppliers_status
        CHECK (status IN ('active', 'inactive'))
);

-- Result: CREATE TABLE

-- ------------------------------------------------------------
-- Example 2: Table constraints and foreign keys
-- ------------------------------------------------------------
CREATE TABLE product_suppliers (
    product_id  INT NOT NULL,
    supplier_id INT NOT NULL,
    unit_cost   DECIMAL(10, 2) NOT NULL,
    lead_days   INT NOT NULL DEFAULT 7,
    PRIMARY KEY (product_id, supplier_id),
    CONSTRAINT fk_ps_products
        FOREIGN KEY (product_id)
        REFERENCES products (product_id),
    CONSTRAINT fk_ps_suppliers
        FOREIGN KEY (supplier_id)
        REFERENCES suppliers (supplier_id),
    CONSTRAINT chk_ps_unit_cost
        CHECK (unit_cost > 0)
);

-- Result: CREATE TABLE

-- ------------------------------------------------------------
-- Example 3: Viewing a Table's Structure
-- ------------------------------------------------------------
SELECT column_name, data_type,
       character_maximum_length AS max_length,
       is_nullable
FROM information_schema.columns
WHERE table_name = 'suppliers'
ORDER BY ordinal_position;

-- Result:
--   column_name  |     data_type     | max_length | is_nullable
-- ---------------+-------------------+------------+-------------
--  supplier_id   | integer           |       NULL | NO
--  supplier_name | character varying |         50 | NO
--  email         | character varying |        100 | YES
--  status        | character varying |         10 | NO
--  added_on      | date              |       NULL | NO
-- (5 rows)

-- ------------------------------------------------------------
-- Example 4: Adding Rows
-- ------------------------------------------------------------
INSERT INTO suppliers
    (supplier_id, supplier_name, email)
VALUES (1, 'Apex Electronics',
        'sales@apex.example.com');

-- Result: INSERT 0 1

-- ------------------------------------------------------------
-- Example 5: Adding Rows
-- ------------------------------------------------------------
INSERT INTO suppliers
    (supplier_id, supplier_name, email, status)
VALUES
    (2, 'Hearth Kitchenware', NULL, DEFAULT),
    (3, 'Oakline Furniture',
        'hello@oakline.example.com', 'inactive');

-- Result: INSERT 0 2

-- ------------------------------------------------------------
-- Example 6: Adding Rows
-- ------------------------------------------------------------
INSERT INTO product_suppliers
    (product_id, supplier_id, unit_cost)
VALUES
    (1, 1, 950.00),
    (2, 1, 610.00),
    (5, 2, 4.25),
    (6, 3, 160.00);

-- Result: INSERT 0 4

-- ------------------------------------------------------------
-- Example 7: Checking the rows
-- ------------------------------------------------------------
SELECT supplier_id, supplier_name, email, status
FROM suppliers
ORDER BY supplier_id;

-- Result:
--  supplier_id |   supplier_name    |           email           |  status
-- -------------+--------------------+---------------------------+----------
--            1 | Apex Electronics   | sales@apex.example.com    | active
--            2 | Hearth Kitchenware | NULL                      | active
--            3 | Oakline Furniture  | hello@oakline.example.com | inactive
-- (3 rows)

-- ------------------------------------------------------------
-- Example 8: When a constraint says no
-- Fails on purpose, to show the error.
-- ------------------------------------------------------------
SAVEPOINT example;

INSERT INTO product_suppliers
    (product_id, supplier_id, unit_cost)
VALUES (4, 1, 0);

ROLLBACK TO SAVEPOINT example;

-- Expected error:
--   ERROR:  new row for relation "product_suppliers" violates check constraint "chk_ps_unit_cost"
--   DETAIL:  Failing row contains (4, 1, 0.00, 7).

-- ------------------------------------------------------------
-- Example 9: Changing a Table with ALTER TABLE
-- ------------------------------------------------------------
ALTER TABLE suppliers
    ADD COLUMN phone VARCHAR(20);

-- Result: ALTER TABLE

-- ------------------------------------------------------------
-- Example 10: Changing a Table with ALTER TABLE
-- ------------------------------------------------------------
ALTER TABLE product_suppliers
    ADD CONSTRAINT chk_ps_lead_days
    CHECK (lead_days > 0);

-- Result: ALTER TABLE

-- ------------------------------------------------------------
-- Example 11: Changing a Table with ALTER TABLE
-- ------------------------------------------------------------
ALTER TABLE suppliers
    ALTER COLUMN phone TYPE VARCHAR(30);

-- Result: ALTER TABLE

-- ------------------------------------------------------------
-- Example 12: Generated Columns
-- ------------------------------------------------------------
ALTER TABLE product_suppliers
    ADD COLUMN cost_with_duty DECIMAL(10, 2)
    GENERATED ALWAYS AS (unit_cost * 1.05)
    STORED;

-- Result: ALTER TABLE

-- ------------------------------------------------------------
-- Example 13: Generated Columns
-- ------------------------------------------------------------
SELECT product_id, supplier_id, unit_cost,
       cost_with_duty
FROM product_suppliers
ORDER BY product_id, supplier_id;

-- Result:
--  product_id | supplier_id | unit_cost | cost_with_duty
-- ------------+-------------+-----------+----------------
--           1 |           1 |    950.00 |         997.50
--           2 |           1 |    610.00 |         640.50
--           5 |           2 |      4.25 |           4.46
--           6 |           3 |    160.00 |         168.00
-- (4 rows)

-- ------------------------------------------------------------
-- Example 14: Removing a Table with DROP TABLE
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

DROP TABLE IF EXISTS product_suppliers;
DROP TABLE IF EXISTS suppliers;

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Try It 1
-- Create a warehouses table with a warehouse_id primary key, a
-- required and unique warehouse_name, a required city and a whole-
-- number capacity that must be greater than zero. Name the capacity
-- rule.
-- ------------------------------------------------------------
-- 1. The warehouses table
CREATE TABLE warehouses (
    warehouse_id   INT PRIMARY KEY,
    warehouse_name VARCHAR(50) NOT NULL UNIQUE,
    city           VARCHAR(50) NOT NULL,
    capacity       INT NOT NULL,
    CONSTRAINT chk_warehouses_capacity
        CHECK (capacity > 0)
);

-- Result: CREATE TABLE

-- ------------------------------------------------------------
-- Try It 2
-- In one INSERT, add North Hub in Chicago (capacity 5,000) and South
-- Hub in Austin (capacity 3,500). Then list the warehouses.
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 2. Two warehouses in one INSERT
INSERT INTO warehouses
    (warehouse_id, warehouse_name, city,
     capacity)
VALUES
    (1, 'North Hub', 'Chicago', 5000),
    (2, 'South Hub', 'Austin', 3500);

SELECT warehouse_id, warehouse_name, city,
       capacity
FROM warehouses
ORDER BY warehouse_id;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  warehouse_id | warehouse_name |  city   | capacity
-- --------------+----------------+---------+----------
--             1 | North Hub      | Chicago |     5000
--             2 | South Hub      | Austin  |     3500
-- (2 rows)

-- ------------------------------------------------------------
-- Try It 3
-- Add a manager_id column to warehouses that must refer to an
-- employee.
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 3. A manager for each warehouse
ALTER TABLE warehouses
    ADD COLUMN manager_id INT
    REFERENCES employees (employee_id);

DROP TABLE warehouses;

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Undo everything this file changed.
-- ------------------------------------------------------------
ROLLBACK;
