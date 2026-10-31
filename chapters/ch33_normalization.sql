-- The Most Helpful SQL Guide, Second Edition
-- Chapter 33: Normalization
--
-- Every example in this chapter that runs on PostgreSQL,
-- in book order, with the result the book prints. Load
-- sample_db.sql first. To run the whole file in psql:
--   psql -d sqlguide -f chapters/ch33_normalization.sql
-- It runs as one transaction and rolls back at the end, so your
-- database is left unchanged. Examples that change data or fail on
-- purpose are wrapped in a savepoint and undone, as in the book.
-- You can also copy any single example into a query window.

BEGIN;

-- ------------------------------------------------------------
-- Example 1: The Trouble with Repeated Facts
-- ------------------------------------------------------------
CREATE TEMPORARY TABLE order_sheet AS
SELECT o.order_id, o.order_date,
       c.customer_id,
       c.first_name || ' ' || c.last_name
           AS customer_name,
       c.city,
       p.product_id, p.product_name, p.category,
       oi.quantity, oi.unit_price
FROM orders o
JOIN customers c
    ON c.customer_id = o.customer_id
JOIN order_items oi
    ON oi.order_id = o.order_id
JOIN products p
    ON p.product_id = oi.product_id;

ALTER TABLE order_sheet
    ADD PRIMARY KEY (order_id, product_id);

SELECT order_id, customer_name, city,
       product_name, category
FROM order_sheet
ORDER BY order_id, product_id;

-- Result:
--  order_id | customer_name |   city   | product_name |  category
-- ----------+---------------+----------+--------------+-------------
--       101 | Alice Brown   | New York | Laptop       | Electronics
--       101 | Alice Brown   | New York | Coffee Mug   | Kitchen
--       102 | Bob Davis     | Chicago  | Smartphone   | Electronics
--       103 | Charlie Evans | New York | Tablet       | Electronics
--       104 | Alice Brown   | New York | Laptop       | Electronics
--       104 | Alice Brown   | New York | Monitor      | Electronics
--       105 | Dana Kim      | Austin   | Coffee Mug   | Kitchen
--       105 | Dana Kim      | Austin   | Desk Chair   | Furniture
--       106 | Charlie Evans | New York | Smartphone   | Electronics
--       106 | Charlie Evans | New York | Monitor      | Electronics
-- (10 rows)

-- ------------------------------------------------------------
-- Example 2: Update anomalies
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

UPDATE order_sheet
SET city = 'Boston'
WHERE order_id = 104;

SELECT order_id, customer_name, city
FROM order_sheet
WHERE customer_id = 1
ORDER BY order_id, product_id;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  order_id | customer_name |   city
-- ----------+---------------+----------
--       101 | Alice Brown   | New York
--       101 | Alice Brown   | New York
--       104 | Alice Brown   | Boston
--       104 | Alice Brown   | Boston
-- (4 rows)

-- ------------------------------------------------------------
-- Example 3: Insert anomalies
-- Fails on purpose, to show the error.
-- ------------------------------------------------------------
SAVEPOINT example;

INSERT INTO order_sheet
    (product_id, product_name, category)
VALUES (7, 'Webcam', 'Electronics');

ROLLBACK TO SAVEPOINT example;

-- Expected error:
--   ERROR:  null value in column "order_id" of relation "order_sheet" violates not-null constraint
--   DETAIL:  Failing row contains (null, null, null, null, null, 7, Webcam, Electronics, null, null).

-- ------------------------------------------------------------
-- Example 4: Delete anomalies
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

DELETE FROM order_sheet
WHERE order_id = 103;

SELECT DISTINCT product_name, category
FROM order_sheet
ORDER BY product_name;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  product_name |  category
-- --------------+-------------
--  Coffee Mug   | Kitchen
--  Desk Chair   | Furniture
--  Laptop       | Electronics
--  Monitor      | Electronics
--  Smartphone   | Electronics
-- (5 rows)

-- ------------------------------------------------------------
-- Example 5: Functional Dependencies
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

UPDATE order_sheet
SET category = 'Computers'
WHERE order_id = 104
    AND product_id = 1;

SELECT product_id,
       STRING_AGG(DISTINCT category, ', '
                  ORDER BY category) AS categories
