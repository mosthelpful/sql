-- The Most Helpful SQL Guide, Second Edition
-- Appendix C: Common SQL Patterns
--
-- Every example in this part of the book that runs on PostgreSQL,
-- in book order, with the result the book prints. Load
-- sample_db.sql first. To run the whole file in psql:
--   psql -d sqlguide -f appendix_c/patterns.sql
-- It runs as one transaction and rolls back at the end, so your
-- database is left unchanged. Examples that change data or fail on
-- purpose are wrapped in a savepoint and undone, as in the book.
-- You can also copy any single example into a query window.

BEGIN;

-- ------------------------------------------------------------
-- Example 1: Paging Through Results
-- ------------------------------------------------------------
SELECT product_id, product_name, price
FROM products
ORDER BY price, product_id
OFFSET 2 ROWS
FETCH FIRST 2 ROWS ONLY;

-- Result:
--  product_id | product_name | price
-- ------------+--------------+--------
--           4 | Monitor      | 300.00
--           3 | Tablet       | 450.00
-- (2 rows)

-- ------------------------------------------------------------
-- Example 2: Paging Through Results
-- ------------------------------------------------------------
SELECT product_id, product_name, price
FROM products
WHERE (price, product_id) > (249.00, 6)
ORDER BY price, product_id
FETCH FIRST 2 ROWS ONLY;

-- Result:
--  product_id | product_name | price
-- ------------+--------------+--------
--           4 | Monitor      | 300.00
--           3 | Tablet       | 450.00
-- (2 rows)

-- ------------------------------------------------------------
-- Example 3: Top N per Group
-- ------------------------------------------------------------
WITH ranked AS (
    SELECT d.department_name,
           e.first_name,
           e.hire_date,
           ROW_NUMBER() OVER (
               PARTITION BY e.department_id
               ORDER BY e.hire_date DESC,
                        e.employee_id
           ) AS row_num
    FROM employees e
    JOIN departments d
        ON d.department_id = e.department_id
)
SELECT department_name, first_name, hire_date
FROM ranked
WHERE row_num <= 2
ORDER BY department_name, hire_date DESC;

-- Result:
--  department_name | first_name | hire_date
-- -----------------+------------+------------
--  Engineering     | Sarah      | 2020-02-03
--  Engineering     | Michael    | 2018-05-29
--  Executive       | John       | 2015-06-15
--  Finance         | David      | 2019-11-12
--  Finance         | Jane       | 2016-09-23
--  Sales           | Priya      | 2021-08-30
-- (6 rows)

-- ------------------------------------------------------------
-- Example 4: Latest Row per Group
-- ------------------------------------------------------------
WITH ranked AS (
    SELECT customer_id, order_id, order_date,
           ROW_NUMBER() OVER (
               PARTITION BY customer_id
               ORDER BY order_date DESC,
                        order_id DESC
           ) AS row_num
    FROM orders
)
SELECT customer_id, order_id, order_date
FROM ranked
WHERE row_num = 1
ORDER BY customer_id;

-- Result:
--  customer_id | order_id | order_date
-- -------------+----------+------------
--            1 |      104 | 2024-02-03
--            2 |      102 | 2024-01-16
--            3 |      106 | 2024-03-05
--            4 |      105 | 2024-02-10
-- (4 rows)

-- ------------------------------------------------------------
-- Example 5: Latest Row per Group
-- ------------------------------------------------------------
SELECT DISTINCT ON (customer_id)
       customer_id, order_id, order_date
FROM orders
ORDER BY customer_id, order_date DESC,
         order_id DESC;

-- Result:
--  customer_id | order_id | order_date
-- -------------+----------+------------
--            1 |      104 | 2024-02-03
--            2 |      102 | 2024-01-16
--            3 |      106 | 2024-03-05
--            4 |      105 | 2024-02-10
-- (4 rows)

