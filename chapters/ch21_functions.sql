-- The Most Helpful SQL Guide, Second Edition
-- Chapter 21: SQL Functions
--
-- Every example in this part of the book that runs on PostgreSQL,
-- in book order, with the result the book prints. Load
-- sample_db.sql first. To run the whole file in psql:
--   psql -d sqlguide -f chapters/ch21_functions.sql
-- It runs as one transaction and rolls back at the end, so your
-- database is left unchanged. Examples that change data or fail on
-- purpose are wrapped in a savepoint and undone, as in the book.
-- You can also copy any single example into a query window.

BEGIN;

-- ------------------------------------------------------------
-- Example 1: Changing case and measuring length
-- ------------------------------------------------------------
SELECT last_name,
       UPPER(last_name) AS upper_name,
       LOWER(job_title) AS lower_title,
       LENGTH(last_name) AS name_length
FROM employees
WHERE department_id = 30
ORDER BY employee_id;

-- Result:
--  last_name | upper_name |     lower_title     | name_length
-- -----------+------------+---------------------+-------------
--  Johnson   | JOHNSON    | engineering manager |           7
--  Williams  | WILLIAMS   | software engineer   |           8
--  Chen      | CHEN       | software engineer   |           4
-- (3 rows)

-- ------------------------------------------------------------
-- Example 2: Joining strings: || and CONCAT
-- ------------------------------------------------------------
SELECT last_name || ', ' || first_name
           AS full_name
FROM employees
ORDER BY last_name, first_name;

-- Result:
--      full_name
-- -------------------
--  Brown, David
--  Chen, Sarah
--  Doe, John
--  Johnson, Emily
--  Patel, Priya
--  Smith, Jane
--  Williams, Michael
--  Wilson, Tom
-- (8 rows)

-- ------------------------------------------------------------
-- Example 3: Joining strings: || and CONCAT
-- ------------------------------------------------------------
SELECT first_name,
       first_name || ' (' || city || ')'
           AS with_pipes,
       CONCAT(first_name, ' (', city, ')')
           AS with_concat
FROM customers
ORDER BY customer_id;

-- Result:
--  first_name |     with_pipes     |    with_concat
-- ------------+--------------------+--------------------
--  Alice      | Alice (New York)   | Alice (New York)
--  Bob        | Bob (Chicago)      | Bob (Chicago)
--  Charlie    | Charlie (New York) | Charlie (New York)
--  Dana       | Dana (Austin)      | Dana (Austin)
--  Ethan      | NULL               | Ethan ()
-- (5 rows)

-- ------------------------------------------------------------
-- Example 4: Finding and extracting text
-- ------------------------------------------------------------
SELECT email,
       POSITION('@' IN email) AS at_sign,
       SUBSTRING(email, 1,
                 POSITION('@' IN email) - 1)
           AS user_name,
       SPLIT_PART(email, '@', 2) AS domain
FROM employees
WHERE department_id = 30
ORDER BY employee_id;

-- Result:
--            email           | at_sign |   user_name   |   domain
-- ---------------------------+---------+---------------+-------------
--  emily.johnson@example.com |      14 | emily.johnson | example.com
--  michael.w@example.com     |      10 | michael.w     | example.com
--  sarah.chen@example.com    |      11 | sarah.chen    | example.com
-- (3 rows)

-- ------------------------------------------------------------
-- Example 5: TRIM and REPLACE
-- ------------------------------------------------------------
SELECT '[' || TRIM('  Desk Lamp  ') || ']'
           AS trimmed;

-- Result:
--    trimmed
-- -------------
--  [Desk Lamp]
-- (1 row)

-- ------------------------------------------------------------
-- Example 6: TRIM and REPLACE
-- ------------------------------------------------------------
SELECT product_name,
       LOWER(REPLACE(product_name, ' ', '-'))
           AS slug
FROM products
ORDER BY product_id;

-- Result:
--  product_name |    slug
-- --------------+------------
--  Laptop       | laptop
--  Smartphone   | smartphone
--  Tablet       | tablet
--  Monitor      | monitor
--  Coffee Mug   | coffee-mug
--  Desk Chair   | desk-chair
-- (6 rows)

-- ------------------------------------------------------------
-- Example 7: Numeric Functions
-- ------------------------------------------------------------
SELECT product_name,
       price * 0.85 AS sale_price,
       ROUND(price * 0.85, 2) AS to_cents,
       CEIL(price * 0.85) AS up,
       FLOOR(price * 0.85) AS down
FROM products
ORDER BY product_id;

-- Result:
--  product_name | sale_price | to_cents |  up  | down
-- --------------+------------+----------+------+------
--  Laptop       |  1020.0000 |  1020.00 | 1020 | 1020
--  Smartphone   |   680.0000 |   680.00 |  680 |  680
--  Tablet       |   382.5000 |   382.50 |  383 |  382
--  Monitor      |   255.0000 |   255.00 |  255 |  255
--  Coffee Mug   |     9.3415 |     9.34 |   10 |    9
--  Desk Chair   |   211.6500 |   211.65 |  212 |  211
-- (6 rows)

-- ------------------------------------------------------------
-- Example 8: Numeric Functions
-- ------------------------------------------------------------
SELECT product_name, stock,
       stock / 12 AS full_boxes,
       MOD(stock, 12) AS loose,
       ABS(stock - 30) AS off_target
FROM products
ORDER BY product_id;

