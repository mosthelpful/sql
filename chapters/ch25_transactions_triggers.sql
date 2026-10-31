-- The Most Helpful SQL Guide, Second Edition
-- Chapter 25: Transactions, Triggers and Assertions
--
-- Every example in this chapter that runs on PostgreSQL,
-- in book order, with the result the book prints. Load
-- sample_db.sql first. To run the whole file in psql:
--   psql -d sqlguide -f chapters/ch25_transactions_triggers.sql
-- It runs as one transaction and rolls back at the end, so your
-- database is left unchanged. Examples that change data or fail on
-- purpose are wrapped in a savepoint and undone, as in the book.
-- You can also copy any single example into a query window.

BEGIN;

-- ------------------------------------------------------------
-- Example 1: Transactions
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

INSERT INTO orders
    (order_id, customer_id, order_date, status)
VALUES (107, 4, DATE '2024-03-20', 'processing');

INSERT INTO order_items
    (order_id, product_id, quantity, unit_price)
VALUES (107, 6, 2, 249.00);

UPDATE products
SET stock = stock - 2
WHERE product_id = 6;

SELECT oi.order_id, p.product_name,
       oi.quantity, p.stock
FROM order_items oi
JOIN products p
    ON p.product_id = oi.product_id
WHERE oi.order_id = 107;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  order_id | product_name | quantity | stock
-- ----------+--------------+----------+-------
--       107 | Desk Chair   |        2 |     6
-- (1 row)

-- ------------------------------------------------------------
-- Example 2: When a statement fails
-- Fails on purpose, to show the error.
-- ------------------------------------------------------------
SAVEPOINT example;

INSERT INTO orders
    (order_id, customer_id, order_date, status)
VALUES (108, 1, DATE '2024-03-21', 'processing');

INSERT INTO order_items
    (order_id, product_id, quantity, unit_price)
VALUES (108, 6, 10, 249.00);

UPDATE products
SET stock = stock - 10
WHERE product_id = 6;

ROLLBACK TO SAVEPOINT example;

-- Expected error:
--   ERROR:  new row for relation "products" violates check constraint "products_stock_check"
--   DETAIL:  Failing row contains (6, Desk Chair, Furniture, 249.00, -2).

-- ------------------------------------------------------------
-- Example 3: Fix 1: test and change in one statement
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

UPDATE products
SET stock = stock - 10
WHERE product_id = 6
    AND stock >= 10;

ROLLBACK TO SAVEPOINT example;

-- Result: UPDATE 0

-- ------------------------------------------------------------
-- Example 4: An audit trail
-- ------------------------------------------------------------
CREATE TABLE employee_salary_audit (
    audit_id    INT GENERATED ALWAYS AS IDENTITY
                PRIMARY KEY,
    employee_id INT NOT NULL,
    old_salary  DECIMAL(10, 2) NOT NULL,
    new_salary  DECIMAL(10, 2) NOT NULL,
    changed_at  TIMESTAMP WITH TIME ZONE NOT NULL
                DEFAULT CURRENT_TIMESTAMP,
    changed_by  VARCHAR(63) NOT NULL
                DEFAULT CURRENT_USER
);

-- Result: CREATE TABLE

-- ------------------------------------------------------------
-- Example 5: An audit trail
-- ------------------------------------------------------------
CREATE FUNCTION log_salary_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO employee_salary_audit
        (employee_id, old_salary, new_salary)
    VALUES (OLD.employee_id, OLD.salary,
            NEW.salary);
    RETURN NULL;
END;
$$;

-- Result: CREATE FUNCTION

-- ------------------------------------------------------------
-- Example 6: An audit trail
-- ------------------------------------------------------------
CREATE TRIGGER employees_salary_audit
AFTER UPDATE OF salary ON employees
FOR EACH ROW
WHEN (OLD.salary IS DISTINCT FROM NEW.salary)
EXECUTE FUNCTION log_salary_change();

-- Result: CREATE TRIGGER

-- ------------------------------------------------------------
-- Example 7: An audit trail
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

UPDATE employees
SET salary = salary * 1.05
WHERE department_id = 30;

SELECT employee_id, old_salary, new_salary
FROM employee_salary_audit
ORDER BY employee_id;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  employee_id | old_salary | new_salary
-- -------------+------------+------------
--            3 |  105000.00 |  110250.00
--            4 |   92000.00 |   96600.00
--            5 |   92000.00 |   96600.00
-- (3 rows)

