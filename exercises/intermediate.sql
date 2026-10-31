-- The Most Helpful SQL Guide, Second Edition
-- Practical Exercises: Intermediate
--
-- The answer to every question, with the result the book prints.
-- Load sample_db.sql first. To run the whole file in psql:
--   psql -d sqlguide -f exercises/intermediate.sql
-- It runs as one transaction and rolls back at the end, so your
-- database is left unchanged. Examples that change data or fail on
-- purpose are wrapped in a savepoint and undone, as in the book.
-- You can also copy any single example into a query window.

BEGIN;

-- ------------------------------------------------------------
-- Exercise 1
-- List the employees who earn more than their manager. (Chapter 11)
-- ------------------------------------------------------------
-- 1. Employees who out-earn their manager
SELECT e.first_name, e.salary,
       m.first_name AS manager,
       m.salary AS manager_salary
FROM employees e
JOIN employees m
    ON m.employee_id = e.manager_id
WHERE e.salary > m.salary
ORDER BY e.employee_id;

-- Result:
--  first_name | salary | manager | manager_salary
-- ------------+--------+---------+----------------
-- (0 rows)

-- ------------------------------------------------------------
-- Exercise 2
-- For each customer who has ordered, show their sales in three
-- columns: shipped, still processing and cancelled. An order line is
-- worth quantity × unit_price. (Chapter 20)
-- ------------------------------------------------------------
-- 2. Sales per customer, by order status
SELECT c.first_name,
       SUM(CASE WHEN o.status = 'shipped'
                THEN oi.quantity * oi.unit_price
                ELSE 0.00 END) AS shipped,
       SUM(CASE WHEN o.status = 'processing'
                THEN oi.quantity * oi.unit_price
                ELSE 0.00 END) AS processing,
       SUM(CASE WHEN o.status = 'cancelled'
                THEN oi.quantity * oi.unit_price
                ELSE 0.00 END) AS cancelled
FROM customers c
JOIN orders o
    ON o.customer_id = c.customer_id
JOIN order_items oi
    ON oi.order_id = o.order_id
GROUP BY c.customer_id, c.first_name
ORDER BY c.customer_id;

-- Result:
--  first_name | shipped | processing | cancelled
-- ------------+---------+------------+-----------
--  Alice      | 3021.98 |       0.00 |      0.00
--  Bob        |  800.00 |       0.00 |      0.00
--  Charlie    | 1100.00 |       0.00 |    900.00
--  Dana       |    0.00 |     292.96 |      0.00
-- (4 rows)

-- ------------------------------------------------------------
-- Exercise 3
-- Find the customers who have never placed an order. (Chapter 11)
-- ------------------------------------------------------------
-- 3. Customers with no orders
SELECT c.customer_id, c.first_name, c.last_name
FROM customers c
LEFT JOIN orders o
    ON o.customer_id = c.customer_id
WHERE o.order_id IS NULL
ORDER BY c.customer_id;

-- Result:
--  customer_id | first_name | last_name
-- -------------+------------+-----------
--            5 | Ethan      | Ruiz
-- (1 row)

-- ------------------------------------------------------------
-- Exercise 4
-- For each department, by name, show the number of employees and
-- their average salary. Include departments with no employees.
-- (Chapter 12)
-- ------------------------------------------------------------
-- 4. Staff and average salary per department
SELECT d.department_name,
       COUNT(e.employee_id) AS staff,
       ROUND(AVG(e.salary), 2) AS avg_salary
FROM departments d
LEFT JOIN employees e
    ON e.department_id = d.department_id
GROUP BY d.department_id, d.department_name
ORDER BY d.department_id;

-- Result:
--  department_name | staff | avg_salary
-- -----------------+-------+------------
--  Executive       |     1 |  150000.00
--  Finance         |     2 |   77500.00
--  Engineering     |     3 |   96333.33
--  Sales           |     1 |   58000.00
--  Legal           |     0 |       NULL
-- (5 rows)

-- ------------------------------------------------------------
-- Exercise 5
-- List the products with fewer than 50 units in stock that appear on
-- at least one order that wasn't cancelled. (Chapter 13)
-- ------------------------------------------------------------
-- 5. Low-stock products still being ordered
SELECT p.product_name, p.stock
FROM products p
WHERE p.stock < 50
    AND EXISTS (
        SELECT 1
        FROM order_items oi
        JOIN orders o
            ON o.order_id = oi.order_id
        WHERE oi.product_id = p.product_id
            AND o.status <> 'cancelled'
    )
ORDER BY p.stock;