-- Result:
--  product_name | stock | full_boxes | loose | off_target
-- --------------+-------+------------+-------+------------
--  Laptop       |    15 |          1 |     3 |         15
--  Smartphone   |    40 |          3 |     4 |         10
--  Tablet       |    25 |          2 |     1 |          5
--  Monitor      |    30 |          2 |     6 |          0
--  Coffee Mug   |   100 |          8 |     4 |         70
--  Desk Chair   |     8 |          0 |     8 |         22
-- (6 rows)

-- ------------------------------------------------------------
-- Example 9: Integer division
-- ------------------------------------------------------------
SELECT 7 / 2 AS integers,
       7.0 / 2 AS decimal_point,
       CAST(7 AS DECIMAL) / 2 AS cast_first,
       CAST(7 / 2 AS DECIMAL) AS cast_too_late;

-- Result:
--  integers |   decimal_point    |     cast_first     | cast_too_late
-- ----------+--------------------+--------------------+---------------
--         3 | 3.5000000000000000 | 3.5000000000000000 |             3
-- (1 row)

-- ------------------------------------------------------------
-- Example 10: Converting Types with CAST
-- ------------------------------------------------------------
SELECT product_name, price,
       CAST(price AS INTEGER) AS whole_price,
       price::INTEGER AS shorthand,
       CAST(stock AS VARCHAR(10)) || ' in stock'
           AS label
FROM products
WHERE category <> 'Electronics'
ORDER BY product_id;

-- Result:
--  product_name | price  | whole_price | shorthand |    label
-- --------------+--------+-------------+-----------+--------------
--  Coffee Mug   |  10.99 |          11 |        11 | 100 in stock
--  Desk Chair   | 249.00 |         249 |       249 | 8 in stock
-- (2 rows)

-- ------------------------------------------------------------
-- Example 11: Converting Types with CAST
-- Fails on purpose, to show the error.
-- ------------------------------------------------------------
SAVEPOINT example;

SELECT CAST('12 units' AS INTEGER);

ROLLBACK TO SAVEPOINT example;

-- Expected error:
--   ERROR:  invalid input syntax for type integer: "12 units"

-- ------------------------------------------------------------
-- Example 12: User-Defined Functions
-- ------------------------------------------------------------
CREATE FUNCTION price_with_tax(price NUMERIC,
                               rate NUMERIC)
RETURNS NUMERIC
LANGUAGE sql
IMMUTABLE
RETURN ROUND(price * (1 + rate), 2);

-- Result: CREATE FUNCTION

-- ------------------------------------------------------------
-- Example 13: User-Defined Functions
-- ------------------------------------------------------------
SELECT product_name, price,
       price_with_tax(price, 0.08) AS with_tax
FROM products
ORDER BY product_id;

-- Result:
--  product_name |  price  | with_tax
-- --------------+---------+----------
--  Laptop       | 1200.00 |  1296.00
--  Smartphone   |  800.00 |   864.00
--  Tablet       |  450.00 |   486.00
--  Monitor      |  300.00 |   324.00
--  Coffee Mug   |   10.99 |    11.87
--  Desk Chair   |  249.00 |   268.92
-- (6 rows)

-- ------------------------------------------------------------
-- Example 14: User-Defined Functions
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

DROP FUNCTION price_with_tax(NUMERIC, NUMERIC);

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Try It 1
-- List each employee as their last name in capitals, a comma and
-- their first initial, such as "DOE, J".
-- ------------------------------------------------------------
-- 1. Last name in capitals and first initial
SELECT UPPER(last_name) || ', '
           || SUBSTRING(first_name, 1, 1)
           AS short_name
FROM employees
ORDER BY employee_id;

-- Result:
--  short_name
-- -------------
--  DOE, J
--  SMITH, J
--  JOHNSON, E
--  WILLIAMS, M
--  CHEN, S
--  BROWN, D
--  PATEL, P
--  WILSON, T
-- (8 rows)

-- ------------------------------------------------------------
-- Try It 2
-- Work out the average stock per product as SUM(stock) / COUNT(*),
-- keeping the fraction, rounded to one decimal place.
-- ------------------------------------------------------------
-- 2. Average stock, keeping the fraction
SELECT ROUND(CAST(SUM(stock) AS DECIMAL)
             / COUNT(*), 1) AS avg_stock
FROM products;

-- Result:
--  avg_stock
-- -----------
--       36.3
-- (1 row)

-- ------------------------------------------------------------
-- Try It 3
-- Write a function sale_price(price, pct) that takes pct percent off
-- a price, rounded to the cent. Use it to show every product at 15%
-- off.
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 3. A discount function. pct is NUMERIC, so
--    pct / 100 isn't cut to 0.
CREATE FUNCTION sale_price(price NUMERIC,
                           pct NUMERIC)
RETURNS NUMERIC
LANGUAGE sql
IMMUTABLE
RETURN ROUND(price * (1 - pct / 100), 2);

SELECT product_name, price,
       sale_price(price, 15) AS on_sale
FROM products
ORDER BY product_id;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  product_name |  price  | on_sale
-- --------------+---------+---------
--  Laptop       | 1200.00 | 1020.00
--  Smartphone   |  800.00 |  680.00
--  Tablet       |  450.00 |  382.50
--  Monitor      |  300.00 |  255.00
--  Coffee Mug   |   10.99 |    9.34
--  Desk Chair   |  249.00 |  211.65
-- (6 rows)

-- ------------------------------------------------------------
-- Example 15: Try It
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

DROP FUNCTION IF EXISTS
    sale_price(NUMERIC, NUMERIC);
DROP FUNCTION IF EXISTS
    price_with_tax(NUMERIC, NUMERIC);

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Undo everything this file changed.
-- ------------------------------------------------------------
ROLLBACK;