-- ------------------------------------------------------------
-- Example 8: BEFORE triggers
-- ------------------------------------------------------------
CREATE FUNCTION lowercase_email()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.email := LOWER(NEW.email);
    RETURN NEW;
END;
$$;

CREATE TRIGGER customers_lowercase_email
BEFORE INSERT OR UPDATE OF email ON customers
FOR EACH ROW
EXECUTE FUNCTION lowercase_email();

-- Result: CREATE TRIGGER

-- ------------------------------------------------------------
-- Example 9: BEFORE triggers
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

INSERT INTO customers
    (customer_id, first_name, last_name, email,
     city, status, created_on)
VALUES (6, 'Fiona', 'Lee',
        'Fiona.Lee@Example.COM', 'Boston',
        'active', DATE '2024-06-01');

SELECT customer_id, first_name, email
FROM customers
WHERE customer_id = 6;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  customer_id | first_name |         email
-- -------------+------------+-----------------------
--            6 | Fiona      | fiona.lee@example.com
-- (1 row)

-- ------------------------------------------------------------
-- Example 10: A history table with a trigger
-- ------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE product_history (
    product_id   INT NOT NULL,
    product_name VARCHAR(50) NOT NULL,
    price        DECIMAL(10, 2) NOT NULL,
    valid_period TSTZRANGE NOT NULL,
    EXCLUDE USING gist (
        product_id WITH =,
        valid_period WITH &&)
);

-- Result: CREATE TABLE

-- ------------------------------------------------------------
-- Example 11: A history table with a trigger
-- ------------------------------------------------------------
CREATE FUNCTION save_product_version()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_from TIMESTAMP WITH TIME ZONE;
BEGIN
    IF TG_OP = 'UPDATE'
        AND NEW.price = OLD.price
        AND NEW.product_name = OLD.product_name
    THEN
        RETURN NULL;
    END IF;

    SELECT MAX(UPPER(valid_period))
    INTO v_from
    FROM product_history
    WHERE product_id = OLD.product_id;

    INSERT INTO product_history
        (product_id, product_name, price,
         valid_period)
    VALUES (OLD.product_id, OLD.product_name,
            OLD.price, TSTZRANGE(v_from, now()));
    RETURN NULL;
END;
$$;

CREATE TRIGGER products_save_version
AFTER UPDATE OF price, product_name
    OR DELETE ON products
FOR EACH ROW
EXECUTE FUNCTION save_product_version();

-- Result: CREATE TRIGGER

-- ------------------------------------------------------------
-- Example 12: A history table with a trigger
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

UPDATE products
SET price = 1250.00
WHERE product_id = 1;

SELECT product_id, price,
       LOWER_INF(valid_period) AS from_start,
       UPPER(valid_period) = now() AS ended_now
FROM product_history;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  product_id |  price  | from_start | ended_now
-- ------------+---------+------------+-----------
--           1 | 1200.00 | true       | true
-- (1 row)

-- ------------------------------------------------------------
-- Example 13: Asking "as of" a date
-- Sets up data for the examples that follow.
-- ------------------------------------------------------------
INSERT INTO product_history
    (product_id, product_name, price,
     valid_period)
VALUES
    (1, 'Laptop', 1100.00, TSTZRANGE(
        TIMESTAMPTZ '2023-11-01 00:00+00',
        TIMESTAMPTZ '2024-01-15 00:00+00')),
    (1, 'Laptop', 1150.00, TSTZRANGE(
        TIMESTAMPTZ '2024-01-15 00:00+00',
        TIMESTAMPTZ '2024-03-01 00:00+00'));

-- ------------------------------------------------------------
-- Example 14: Asking "as of" a date
-- ------------------------------------------------------------
CREATE FUNCTION product_price_as_of(
    p_id INT,
    p_at TIMESTAMP WITH TIME ZONE)
RETURNS DECIMAL(10, 2)
LANGUAGE sql
RETURN COALESCE(
    (SELECT h.price
     FROM product_history h
     WHERE h.product_id = p_id
         AND h.valid_period @> p_at),
    (SELECT p.price
     FROM products p
     WHERE p.product_id = p_id
         AND NOT EXISTS (
             SELECT 1
             FROM product_history h
             WHERE h.product_id = p_id
                 AND UPPER(h.valid_period)
                     > p_at)));

