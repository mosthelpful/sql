-- The Most Helpful SQL Guide, Second Edition
-- Chapter 35: Metadata
--
-- Every example in this chapter that runs on PostgreSQL,
-- in book order, with the result the book prints. Load
-- sample_db.sql first. To run the whole file in psql:
--   psql -d sqlguide -f chapters/ch35_metadata.sql
-- It runs as one transaction and rolls back at the end, so your
-- database is left unchanged. Examples that change data or fail on
-- purpose are wrapped in a savepoint and undone, as in the book.
-- You can also copy any single example into a query window.

BEGIN;

-- ------------------------------------------------------------
-- Example 1: Columns and data types
-- ------------------------------------------------------------
SELECT column_name, data_type,
       character_maximum_length AS max_length,
       numeric_precision AS prec,
       numeric_scale AS scale,
       is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
    AND table_name = 'employees'
ORDER BY ordinal_position;

-- Result:
--   column_name  |     data_type     | max_length | prec | scale | is_nullable
-- ---------------+-------------------+------------+------+-------+-------------
--  employee_id   | integer           |       NULL |   32 |     0 | NO
--  first_name    | character varying |         50 | NULL |  NULL | NO
--  last_name     | character varying |         50 | NULL |  NULL | NO
--  email         | character varying |        100 | NULL |  NULL | NO
--  job_title     | character varying |         50 | NULL |  NULL | NO
--  department_id | integer           |       NULL |   32 |     0 | YES
--  manager_id    | integer           |       NULL |   32 |     0 | YES
--  hire_date     | date              |       NULL | NULL |  NULL | NO
--  salary        | numeric           |       NULL |   10 |     2 | NO
-- (9 rows)

-- ------------------------------------------------------------
-- Example 2: Columns and data types
-- ------------------------------------------------------------
SELECT table_name, column_name
FROM information_schema.columns
WHERE table_schema = 'public'
    AND column_name LIKE '%email%'
ORDER BY table_name;

-- Result:
--  table_name | column_name
-- ------------+-------------
--  customers  | email
--  employees  | email
-- (2 rows)

-- ------------------------------------------------------------
-- Example 3: Keys and constraints
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

CREATE TABLE staging_customers (
    first_name VARCHAR(50),
    last_name  VARCHAR(50),
    email      VARCHAR(100)
);

SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
    AND table_type = 'BASE TABLE'
EXCEPT
SELECT table_name
FROM information_schema.table_constraints
WHERE table_schema = 'public'
    AND constraint_type = 'PRIMARY KEY'
ORDER BY table_name;

ROLLBACK TO SAVEPOINT example;

-- Result:
--     table_name
-- -------------------
--  staging_customers
-- (1 row)

-- ------------------------------------------------------------
-- Example 4: Keys and constraints
-- ------------------------------------------------------------
SELECT fk.table_name, fk.column_name,
       pk.table_name AS ref_table,
       pk.column_name AS ref_column
FROM information_schema.referential_constraints r
JOIN information_schema.key_column_usage fk
    ON fk.constraint_name = r.constraint_name
JOIN information_schema.key_column_usage pk
    ON pk.constraint_name =
           r.unique_constraint_name
    AND pk.ordinal_position =
           fk.position_in_unique_constraint
WHERE r.constraint_schema = 'public'
ORDER BY fk.table_name, fk.column_name;

-- Result:
--  table_name  |  column_name  |  ref_table  |  ref_column
-- -------------+---------------+-------------+---------------
--  employees   | department_id | departments | department_id
--  employees   | manager_id    | employees   | employee_id
--  order_items | order_id      | orders      | order_id
--  order_items | product_id    | products    | product_id
--  orders      | customer_id   | customers   | customer_id
--  projects    | department_id | departments | department_id
-- (6 rows)

-- ------------------------------------------------------------
-- Example 5: PostgreSQL's System Catalog
-- ------------------------------------------------------------
SELECT indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
    AND tablename = 'employees'
ORDER BY indexname;

-- Result:
--       indexname      |                                     indexdef
-- ---------------------+----------------------------------------------------------------------------------
--  employees_email_key | CREATE UNIQUE INDEX employees_email_key ON public.employees USING btree (email)
--  employees_pkey      | CREATE UNIQUE INDEX employees_pkey ON public.employees USING btree (employee_id)
-- (2 rows)

-- ------------------------------------------------------------
-- Example 6: PostgreSQL's System Catalog
-- ------------------------------------------------------------
SELECT conname, contype,
       pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'employees'::regclass
    AND contype <> 'n'
ORDER BY conname;