-- Result:
--  product_name | stock
-- --------------+-------
--  Desk Chair   |     8
--  Laptop       |    15
--  Monitor      |    30
--  Smartphone   |    40
-- (4 rows)

-- ------------------------------------------------------------
-- Exercise 6
-- Find the customer whose account was created most recently. If
-- several tie, list them all. (Chapter 13)
-- ------------------------------------------------------------
-- 6. The newest customer, ties included
SELECT first_name, last_name, created_on
FROM customers
WHERE created_on = (SELECT MAX(created_on)
                    FROM customers)
ORDER BY customer_id;

-- Result:
--  first_name | last_name | created_on
-- ------------+-----------+------------
--  Ethan      | Ruiz      | 2024-05-20
-- (1 row)

-- ------------------------------------------------------------
-- Exercise 7
-- List every employee's full name and job title, with their
-- manager's full name. (Chapter 11)
-- ------------------------------------------------------------
-- 7. Employees and their managers, full names
SELECT e.first_name || ' ' || e.last_name
           AS employee,
       e.job_title,
       m.first_name || ' ' || m.last_name
           AS manager
FROM employees e
LEFT JOIN employees m
    ON m.employee_id = e.manager_id
ORDER BY e.employee_id;

-- Result:
--      employee     |      job_title       |    manager
-- ------------------+----------------------+---------------
--  John Doe         | Managing Director    | NULL
--  Jane Smith       | Finance Manager      | John Doe
--  Emily Johnson    | Engineering Manager  | John Doe
--  Michael Williams | Software Engineer    | Emily Johnson
--  Sarah Chen       | Software Engineer    | Emily Johnson
--  David Brown      | Accountant           | Jane Smith
--  Priya Patel      | Sales Representative | John Doe
--  Tom Wilson       | Data Analyst         | Emily Johnson
-- (8 rows)

-- ------------------------------------------------------------
-- Exercise 8
-- Show each customer's most recent order, with its date and total
-- value. (Chapters 17 and 18)
-- ------------------------------------------------------------
-- 8. Each customer's most recent order
WITH order_totals AS (
    SELECT o.customer_id, o.order_id,
           o.order_date,
           SUM(oi.quantity * oi.unit_price)
               AS total
    FROM orders o
    JOIN order_items oi
        ON oi.order_id = o.order_id
    GROUP BY o.customer_id, o.order_id,
             o.order_date
),
ranked AS (
    SELECT customer_id, order_id, order_date,
           total,
           ROW_NUMBER() OVER (
               PARTITION BY customer_id
               ORDER BY order_date DESC,
                        order_id DESC
           ) AS row_num
    FROM order_totals
)
SELECT c.first_name, r.order_id,
       r.order_date, r.total
FROM ranked r
JOIN customers c
    ON c.customer_id = r.customer_id
WHERE r.row_num = 1
ORDER BY c.customer_id;

-- Result:
--  first_name | order_id | order_date |  total
-- ------------+----------+------------+---------
--  Alice      |      104 | 2024-02-03 | 1800.00
--  Bob        |      102 | 2024-01-16 |  800.00
--  Charlie    |      106 | 2024-03-05 | 1100.00
--  Dana       |      105 | 2024-02-10 |  292.96
-- (4 rows)

-- ------------------------------------------------------------
-- Exercise 9
-- List the two most expensive products in each category. (Chapters
-- 17 and 18)
-- ------------------------------------------------------------
-- 9. Two most expensive products per category
WITH ranked AS (
    SELECT category, product_name, price,
           ROW_NUMBER() OVER (
               PARTITION BY category
               ORDER BY price DESC, product_id
           ) AS row_num
    FROM products
)
SELECT category, product_name, price
FROM ranked
WHERE row_num <= 2
ORDER BY category, price DESC;

-- Result:
--   category   | product_name |  price
-- -------------+--------------+---------
--  Electronics | Laptop       | 1200.00
--  Electronics | Smartphone   |  800.00
--  Furniture   | Desk Chair   |  249.00
--  Kitchen     | Coffee Mug   |   10.99
-- (4 rows)

-- ------------------------------------------------------------
-- Exercise 10
-- Show how many days each customer has had an account, as of
-- December 31, 2024. (Chapter 14)
-- ------------------------------------------------------------
-- 10. Days since each account was created
SELECT first_name, created_on,
       DATE '2024-12-31' - created_on
           AS days_as_customer
FROM customers
ORDER BY created_on;