-- ------------------------------------------------------------
-- Example 6: Running Totals
-- ------------------------------------------------------------
WITH order_totals AS (
    SELECT o.order_id, o.order_date,
           SUM(oi.quantity * oi.unit_price)
               AS total
    FROM orders o
    JOIN order_items oi
        ON oi.order_id = o.order_id
    WHERE o.status <> 'cancelled'
    GROUP BY o.order_id, o.order_date
)
SELECT order_id, order_date, total,
       SUM(total) OVER (
           ORDER BY order_date, order_id
           ROWS BETWEEN UNBOUNDED PRECEDING
                    AND CURRENT ROW
       ) AS running_total
FROM order_totals
ORDER BY order_date, order_id;

-- Result:
--  order_id | order_date |  total  | running_total
-- ----------+------------+---------+---------------
--       101 | 2024-01-15 | 1221.98 |       1221.98
--       102 | 2024-01-16 |  800.00 |       2021.98
--       104 | 2024-02-03 | 1800.00 |       3821.98
--       105 | 2024-02-10 |  292.96 |       4114.94
--       106 | 2024-03-05 | 1100.00 |       5214.94
-- (5 rows)

-- ------------------------------------------------------------
-- Example 7: Comparing with the Previous Row
-- ------------------------------------------------------------
SELECT first_name, hire_date,
       hire_date - LAG(hire_date) OVER (
           ORDER BY hire_date
       ) AS days_since_prev
FROM employees
ORDER BY hire_date;

-- Result:
--  first_name | hire_date  | days_since_prev
-- ------------+------------+-----------------
--  John       | 2015-06-15 |            NULL
--  Jane       | 2016-09-23 |             466
--  Emily      | 2017-03-11 |             169
--  Michael    | 2018-05-29 |             444
--  David      | 2019-11-12 |             532
--  Sarah      | 2020-02-03 |              83
--  Priya      | 2021-08-30 |             574
--  Tom        | 2024-01-08 |             861
-- (8 rows)

-- ------------------------------------------------------------
-- Example 8: Pivoting Rows into Columns
-- ------------------------------------------------------------
SELECT TO_CHAR(o.order_date, 'YYYY-MM')
           AS month,
       SUM(CASE WHEN p.category = 'Electronics'
                THEN oi.quantity * oi.unit_price
                ELSE 0.00 END) AS electronics,
       SUM(CASE WHEN p.category = 'Furniture'
                THEN oi.quantity * oi.unit_price
                ELSE 0.00 END) AS furniture,
       SUM(CASE WHEN p.category = 'Kitchen'
                THEN oi.quantity * oi.unit_price
                ELSE 0.00 END) AS kitchen
FROM orders o
JOIN order_items oi
    ON oi.order_id = o.order_id
JOIN products p
    ON p.product_id = oi.product_id
WHERE o.status <> 'cancelled'
GROUP BY TO_CHAR(o.order_date, 'YYYY-MM')
ORDER BY month;

-- Result:
--   month  | electronics | furniture | kitchen
-- ---------+-------------+-----------+---------
--  2024-01 |     2000.00 |      0.00 |   21.98
--  2024-02 |     1800.00 |    249.00 |   43.96
--  2024-03 |     1100.00 |      0.00 |    0.00
-- (3 rows)

-- ------------------------------------------------------------
-- Example 9: Rows with No Match in Another Table
-- ------------------------------------------------------------
SELECT p.product_id, p.product_name
FROM products p
WHERE NOT EXISTS (
    SELECT 1
    FROM order_items oi
    JOIN orders o
        ON o.order_id = oi.order_id
    WHERE oi.product_id = p.product_id
        AND o.status <> 'cancelled'
)
ORDER BY p.product_id;

-- Result:
--  product_id | product_name
-- ------------+--------------
--           3 | Tablet
-- (1 row)

-- ------------------------------------------------------------
-- Example 10: Finding and Removing Duplicates
-- ------------------------------------------------------------
DROP TABLE IF EXISTS customer_import;

CREATE TEMPORARY TABLE customer_import (
    import_id  INT GENERATED ALWAYS AS IDENTITY
                   PRIMARY KEY,
    email      VARCHAR(100) NOT NULL,
    first_name VARCHAR(50)  NOT NULL
);

INSERT INTO customer_import (email, first_name)
SELECT email, first_name
FROM customers
ORDER BY customer_id;