-- Result:
--            conname            | contype |                            definition
-- ------------------------------+---------+-------------------------------------------------------------------
--  employees_department_id_fkey | f       | FOREIGN KEY (department_id) REFERENCES departments(department_id)
--  employees_email_key          | u       | UNIQUE (email)
--  employees_manager_id_fkey    | f       | FOREIGN KEY (manager_id) REFERENCES employees(employee_id)
--  employees_pkey               | p       | PRIMARY KEY (employee_id)
--  employees_salary_check       | c       | CHECK ((salary > (0)::numeric))
-- (5 rows)

-- ------------------------------------------------------------
-- Example 7: Comments
-- ------------------------------------------------------------
COMMENT ON TABLE employees IS
    'One row per employee';

COMMENT ON COLUMN employees.department_id IS
    'NULL until the employee is assigned';

COMMENT ON COLUMN employees.manager_id IS
    'NULL for the head of the company';

-- Result: COMMENT

-- ------------------------------------------------------------
-- Example 8: Comments
-- ------------------------------------------------------------
SELECT attname AS column_name,
       col_description(attrelid, attnum)
           AS comment
FROM pg_attribute
WHERE attrelid = 'employees'::regclass
    AND col_description(attrelid, attnum)
        IS NOT NULL
ORDER BY attnum;

-- Result:
--   column_name  |               comment
-- ---------------+-------------------------------------
--  department_id | NULL until the employee is assigned
--  manager_id    | NULL for the head of the company
-- (2 rows)

-- ------------------------------------------------------------
-- Example 9: Generating SQL from Metadata
-- ------------------------------------------------------------
SELECT format('CREATE INDEX ON %I.%I (%I);',
              k.table_schema, k.table_name,
              k.column_name) AS statement
FROM information_schema.key_column_usage k
JOIN information_schema.table_constraints t
    ON t.constraint_schema = k.constraint_schema
    AND t.constraint_name = k.constraint_name
WHERE t.constraint_type = 'FOREIGN KEY'
    AND k.table_schema = 'public'
ORDER BY k.table_name, k.column_name;

-- Result:
--                      statement
-- ---------------------------------------------------
--  CREATE INDEX ON public.employees (department_id);
--  CREATE INDEX ON public.employees (manager_id);
--  CREATE INDEX ON public.order_items (order_id);
--  CREATE INDEX ON public.order_items (product_id);
--  CREATE INDEX ON public.orders (customer_id);
--  CREATE INDEX ON public.projects (department_id);
-- (6 rows)

-- ------------------------------------------------------------
-- Try It 1
-- List every column in the public schema that accepts NULL, with its
-- table.
-- ------------------------------------------------------------
-- 1. Columns that accept NULL
SELECT table_name, column_name
FROM information_schema.columns
WHERE table_schema = 'public'
    AND is_nullable = 'YES'
ORDER BY table_name, column_name;

-- Result:
--  table_name |  column_name
-- ------------+---------------
--  customers  | city
--  employees  | department_id
--  employees  | manager_id
-- (3 rows)

-- ------------------------------------------------------------
-- Try It 2
-- Show the definition of each CHECK constraint on products.
-- ------------------------------------------------------------
-- 2. CHECK constraints on products
SELECT conname,
       pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'products'::regclass
    AND contype = 'c'
ORDER BY conname;

-- Result:
--        conname        |           definition
-- ----------------------+---------------------------------
--  products_price_check | CHECK ((price >= (0)::numeric))
--  products_stock_check | CHECK ((stock >= 0))
-- (2 rows)

-- ------------------------------------------------------------
-- Try It 3
-- Generate a statement that counts the rows of each table in the
-- public schema.
-- ------------------------------------------------------------
-- 3. One COUNT(*) per table, names quoted
SELECT format('SELECT COUNT(*) FROM %I.%I;',
              table_schema, table_name)
           AS statement
FROM information_schema.tables
WHERE table_schema = 'public'
    AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- Result:
--                 statement
-- ------------------------------------------
--  SELECT COUNT(*) FROM public.customers;
--  SELECT COUNT(*) FROM public.departments;
--  SELECT COUNT(*) FROM public.employees;
--  SELECT COUNT(*) FROM public.order_items;
--  SELECT COUNT(*) FROM public.orders;
--  SELECT COUNT(*) FROM public.products;
--  SELECT COUNT(*) FROM public.projects;
-- (7 rows)

-- ------------------------------------------------------------
-- Example 10: Try It
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

DROP TABLE IF EXISTS staging_customers;

COMMENT ON TABLE employees IS NULL;
COMMENT ON COLUMN employees.department_id
    IS NULL;
COMMENT ON COLUMN employees.manager_id
    IS NULL;

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Undo everything this file changed.
-- ------------------------------------------------------------
ROLLBACK;
