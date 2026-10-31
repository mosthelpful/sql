-- The Most Helpful SQL Guide, Second Edition
-- Chapter 20: CASE Expressions
--
-- Every example in this chapter that runs on PostgreSQL,
-- in book order, with the result the book prints. Load
-- sample_db.sql first. To run the whole file in psql:
--   psql -d sqlguide -f chapters/ch20_case.sql
-- It runs as one transaction and rolls back at the end, so your
-- database is left unchanged. Examples that change data or fail on
-- purpose are wrapped in a savepoint and undone, as in the book.
-- You can also copy any single example into a query window.

BEGIN;

-- ------------------------------------------------------------
-- Example 1: Searched CASE
-- ------------------------------------------------------------
SELECT product_name, price,
       CASE
           WHEN price < 100 THEN 'Budget'
           WHEN price < 500 THEN 'Mid-range'
           ELSE 'Premium'
       END AS price_band
FROM products
ORDER BY price;

-- Result:
--  product_name |  price  | price_band
-- --------------+---------+------------
--  Coffee Mug   |   10.99 | Budget
--  Desk Chair   |  249.00 | Mid-range
--  Monitor      |  300.00 | Mid-range
--  Tablet       |  450.00 | Mid-range
--  Smartphone   |  800.00 | Premium
--  Laptop       | 1200.00 | Premium
-- (6 rows)

-- ------------------------------------------------------------
-- Example 2: The first true WHEN wins
-- ------------------------------------------------------------
SELECT product_name, price,
       CASE
           WHEN price < 500 THEN 'Mid-range'
           WHEN price < 100 THEN 'Budget'
           ELSE 'Premium'
       END AS price_band
FROM products
ORDER BY price;

-- Result:
--  product_name |  price  | price_band
-- --------------+---------+------------
--  Coffee Mug   |   10.99 | Mid-range
--  Desk Chair   |  249.00 | Mid-range
--  Monitor      |  300.00 | Mid-range
--  Tablet       |  450.00 | Mid-range
--  Smartphone   |  800.00 | Premium
--  Laptop       | 1200.00 | Premium
-- (6 rows)

-- ------------------------------------------------------------
-- Example 3: Simple CASE
-- ------------------------------------------------------------
SELECT order_id, status,
       CASE status
           WHEN 'processing' THEN 'Being packed'
           WHEN 'shipped' THEN 'On its way'
           WHEN 'cancelled' THEN 'Cancelled'
       END AS customer_message
FROM orders
ORDER BY order_id;

-- Result:
--  order_id |   status   | customer_message
-- ----------+------------+------------------
--       101 | shipped    | On its way
--       102 | shipped    | On its way
--       103 | cancelled  | Cancelled
--       104 | shipped    | On its way
--       105 | processing | Being packed
--       106 | shipped    | On its way
-- (6 rows)

-- ------------------------------------------------------------
-- Example 4: ELSE and NULL
-- ------------------------------------------------------------
SELECT first_name, hire_date,
       CASE
           WHEN hire_date < DATE '2018-01-01'
               THEN 'Senior'
           WHEN hire_date < DATE '2022-01-01'
               THEN 'Mid-level'
       END AS seniority
FROM employees
ORDER BY hire_date;

-- Result:
--  first_name | hire_date  | seniority
-- ------------+------------+-----------
--  John       | 2015-06-15 | Senior
--  Jane       | 2016-09-23 | Senior
--  Emily      | 2017-03-11 | Senior
--  Michael    | 2018-05-29 | Mid-level
--  David      | 2019-11-12 | Mid-level
--  Sarah      | 2020-02-03 | Mid-level
--  Priya      | 2021-08-30 | Mid-level
--  Tom        | 2024-01-08 | NULL
-- (8 rows)

-- ------------------------------------------------------------
-- Example 5: A custom sort order
-- ------------------------------------------------------------
SELECT order_id, order_date, status
FROM orders
ORDER BY CASE status
             WHEN 'processing' THEN 1
             WHEN 'shipped' THEN 2
             WHEN 'cancelled' THEN 3
         END,
         order_date;

-- Result:
--  order_id | order_date |   status
-- ----------+------------+------------
--       105 | 2024-02-10 | processing
--       101 | 2024-01-15 | shipped
--       102 | 2024-01-16 | shipped
--       104 | 2024-02-03 | shipped
--       106 | 2024-03-05 | shipped
--       103 | 2024-01-17 | cancelled
-- (6 rows)

-- ------------------------------------------------------------
-- Example 6: Grouping by a CASE expression
-- ------------------------------------------------------------
SELECT CASE
           WHEN price < 100 THEN 'Budget'
           WHEN price < 500 THEN 'Mid-range'
           ELSE 'Premium'
       END AS price_band,
       COUNT(*) AS products
FROM products
GROUP BY CASE
             WHEN price < 100 THEN 'Budget'
             WHEN price < 500 THEN 'Mid-range'
             ELSE 'Premium'
         END
ORDER BY MIN(price);

-- Result:
--  price_band | products
-- ------------+----------
--  Budget     |        1
--  Mid-range  |        3
--  Premium    |        2
-- (3 rows)