-- A second load repeats Alice and Charlie
INSERT INTO customer_import (email, first_name)
SELECT email, first_name
FROM customers
WHERE customer_id IN (1, 3)
ORDER BY customer_id;

SELECT email,
       COUNT(*) AS copies,
       MIN(import_id) AS keep_id
FROM customer_import
GROUP BY email
HAVING COUNT(*) > 1
ORDER BY email;

-- Result:
--         email        | copies | keep_id
-- ---------------------+--------+---------
--  alice@example.com   |      2 |       1
--  charlie@example.com |      2 |       3
-- (2 rows)

-- ------------------------------------------------------------
-- Example 11: Finding and Removing Duplicates
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

DELETE FROM customer_import
WHERE import_id IN (
    SELECT import_id
    FROM (
        SELECT import_id,
               ROW_NUMBER() OVER (
                   PARTITION BY email
                   ORDER BY import_id
               ) AS row_num
        FROM customer_import
    ) numbered
    WHERE row_num > 1
);

SELECT import_id, email
FROM customer_import
ORDER BY import_id;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  import_id |        email
-- -----------+---------------------
--          1 | alice@example.com
--          2 | bob@example.com
--          3 | charlie@example.com
--          4 | dana@example.com
--          5 | ethan@example.com
-- (5 rows)

-- ------------------------------------------------------------
-- Example 12: Cleaning Imported Text
-- Sets up data for the examples that follow.
-- ------------------------------------------------------------
DROP TABLE IF EXISTS product_staging;

CREATE TEMPORARY TABLE product_staging (
    product_id   TEXT,
    product_name TEXT,
    category     TEXT,
    price        TEXT,
    stock        TEXT
);

INSERT INTO product_staging
VALUES
    ('7', '  Desk Lamp ', 'Furniture ',
     '39.99', '20'),
    ('8', 'Bookshelf', '  Furniture',
     '129.5', ''),
    ('9', 'Kettle', 'Kitchen', 'n/a', '12'),
    ('10', 'Notebook', '', '4.75', ' 200');

-- ------------------------------------------------------------
-- Example 13: Cleaning Imported Text
-- ------------------------------------------------------------
SELECT product_name, price
FROM product_staging
WHERE NOT pg_input_is_valid(TRIM(price),
                            'numeric')
ORDER BY product_name;

-- Result:
--  product_name | price
-- --------------+-------
--  Kettle       | n/a
-- (1 row)

-- ------------------------------------------------------------
-- Example 14: Cleaning Imported Text
-- ------------------------------------------------------------
SELECT CAST(product_id AS INT) AS product_id,
       TRIM(product_name) AS product_name,
       NULLIF(TRIM(category), '') AS category,
       CAST(TRIM(price) AS DECIMAL(10, 2))
           AS price,
       CAST(NULLIF(TRIM(stock), '') AS INT)
           AS stock
FROM product_staging
WHERE pg_input_is_valid(TRIM(price), 'numeric')
ORDER BY product_name;

-- Result:
--  product_id | product_name | category  | price  | stock
-- ------------+--------------+-----------+--------+-------
--           8 | Bookshelf    | Furniture | 129.50 |  NULL
--           7 | Desk Lamp    | Furniture |  39.99 |    20
--          10 | Notebook     | NULL      |   4.75 |   200
-- (3 rows)

-- ------------------------------------------------------------
-- Example 15: Insert or Update (Upsert)
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

INSERT INTO products
    (product_id, product_name, category,
     price, stock)
VALUES
    (3, 'Tablet', 'Electronics', 450.00, 10),
    (7, 'Desk Lamp', 'Furniture', 39.99, 20)
ON CONFLICT (product_id) DO UPDATE
SET stock = products.stock + EXCLUDED.stock;

SELECT product_id, product_name, stock
FROM products
ORDER BY product_id;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  product_id | product_name | stock
-- ------------+--------------+-------
--           1 | Laptop       |    15
--           2 | Smartphone   |    40
--           3 | Tablet       |    35
--           4 | Monitor      |    30
--           5 | Coffee Mug   |   100
--           6 | Desk Chair   |     8
--           7 | Desk Lamp    |    20
-- (7 rows)