-- Result:
--  first_name | created_on | days_as_customer
-- ------------+------------+------------------
--  Bob        | 2019-08-09 |             1971
--  Alice      | 2020-01-15 |             1812
--  Charlie    | 2021-07-19 |             1261
--  Dana       | 2023-03-02 |              670
--  Ethan      | 2024-05-20 |              225
-- (5 rows)

-- ------------------------------------------------------------
-- Exercise 11
-- A delivery arrives: 10 Laptops, 20 Monitors and 12 units of a new
-- product, a Webcam (product 7, Electronics, 59.99). Load it into a
-- temporary table, then use one statement to add the units to stock
-- and add the Webcam to products. (Chapter 10)
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 11. Apply a delivery with MERGE
DROP TABLE IF EXISTS stock_deliveries;

CREATE TEMPORARY TABLE stock_deliveries (
    product_id   INT PRIMARY KEY,
    product_name VARCHAR(50)    NOT NULL,
    category     VARCHAR(30)    NOT NULL,
    price        DECIMAL(10, 2) NOT NULL,
    units        INT            NOT NULL
);

INSERT INTO stock_deliveries
    (product_id, product_name, category, price,
     units)
VALUES
    (1, 'Laptop', 'Electronics', 1200.00, 10),
    (4, 'Monitor', 'Electronics', 300.00, 20),
    (7, 'Webcam', 'Electronics', 59.99, 12);

MERGE INTO products p
USING stock_deliveries sd
    ON (p.product_id = sd.product_id)
WHEN MATCHED THEN
    UPDATE SET stock = p.stock + sd.units
WHEN NOT MATCHED THEN
    INSERT (product_id, product_name, category,
            price, stock)
    VALUES (sd.product_id, sd.product_name,
            sd.category, sd.price, sd.units);

SELECT product_id, product_name, price, stock
FROM products
ORDER BY product_id;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  product_id | product_name |  price  | stock
-- ------------+--------------+---------+-------
--           1 | Laptop       | 1200.00 |    25
--           2 | Smartphone   |  800.00 |    40
--           3 | Tablet       |  450.00 |    25
--           4 | Monitor      |  300.00 |    50
--           5 | Coffee Mug   |   10.99 |   100
--           6 | Desk Chair   |  249.00 |     8
--           7 | Webcam       |   59.99 |    12
-- (7 rows)

-- ------------------------------------------------------------
-- Exercise 12
-- Order 105 is ready to ship. Take its quantities out of stock,
-- joining products to the order's lines, and mark the order shipped.
-- (Chapter 13)
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 12. Ship order 105 and update stock
UPDATE products p
SET stock = p.stock - oi.quantity
FROM order_items oi
WHERE oi.product_id = p.product_id
    AND oi.order_id = 105;

UPDATE orders
SET status = 'shipped'
WHERE order_id = 105;

SELECT o.status, p.product_name,
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
--  status  | product_name | quantity | stock
-- ---------+--------------+----------+-------
--  shipped | Coffee Mug   |        4 |    96
--  shipped | Desk Chair   |        1 |     7
-- (2 rows)

-- ------------------------------------------------------------
-- Exercise 13
-- List the employees who don't manage anyone. Why does WHERE
-- employee_id NOT IN (SELECT manager_id FROM employees) return no
-- rows? (Chapters 13 and 15)
-- ------------------------------------------------------------
-- 13. Employees who manage nobody
SELECT e.first_name, e.last_name, e.job_title
FROM employees e
WHERE NOT EXISTS (
    SELECT 1
    FROM employees r
    WHERE r.manager_id = e.employee_id
)
ORDER BY e.employee_id;

-- Result:
--  first_name | last_name |      job_title
-- ------------+-----------+----------------------
--  Michael    | Williams  | Software Engineer
--  Sarah      | Chen      | Software Engineer
--  David      | Brown     | Accountant
--  Priya      | Patel     | Sales Representative
--  Tom        | Wilson    | Data Analyst
-- (5 rows)

-- ------------------------------------------------------------
-- Exercise 14
-- Show each employee's level in the org chart, with the chain of
-- managers from the top down to them, such as John > Emily > Tom.
-- (Chapters 18 and 21)
-- ------------------------------------------------------------
-- 14. Org chart levels and reporting chains
WITH RECURSIVE org AS (
    SELECT employee_id, first_name,
           1 AS depth,
           CAST(first_name AS TEXT) AS chain
    FROM employees
    WHERE manager_id IS NULL

    UNION ALL

    SELECT e.employee_id, e.first_name,
           o.depth + 1,
           o.chain || ' > ' || e.first_name
    FROM employees e
    JOIN org o
        ON e.manager_id = o.employee_id
)
SELECT first_name, depth, chain
FROM org
ORDER BY chain;