-- Result: CREATE FUNCTION

-- ------------------------------------------------------------
-- Example 15: Asking "as of" a date
-- ------------------------------------------------------------
SELECT product_price_as_of(1,
           TIMESTAMPTZ '2023-10-01 00:00+00')
           AS oct_1,
       product_price_as_of(1,
           TIMESTAMPTZ '2024-02-01 00:00+00')
           AS feb_1,
       product_price_as_of(1,
           TIMESTAMPTZ '2024-03-01 00:00+00')
           AS mar_1;

-- Result:
--  oct_1 |  feb_1  |  mar_1
-- -------+---------+---------
--  NULL  | 1150.00 | 1200.00
-- (1 row)

-- ------------------------------------------------------------
-- Example 16: Asking "as of" a date
-- Fails on purpose, to show the error.
-- ------------------------------------------------------------
SAVEPOINT example;

INSERT INTO product_history
    (product_id, product_name, price,
     valid_period)
VALUES (1, 'Laptop', 1175.00, TSTZRANGE(
    TIMESTAMPTZ '2024-02-01 00:00+00',
    TIMESTAMPTZ '2024-02-15 00:00+00'));

ROLLBACK TO SAVEPOINT example;

-- Expected error:
--   ERROR:  conflicting key value violates exclusion constraint "product_history_product_id_valid_period_excl"
--   DETAIL:  Key (product_id, valid_period)=(1, ["2024-02-01 00:00:00+00","2024-02-15 00:00:00+00")) conflicts with existing key (product_id, valid_period)=(1, ["2024-01-15 00:00:00+00","2024-03-01 00:00:00+00")).

-- ------------------------------------------------------------
-- Try It 1
-- Cancel order 105: in a transaction you roll back, mark it
-- cancelled and put its items back in stock. Show the stock of the
-- products involved.
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 1. Cancel order 105 and restock its items.
--    Run both UPDATEs as one transaction.
UPDATE orders
SET status = 'cancelled'
WHERE order_id = 105;

UPDATE products
SET stock = stock + (
        SELECT oi.quantity
        FROM order_items oi
        WHERE oi.order_id = 105
            AND oi.product_id =
                products.product_id)
WHERE product_id IN (
        SELECT product_id
        FROM order_items
        WHERE order_id = 105);

SELECT product_id, product_name, stock
FROM products
WHERE product_id IN (5, 6)
ORDER BY product_id;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  product_id | product_name | stock
-- ------------+--------------+-------
--           5 | Coffee Mug   |   104
--           6 | Desk Chair   |     9
-- (2 rows)

-- ------------------------------------------------------------
-- Try It 2
-- Write a BEFORE trigger that removes spaces from both ends of
-- product names when products are inserted or renamed. Test it by
-- adding a Desk Lamp as product 7.
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 2. Trim product names before they're stored
CREATE FUNCTION trim_product_name()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.product_name := TRIM(NEW.product_name);
    RETURN NEW;
END;
$$;

CREATE TRIGGER products_trim_name
BEFORE INSERT OR UPDATE OF product_name
    ON products
FOR EACH ROW
EXECUTE FUNCTION trim_product_name();

INSERT INTO products
    (product_id, product_name, category,
     price, stock)
VALUES (7, '  Desk Lamp ', 'Furniture',
        39.99, 20);

SELECT product_id, product_name,
       LENGTH(product_name) AS name_length
FROM products
WHERE product_id = 7;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  product_id | product_name | name_length
-- ------------+--------------+-------------
--           7 | Desk Lamp    |           9
-- (1 row)

-- ------------------------------------------------------------
-- Example 17: Try It
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

DROP TRIGGER employees_salary_audit
    ON employees;
DROP TRIGGER customers_lowercase_email
    ON customers;
DROP TRIGGER IF EXISTS products_trim_name
    ON products;
DROP TRIGGER products_save_version
    ON products;
DROP FUNCTION log_salary_change,
    lowercase_email, save_product_version,
    product_price_as_of;
DROP FUNCTION IF EXISTS trim_product_name;
DROP TABLE employee_salary_audit,
    product_history;
-- Skip this if you used btree_gist before
DROP EXTENSION btree_gist;

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Undo everything this file changed.
-- ------------------------------------------------------------
ROLLBACK;