-- ------------------------------------------------------------
-- Example 16: Walking a Hierarchy
-- ------------------------------------------------------------
WITH RECURSIVE org AS (
    SELECT employee_id,
           CAST(first_name AS TEXT) AS chain,
           1 AS depth
    FROM employees
    WHERE manager_id IS NULL
    UNION ALL
    SELECT e.employee_id,
           o.chain || ' > ' || e.first_name,
           o.depth + 1
    FROM employees e
    JOIN org o
        ON e.manager_id = o.employee_id
)
SELECT depth, chain
FROM org
ORDER BY chain;

-- Result:
--  depth |         chain
-- -------+------------------------
--      1 | John
--      2 | John > Emily
--      3 | John > Emily > Michael
--      3 | John > Emily > Sarah
--      3 | John > Emily > Tom
--      2 | John > Jane
--      3 | John > Jane > David
--      2 | John > Priya
-- (8 rows)

-- ------------------------------------------------------------
-- Example 17: Gaps and Islands
-- ------------------------------------------------------------
WITH grouped AS (
    SELECT order_date,
           order_date - CAST(DENSE_RANK() OVER (
               ORDER BY order_date) AS INT) AS grp
    FROM orders
)
SELECT MIN(order_date) AS run_start,
       MAX(order_date) AS run_end,
       COUNT(DISTINCT order_date) AS days
FROM grouped
GROUP BY grp
ORDER BY run_start;

-- Result:
--  run_start  |  run_end   | days
-- ------------+------------+------
--  2024-01-15 | 2024-01-17 |    3
--  2024-02-03 | 2024-02-03 |    1
--  2024-02-10 | 2024-02-10 |    1
--  2024-03-05 | 2024-03-05 |    1
-- (4 rows)

-- ------------------------------------------------------------
-- Example 18: Gaps and Islands
-- ------------------------------------------------------------
WITH next_dates AS (
    SELECT order_date,
           LEAD(order_date) OVER (
               ORDER BY order_date) AS next_date
    FROM orders
)
SELECT order_date + 1 AS gap_start,
       next_date - 1 AS gap_end,
       next_date - order_date - 1 AS days
FROM next_dates
WHERE next_date > order_date + 1
ORDER BY gap_start;

-- Result:
--  gap_start  |  gap_end   | days
-- ------------+------------+------
--  2024-01-18 | 2024-02-02 |   16
--  2024-02-04 | 2024-02-09 |    6
--  2024-02-11 | 2024-03-04 |   23
-- (3 rows)

-- ------------------------------------------------------------
-- Example 19: A Calendar with No Gaps
-- ------------------------------------------------------------
SELECT CAST(c.day AS DATE) AS day,
       COUNT(o.order_id) AS orders
FROM generate_series(DATE '2024-01-14',
                     DATE '2024-01-20',
                     INTERVAL '1 day') c(day)
LEFT JOIN orders o
    ON o.order_date = c.day
GROUP BY c.day
ORDER BY c.day;

-- Result:
--     day     | orders
-- ------------+--------
--  2024-01-14 |      0
--  2024-01-15 |      1
--  2024-01-16 |      1
--  2024-01-17 |      1
--  2024-01-18 |      0
--  2024-01-19 |      0
--  2024-01-20 |      0
-- (7 rows)

-- ------------------------------------------------------------
-- Example 20: Safe Dynamic SQL
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS count_matches;

CREATE FUNCTION count_matches(tbl TEXT,
                              col TEXT,
                              val TEXT)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    n BIGINT;
BEGIN
    EXECUTE format(
        'SELECT COUNT(*) FROM %I WHERE %I = $1',
        tbl, col)
        INTO n
        USING val;
    RETURN n;
END;
$$;

SELECT count_matches('customers', 'city',
                     'New York') AS new_york,
       count_matches('orders', 'status',
                     'shipped') AS shipped;

-- Result:
--  new_york | shipped
-- ----------+---------
--         2 |       4
-- (1 row)

-- ------------------------------------------------------------
-- Example 21: Safe Dynamic SQL
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

DROP FUNCTION IF EXISTS count_matches;

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Undo everything this file changed.
-- ------------------------------------------------------------
ROLLBACK;