-- Result:
--  first_name | depth |         chain
-- ------------+-------+------------------------
--  John       |     1 | John
--  Emily      |     2 | John > Emily
--  Michael    |     3 | John > Emily > Michael
--  Sarah      |     3 | John > Emily > Sarah
--  Tom        |     3 | John > Emily > Tom
--  Jane       |     2 | John > Jane
--  David      |     3 | John > Jane > David
--  Priya      |     2 | John > Priya
-- (8 rows)

-- ------------------------------------------------------------
-- Exercise 15
-- A login form looks members up by email, ignoring case. On a
-- throwaway table of 20,000 members with mixed-case emails, create
-- an index that WHERE LOWER(email) = … can use, and show that the
-- query uses it. (Chapters 19 and 21)
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 15. An index for case-insensitive lookups
DROP TABLE IF EXISTS member_logins;

CREATE TABLE member_logins (
    member_id INT PRIMARY KEY,
    email     VARCHAR(100) NOT NULL
);

INSERT INTO member_logins (member_id, email)
SELECT n, 'Member' || n || '@Example.com'
FROM generate_series(1, 20000) n;

ANALYZE member_logins;

CREATE INDEX idx_member_logins_email_lower
    ON member_logins (LOWER(email));

EXPLAIN (COSTS OFF)
SELECT member_id, email
FROM member_logins
WHERE LOWER(email) = 'member42@example.com';

ROLLBACK TO SAVEPOINT example;

-- Plan:
--   Bitmap Heap Scan on member_logins
--     Recheck Cond: (lower((email)::text) = 'member42@example.com'::text)
--     ->  Bitmap Index Scan on idx_member_logins_email_lower
--           Index Cond: (lower((email)::text) = 'member42@example.com'::text)

-- ------------------------------------------------------------
-- Exercise 16
-- A sign-up form exported cities and ages as text, with stray
-- spaces, blank cities and ages that aren't whole numbers. Put a few
-- such rows in a temporary table, then show each one cleaned: the
-- city trimmed, with blanks as NULL, and the age as an integer, or
-- NULL where it can't be converted. (Chapters 15 and 21)
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 16. Clean imported text
DROP TABLE IF EXISTS signup_import;

CREATE TEMPORARY TABLE signup_import (
    row_id INT PRIMARY KEY,
    city   VARCHAR(50),
    age    VARCHAR(10)
);

INSERT INTO signup_import (row_id, city, age)
VALUES
    (1, '  Austin ', '34'),
    (2, '', ' 27 '),
    (3, 'Chicago', 'n/a'),
    (4, '   ', '41.5'),
    (5, 'New York', NULL);

SELECT row_id,
       NULLIF(TRIM(city), '') AS city,
       CASE WHEN pg_input_is_valid(TRIM(age),
                                   'integer')
            THEN CAST(TRIM(age) AS INTEGER)
       END AS age
FROM signup_import
ORDER BY row_id;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  row_id |   city   | age
-- --------+----------+------
--       1 | Austin   |   34
--       2 | NULL     |   27
--       3 | Chicago  | NULL
--       4 | NULL     | NULL
--       5 | New York | NULL
-- (5 rows)

-- ------------------------------------------------------------
-- Exercise 17
-- Show the payroll by department name and job title, with a subtotal
-- for each department and a grand total. Label the total rows, and
-- label Tom's group "No department". (Chapters 20 and 28)
-- ------------------------------------------------------------
-- 17. Payroll with labeled subtotals
SELECT CASE WHEN GROUPING(d.department_name) = 1
            THEN 'All departments'
            ELSE COALESCE(d.department_name,
                          'No department')
       END AS department,
       CASE WHEN GROUPING(e.job_title) = 1
            THEN 'All titles'
            ELSE e.job_title
       END AS job_title,
       COUNT(*) AS staff,
       SUM(e.salary) AS payroll
FROM employees e
LEFT JOIN departments d
    ON d.department_id = e.department_id
GROUP BY ROLLUP (d.department_name, e.job_title)
ORDER BY GROUPING(d.department_name),
         d.department_name,
         GROUPING(e.job_title), e.job_title;