-- ------------------------------------------------------------
-- Example 7: Conditional aggregation
-- ------------------------------------------------------------
SELECT c.first_name,
       SUM(CASE WHEN o.status = 'shipped'
                THEN 1 ELSE 0 END) AS shipped,
       SUM(CASE WHEN o.status = 'processing'
                THEN 1 ELSE 0 END) AS processing,
       SUM(CASE WHEN o.status = 'cancelled'
                THEN 1 ELSE 0 END) AS cancelled
FROM customers c
JOIN orders o
    ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name
ORDER BY c.customer_id;

-- Result:
--  first_name | shipped | processing | cancelled
-- ------------+---------+------------+-----------
--  Alice      |       2 |          0 |         0
--  Bob        |       1 |          0 |         0
--  Charlie    |       1 |          0 |         1
--  Dana       |       0 |          1 |         0
-- (4 rows)

-- ------------------------------------------------------------
-- Example 8: 1. Testing for NULL with the simple form
-- ------------------------------------------------------------
SELECT first_name, city,
       CASE city
           WHEN NULL THEN 'Unknown'
           ELSE city
       END AS simple_form,
       CASE
           WHEN city IS NULL THEN 'Unknown'
           ELSE city
       END AS searched_form
FROM customers
ORDER BY customer_id;

-- Result:
--  first_name |   city   | simple_form | searched_form
-- ------------+----------+-------------+---------------
--  Alice      | New York | New York    | New York
--  Bob        | Chicago  | Chicago     | Chicago
--  Charlie    | New York | New York    | New York
--  Dana       | Austin   | Austin      | Austin
--  Ethan      | NULL     | NULL        | Unknown
-- (5 rows)

-- ------------------------------------------------------------
-- Example 9: 2. Mixing data types
-- Fails on purpose, to show the error.
-- ------------------------------------------------------------
SAVEPOINT example;

SELECT product_name,
       CASE
           WHEN stock < 20 THEN 'Low'
           ELSE stock
       END AS stock_level
FROM products
ORDER BY product_id;

ROLLBACK TO SAVEPOINT example;

-- Expected error:
--   ERROR:  invalid input syntax for type integer: "Low"

-- ------------------------------------------------------------
-- Try It 1
-- Label each product's stock as Low (under 20), OK (20 to 49) or
-- Plenty (50 or more).
-- ------------------------------------------------------------
-- 1. Stock levels
SELECT product_name, stock,
       CASE
           WHEN stock < 20 THEN 'Low'
           WHEN stock < 50 THEN 'OK'
           ELSE 'Plenty'
       END AS stock_level
FROM products
ORDER BY product_id;

-- Result:
--  product_name | stock | stock_level
-- --------------+-------+-------------
--  Laptop       |    15 | Low
--  Smartphone   |    40 | OK
--  Tablet       |    25 | OK
--  Monitor      |    30 | OK
--  Coffee Mug   |   100 | Plenty
--  Desk Chair   |     8 | Low
-- (6 rows)

-- ------------------------------------------------------------
-- Try It 2
-- For each department, count the employees who earn 90,000 or more
-- and those who earn less. Include departments with no employees.
-- ------------------------------------------------------------
-- 2. Earners per department; Legal shows 0s
SELECT d.department_name,
       SUM(CASE WHEN e.salary >= 90000
                THEN 1 ELSE 0 END) AS from_90k,
       SUM(CASE WHEN e.salary < 90000
                THEN 1 ELSE 0 END) AS under_90k
FROM departments d
LEFT JOIN employees e
    ON e.department_id = d.department_id
GROUP BY d.department_id, d.department_name
ORDER BY d.department_id;

-- Result:
--  department_name | from_90k | under_90k
-- -----------------+----------+-----------
--  Executive       |        1 |         0
--  Finance         |        0 |         2
--  Engineering     |        3 |         0
--  Sales           |        0 |         1
--  Legal           |        0 |         0
-- (5 rows)

-- ------------------------------------------------------------
-- Try It 3
-- In one UPDATE, cut Electronics prices by 10% and raise Furniture
-- prices by 5%, leaving other products unchanged. Then list every
-- product's price.
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 3. Without ELSE price, the Coffee Mug's
--    price would be set to NULL, and the
--    NOT NULL constraint would reject it.
UPDATE products
SET price =
    CASE category
        WHEN 'Electronics' THEN price * 0.90
        WHEN 'Furniture' THEN price * 1.05
        ELSE price
    END;

SELECT product_name, category, price
FROM products
ORDER BY product_id;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  product_name |  category   |  price
-- --------------+-------------+---------
--  Laptop       | Electronics | 1080.00
--  Smartphone   | Electronics |  720.00
--  Tablet       | Electronics |  405.00
--  Monitor      | Electronics |  270.00
--  Coffee Mug   | Kitchen     |   10.99
--  Desk Chair   | Furniture   |  261.45
-- (6 rows)

-- ------------------------------------------------------------
-- Undo everything this file changed.
-- ------------------------------------------------------------
ROLLBACK;