FROM order_sheet
GROUP BY product_id
HAVING COUNT(DISTINCT category) > 1;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  product_id |       categories
-- ------------+------------------------
--           1 | Computers, Electronics
-- (1 row)

-- ------------------------------------------------------------
-- Example 6: First Normal Form (1NF)
-- Sets up data for the examples that follow.
-- ------------------------------------------------------------
CREATE TEMPORARY TABLE order_lists (
    order_id    INT PRIMARY KEY,
    product_ids INT[] NOT NULL
);

INSERT INTO order_lists (order_id, product_ids)
VALUES
    (101, ARRAY[1, 5]),
    (102, ARRAY[2]),
    (103, ARRAY[3]),
    (104, ARRAY[1, 4]),
    (105, ARRAY[5, 6]),
    (106, ARRAY[2, 4]);

-- ------------------------------------------------------------
-- Example 7: First Normal Form (1NF)
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

UPDATE order_lists
SET product_ids = ARRAY[2, 4, 99]
WHERE order_id = 106;

SELECT order_id
FROM order_lists
WHERE 99 = ANY (product_ids);

ROLLBACK TO SAVEPOINT example;

-- Result:
--  order_id
-- ----------
--       106
-- (1 row)

-- ------------------------------------------------------------
-- Example 8: Second Normal Form (2NF)
-- ------------------------------------------------------------
SELECT DISTINCT order_id, order_date,
       customer_id, customer_name, city
FROM order_sheet
ORDER BY order_id;

-- Result:
--  order_id | order_date | customer_id | customer_name |   city
-- ----------+------------+-------------+---------------+----------
--       101 | 2024-01-15 |           1 | Alice Brown   | New York
--       102 | 2024-01-16 |           2 | Bob Davis     | Chicago
--       103 | 2024-01-17 |           3 | Charlie Evans | New York
--       104 | 2024-02-03 |           1 | Alice Brown   | New York
--       105 | 2024-02-10 |           4 | Dana Kim      | Austin
--       106 | 2024-03-05 |           3 | Charlie Evans | New York
-- (6 rows)

-- ------------------------------------------------------------
-- Try It 1
-- Is the manager a property of the department? Check whether the
-- employees in each department all share one manager_id.
-- ------------------------------------------------------------
-- 1. Departments whose staff have more than
--    one manager
SELECT department_id,
       COUNT(DISTINCT manager_id) AS managers
FROM employees
GROUP BY department_id
HAVING COUNT(DISTINCT manager_id) > 1
ORDER BY department_id;

-- Result:
--  department_id | managers
-- ---------------+----------
--             20 |        2
--             30 |        2
-- (2 rows)

-- ------------------------------------------------------------
-- Try It 2
-- Rebuild the order sheet's rows for order 105 from the sample
-- database's tables.
-- ------------------------------------------------------------
-- 2. Order 105, rebuilt with joins
SELECT o.order_id,
       c.first_name || ' ' || c.last_name
           AS customer_name,
       c.city, p.product_name, p.category
FROM orders o
JOIN customers c
    ON c.customer_id = o.customer_id
JOIN order_items oi
    ON oi.order_id = o.order_id
JOIN products p
    ON p.product_id = oi.product_id
WHERE o.order_id = 105
ORDER BY p.product_id;

-- Result:
--  order_id | customer_name |  city  | product_name | category
-- ----------+---------------+--------+--------------+-----------
--       105 | Dana Kim      | Austin | Coffee Mug   | Kitchen
--       105 | Dana Kim      | Austin | Desk Chair   | Furniture
-- (2 rows)

-- ------------------------------------------------------------
-- Try It 3
-- Delete the cancelled order 103 from the sample database, in a
-- transaction you roll back (Chapter 25). Then show that the Tablet
-- is still in products.
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 3. Delete the lines first, then the order
DELETE FROM order_items
WHERE order_id = 103;

DELETE FROM orders
WHERE order_id = 103;

SELECT product_id, product_name, category
FROM products
WHERE product_id = 3;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  product_id | product_name |  category
-- ------------+--------------+-------------
--           3 | Tablet       | Electronics
-- (1 row)

-- ------------------------------------------------------------
-- Undo everything this file changed.
-- ------------------------------------------------------------
ROLLBACK;