-- Result:
--    department    |      job_title       | staff |  payroll
-- -----------------+----------------------+-------+-----------
--  Engineering     | Engineering Manager  |     1 | 105000.00
--  Engineering     | Software Engineer    |     2 | 184000.00
--  Engineering     | All titles           |     3 | 289000.00
--  Executive       | Managing Director    |     1 | 150000.00
--  Executive       | All titles           |     1 | 150000.00
--  Finance         | Accountant           |     1 |  67000.00
--  Finance         | Finance Manager      |     1 |  88000.00
--  Finance         | All titles           |     2 | 155000.00
--  Sales           | Sales Representative |     1 |  58000.00
--  Sales           | All titles           |     1 |  58000.00
--  No department   | Data Analyst         |     1 |  71000.00
--  No department   | All titles           |     1 |  71000.00
--  All departments | All titles           |     8 | 723000.00
-- (13 rows)

-- ------------------------------------------------------------
-- Exercise 18
-- For each table in the sample database, count its columns and list
-- the ones that accept NULL. (Chapters 12 and 35)
-- ------------------------------------------------------------
-- 18. Columns and nullable columns per table
SELECT c.table_name,
       COUNT(*) AS column_count,
       STRING_AGG(c.column_name, ', '
                  ORDER BY c.ordinal_position)
           FILTER (WHERE c.is_nullable = 'YES')
           AS nullable_columns
FROM information_schema.columns c
JOIN information_schema.tables t
    ON t.table_schema = c.table_schema
    AND t.table_name = c.table_name
WHERE c.table_schema = 'public'
    AND t.table_type = 'BASE TABLE'
GROUP BY c.table_name
ORDER BY c.table_name;

-- Result:
--  table_name  | column_count |     nullable_columns
-- -------------+--------------+---------------------------
--  customers   |            7 | city
--  departments |            2 | NULL
--  employees   |            9 | department_id, manager_id
--  order_items |            4 | NULL
--  orders      |            4 | NULL
--  products    |            5 | NULL
--  projects    |            4 | NULL
-- (7 rows)

-- ------------------------------------------------------------
-- Exercise 19
-- Ethan (customer 5) places his first order, 107, on March 20, 2024,
-- for two Monitors. Add the order, then add its line with INSERT …
-- SELECT, copying the Monitor's price from products, and return the
-- new line with its value. (Chapters 10 and 36)
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 19. A new order line, priced from products
INSERT INTO orders
    (order_id, customer_id, order_date, status)
VALUES (107, 5, DATE '2024-03-20', 'processing');

INSERT INTO order_items
    (order_id, product_id, quantity, unit_price)
SELECT 107, product_id, 2, price
FROM products
WHERE product_name = 'Monitor'
RETURNING order_id, product_id, quantity,
          unit_price,
          quantity * unit_price AS line_value;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  order_id | product_id | quantity | unit_price | line_value
-- ----------+------------+----------+------------+------------
--       107 |          4 |        2 |     300.00 |     600.00
-- (1 row)

-- ------------------------------------------------------------
-- Exercise 20
-- Build a JSON document for each customer who has ordered: their
-- full name, city and an array of their orders, each with its
-- order_id, date and status, oldest first. (Chapter 37)
-- ------------------------------------------------------------
-- 20. One JSON document per customer
SELECT jsonb_build_object(
           'customer',
           c.first_name || ' ' || c.last_name,
           'city', c.city,
           'orders', jsonb_agg(
               jsonb_build_object(
                   'order_id', o.order_id,
                   'date', o.order_date,
                   'status', o.status)
               ORDER BY o.order_date)
       ) AS customer_doc
FROM customers c
JOIN orders o
    ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name,
         c.last_name, c.city
ORDER BY c.customer_id;

-- Result:
--                                                                                         customer_doc
-- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--  {"city": "New York", "orders": [{"date": "2024-01-15", "status": "shipped", "order_id": 101}, {"date": "2024-02-03", "status": "shipped", "order_id": 104}], "customer": "Alice Brown"}
--  {"city": "Chicago", "orders": [{"date": "2024-01-16", "status": "shipped", "order_id": 102}], "customer": "Bob Davis"}
--  {"city": "New York", "orders": [{"date": "2024-01-17", "status": "cancelled", "order_id": 103}, {"date": "2024-03-05", "status": "shipped", "order_id": 106}], "customer": "Charlie Evans"}
--  {"city": "Austin", "orders": [{"date": "2024-02-10", "status": "processing", "order_id": 105}], "customer": "Dana Kim"}
-- (4 rows)

-- ------------------------------------------------------------
-- Example 1: Answers
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

DROP TABLE IF EXISTS member_logins;

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Undo everything this file changed.
-- ------------------------------------------------------------
ROLLBACK;
