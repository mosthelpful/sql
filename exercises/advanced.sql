-- The Most Helpful SQL Guide, Second Edition
-- Practical Exercises: Advanced
--
-- The answer to every question, with the result the book prints.
-- Load sample_db.sql first. To run the whole file in psql:
--   psql -d sqlguide -f exercises/advanced.sql
-- It runs as one transaction and rolls back at the end, so your
-- database is left unchanged. Examples that change data or fail on
-- purpose are wrapped in a savepoint and undone, as in the book.
-- You can also copy any single example into a query window.

BEGIN;

-- ------------------------------------------------------------
-- Example 1: Questions
-- ------------------------------------------------------------
SELECT d.department_name,
       SUM(e.salary) AS payroll,
       SUM(p.budget) AS project_budget
FROM departments d
JOIN employees e
    ON e.department_id = d.department_id
JOIN projects p
    ON p.department_id = d.department_id
GROUP BY d.department_id, d.department_name
ORDER BY d.department_id;

-- Result:
--  department_name |  payroll  | project_budget
-- -----------------+-----------+----------------
--  Finance         | 155000.00 |      100000.00
--  Engineering     | 578000.00 |      405000.00
--  Sales           |  58000.00 |       45000.00
-- (3 rows)

-- ------------------------------------------------------------
-- Exercise 1
-- List the employees who were hired more than five years after their
-- manager, with both hire dates. (Chapters 11 and 14)
-- ------------------------------------------------------------
-- 1. Hired more than five years after
--    their manager
SELECT e.first_name AS employee,
       e.hire_date,
       m.first_name AS manager,
       m.hire_date AS manager_hired
FROM employees e
JOIN employees m
    ON m.employee_id = e.manager_id
WHERE e.hire_date
      > m.hire_date + INTERVAL '5 years'
ORDER BY e.employee_id;

-- Result:
--  employee | hire_date  | manager | manager_hired
-- ----------+------------+---------+---------------
--  Priya    | 2021-08-30 | John    | 2015-06-15
--  Tom      | 2024-01-08 | Emily   | 2017-03-11
-- (2 rows)

-- ------------------------------------------------------------
-- Exercise 2
-- Show every customer's total spending, not counting cancelled
-- orders. Customers who have never ordered should show 0.00.
-- (Chapters 11 and 12)
-- ------------------------------------------------------------
-- 2. Spending per customer, including
--    customers with no orders
SELECT c.first_name, c.last_name,
       COALESCE(SUM(oi.quantity * oi.unit_price),
                0.00) AS total_spent
FROM customers c
LEFT JOIN orders o
    ON o.customer_id = c.customer_id
    AND o.status <> 'cancelled'
LEFT JOIN order_items oi
    ON oi.order_id = o.order_id
GROUP BY c.customer_id, c.first_name,
         c.last_name
ORDER BY total_spent DESC, c.customer_id;

-- Result:
--  first_name | last_name | total_spent
-- ------------+-----------+-------------
--  Alice      | Brown     |     3021.98
--  Charlie    | Evans     |     1100.00
--  Bob        | Davis     |      800.00
--  Dana       | Kim       |      292.96
--  Ethan      | Ruiz      |        0.00
-- (5 rows)

-- ------------------------------------------------------------
-- Exercise 3
-- Find the most popular product in each category, measured by the
-- number of orders it appears on. Break ties by revenue. (Chapters
-- 17 and 18)
-- ------------------------------------------------------------
-- 3. Most popular product per category
WITH product_orders AS (
    SELECT p.category, p.product_name,
           COUNT(*) AS order_count,
           SUM(oi.quantity * oi.unit_price)
               AS revenue
    FROM products p
    JOIN order_items oi
        ON oi.product_id = p.product_id
    GROUP BY p.product_id, p.category,
             p.product_name
),
ranked AS (
    SELECT category, product_name, order_count,
           revenue,
           ROW_NUMBER() OVER (
               PARTITION BY category
               ORDER BY order_count DESC,
                        revenue DESC
           ) AS row_num
    FROM product_orders
)
SELECT category, product_name, order_count,
       revenue
FROM ranked
WHERE row_num = 1
ORDER BY category;

-- Result:
--   category   | product_name | order_count | revenue
-- -------------+--------------+-------------+---------
--  Electronics | Laptop       |           2 | 2400.00
--  Furniture   | Desk Chair   |           1 |  249.00
--  Kitchen     | Coffee Mug   |           2 |   65.94
-- (3 rows)

-- ------------------------------------------------------------
-- Exercise 4
-- Show sales for each month from January to June 2024, not counting
-- cancelled orders, with a running total. Months with no sales
-- should show 0.00. (Chapters 17 and 28)
-- ------------------------------------------------------------
-- 4. Monthly sales with empty months and
--    a running total
WITH monthly AS (
    SELECT CAST(DATE_TRUNC('month', o.order_date)
                AS DATE) AS month,
           SUM(oi.quantity * oi.unit_price)
               AS sales
    FROM orders o
    JOIN order_items oi
        ON oi.order_id = o.order_id
    WHERE o.status <> 'cancelled'
    GROUP BY DATE_TRUNC('month', o.order_date)
)
SELECT CAST(m.month_start AS DATE) AS month,
       COALESCE(s.sales, 0.00) AS sales,
       SUM(COALESCE(s.sales, 0.00)) OVER (
           ORDER BY m.month_start
           ROWS BETWEEN UNBOUNDED PRECEDING
                    AND CURRENT ROW
       ) AS running_total
FROM generate_series(DATE '2024-01-01',
                     DATE '2024-06-01',
                     INTERVAL '1 month')
         m(month_start)
LEFT JOIN monthly s
    ON s.month = m.month_start
ORDER BY month;

-- Result:
--    month    |  sales  | running_total
-- ------------+---------+---------------
--  2024-01-01 | 2021.98 |       2021.98
--  2024-02-01 | 2092.96 |       4114.94
--  2024-03-01 | 1100.00 |       5214.94
--  2024-04-01 |    0.00 |       5214.94
--  2024-05-01 |    0.00 |       5214.94
--  2024-06-01 |    0.00 |       5214.94
-- (6 rows)

-- ------------------------------------------------------------
-- Exercise 5
-- Create a view that counts the employees in each department,
-- including departments with none. Use it to list the departments
-- with fewer than two employees. (Chapter 24)
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 5. A view of department sizes
DROP VIEW IF EXISTS department_sizes;

CREATE VIEW department_sizes AS
SELECT d.department_id, d.department_name,
       COUNT(e.employee_id) AS employees
FROM departments d
LEFT JOIN employees e
    ON e.department_id = d.department_id
GROUP BY d.department_id, d.department_name;

SELECT department_name, employees
FROM department_sizes
WHERE employees < 2
ORDER BY department_id;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  department_name | employees
-- -----------------+-----------
--  Executive       |         1
--  Sales           |         1
--  Legal           |         0
-- (3 rows)

-- ------------------------------------------------------------
-- Exercise 6
-- Find the customers who have placed more than one order but have
-- spent less than 1,500.00, not counting cancelled orders toward the
-- spending. (Chapter 12)
-- ------------------------------------------------------------
-- 6. Several orders, but little spending
SELECT c.first_name, c.last_name,
       COUNT(DISTINCT o.order_id) AS order_count,
       SUM(oi.quantity * oi.unit_price)
           FILTER (WHERE o.status <> 'cancelled')
           AS spent
FROM customers c
JOIN orders o
    ON o.customer_id = c.customer_id
JOIN order_items oi
    ON oi.order_id = o.order_id
GROUP BY c.customer_id, c.first_name,
         c.last_name
HAVING COUNT(DISTINCT o.order_id) > 1
    AND SUM(oi.quantity * oi.unit_price)
        FILTER (WHERE o.status <> 'cancelled')
        < 1500
ORDER BY c.customer_id;

-- Result:
--  first_name | last_name | order_count |  spent
-- ------------+-----------+-------------+---------
--  Charlie    | Evans     |           2 | 1100.00
-- (1 row)

-- ------------------------------------------------------------
-- Exercise 7
-- Show each product's potential revenue if its whole stock sold at
-- the current price, and that revenue's share of the total for all
-- products, as a percentage. (Chapters 17 and 28)
-- ------------------------------------------------------------
-- 7. Potential revenue from stock, and
--    each product's share
SELECT product_name,
       price * stock AS potential,
       ROUND(100 * price * stock
             / SUM(price * stock) OVER (), 1)
           AS pct_of_total
FROM products
ORDER BY potential DESC;

-- Result:
--  product_name | potential | pct_of_total
-- --------------+-----------+--------------
--  Smartphone   |  32000.00 |         43.6
--  Laptop       |  18000.00 |         24.5
--  Tablet       |  11250.00 |         15.3
--  Monitor      |   9000.00 |         12.3
--  Desk Chair   |   1992.00 |          2.7
--  Coffee Mug   |   1099.00 |          1.5
-- (6 rows)

-- ------------------------------------------------------------
-- Exercise 8
-- For each customer who has ordered more than once, find the longest
-- gap, in days, between two of their consecutive orders. (Chapter
-- 17)
-- ------------------------------------------------------------
-- 8. Longest gap between a customer's orders
WITH gaps AS (
    SELECT customer_id,
           order_date - LAG(order_date) OVER (
               PARTITION BY customer_id
               ORDER BY order_date
           ) AS days_between
    FROM orders
)
SELECT c.first_name,
       MAX(g.days_between) AS longest_gap
FROM gaps g
JOIN customers c
    ON c.customer_id = g.customer_id
WHERE g.days_between IS NOT NULL
GROUP BY c.customer_id, c.first_name
ORDER BY longest_gap DESC;

-- Result:
--  first_name | longest_gap
-- ------------+-------------
--  Charlie    |          48
--  Alice      |          19
-- (2 rows)

-- ------------------------------------------------------------
-- Exercise 9
-- The sample data has no loops in its management chain, but bad data
-- can create one. Make David (employee 6) John's manager, then find
-- every employee who indirectly reports to themselves. (Chapter 18)
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 9. Create a loop, then find it
UPDATE employees
SET manager_id = 6
WHERE employee_id = 1;

WITH RECURSIVE chain AS (
    SELECT employee_id AS start_id,
           employee_id, manager_id,
           CAST(first_name AS TEXT) AS route
    FROM employees
    UNION ALL
    SELECT c.start_id, m.employee_id,
           m.manager_id,
           c.route || ' > ' || m.first_name
    FROM chain c
    JOIN employees m
        ON m.employee_id = c.manager_id
) CYCLE employee_id SET is_cycle USING path
SELECT route
FROM chain
WHERE is_cycle
    AND employee_id = start_id
ORDER BY start_id;

ROLLBACK TO SAVEPOINT example;

-- Result:
--             route
-- -----------------------------
--  John > David > Jane > John
--  Jane > John > David > Jane
--  David > Jane > John > David
-- (3 rows)

-- ------------------------------------------------------------
-- Exercise 10
-- List the customers who have bought products from more than one
-- category, with the categories, not counting cancelled orders.
-- (Chapters 11 and 12)
-- ------------------------------------------------------------
-- 10. Customers who buy across categories
SELECT c.first_name, c.last_name,
       STRING_AGG(DISTINCT p.category, ', '
                  ORDER BY p.category)
           AS categories
FROM customers c
JOIN orders o
    ON o.customer_id = c.customer_id
JOIN order_items oi
    ON oi.order_id = o.order_id
JOIN products p
    ON p.product_id = oi.product_id
WHERE o.status <> 'cancelled'
GROUP BY c.customer_id, c.first_name,
         c.last_name
HAVING COUNT(DISTINCT p.category) > 1
ORDER BY c.customer_id;

-- Result:
--  first_name | last_name |      categories
-- ------------+-----------+----------------------
--  Alice      | Brown     | Electronics, Kitchen
--  Dana       | Kim       | Furniture, Kitchen
-- (2 rows)

-- ------------------------------------------------------------
-- Exercise 11
-- A monthly report totals March 2024 sales with WHERE
-- TO_CHAR(sale_date, 'YYYY-MM') = '2024-03', and reads the whole
-- table. Build a 20,000-row sales_history table with
-- generate_series, index its sale_date and rewrite the condition so
-- that EXPLAIN shows the index in use. (Chapters 19 and 22)
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 11. A range on the bare column can use
--     the index
DROP TABLE IF EXISTS sales_history;

CREATE TABLE sales_history (
    sale_id   INT PRIMARY KEY,
    sale_date DATE NOT NULL,
    amount    DECIMAL(10, 2) NOT NULL
);

INSERT INTO sales_history
    (sale_id, sale_date, amount)
SELECT n,
       DATE '2023-01-01' + n / 20,
       n % 300 + 0.99
FROM generate_series(1, 20000) n;

CREATE INDEX idx_sales_history_date
    ON sales_history (sale_date);

ANALYZE sales_history;

EXPLAIN (COSTS OFF)
SELECT SUM(amount) AS march_sales
FROM sales_history
WHERE sale_date >= DATE '2024-03-01'
    AND sale_date < DATE '2024-04-01';

ROLLBACK TO SAVEPOINT example;

-- Plan:
--   Aggregate
--     ->  Index Scan using idx_sales_history_date on sales_history
--           Index Cond: ((sale_date >= '2024-03-01'::date) AND (sale_date < '2024-04-01'::date))

-- ------------------------------------------------------------
-- Exercise 12
-- Write a procedure that gives every employee in a department a
-- percentage raise. It should reject a raise of 0 or less or of more
-- than 10 percent, a department that doesn't exist and a department
-- with no employees. Give Finance a 3.5% raise. (Chapter 23)
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 12. Check the input, then change the rows
DROP PROCEDURE IF EXISTS raise_department_pay;

CREATE PROCEDURE raise_department_pay(
    p_dept_id INT,
    p_pct     DECIMAL)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_pct IS NULL OR p_pct <= 0
       OR p_pct > 10 THEN
        RAISE EXCEPTION 'Raise of % not allowed',
            p_pct;
    ELSIF NOT EXISTS (
        SELECT 1 FROM departments
        WHERE department_id = p_dept_id
    ) THEN
        RAISE EXCEPTION 'Department % not found',
            p_dept_id;
    END IF;

    UPDATE employees
    SET salary = ROUND(salary
                       * (1 + p_pct / 100), 2)
    WHERE department_id = p_dept_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Department % has no employees',
            p_dept_id;
    END IF;
END;
$$;

CALL raise_department_pay(20, 3.5);

SELECT employee_id, first_name, salary
FROM employees
WHERE department_id = 20
ORDER BY employee_id;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  employee_id | first_name |  salary
-- -------------+------------+----------
--            2 | Jane       | 91080.00
--            6 | David      | 69345.00
-- (2 rows)

-- ------------------------------------------------------------
-- Exercise 13
-- Keep a log of product price changes, with the old and new price,
-- written by a trigger. Raise Electronics prices by 5%, then run an
-- UPDATE that restocks the Coffee Mug and sets its price to the
-- value it already has. Show the log with each change as a
-- percentage. (Chapter 25)
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 13. An audit trigger for prices
DROP TRIGGER IF EXISTS products_price_audit
    ON products;
DROP FUNCTION IF EXISTS log_price_change;
DROP TABLE IF EXISTS product_price_log;

CREATE TABLE product_price_log (
    log_id     INT GENERATED ALWAYS AS IDENTITY
               PRIMARY KEY,
    product_id INT NOT NULL,
    old_price  DECIMAL(10, 2) NOT NULL,
    new_price  DECIMAL(10, 2) NOT NULL,
    changed_at TIMESTAMP WITH TIME ZONE NOT NULL
               DEFAULT CURRENT_TIMESTAMP
);

CREATE FUNCTION log_price_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO product_price_log
        (product_id, old_price, new_price)
    VALUES (OLD.product_id, OLD.price,
            NEW.price);
    RETURN NULL;
END;
$$;

CREATE TRIGGER products_price_audit
AFTER UPDATE OF price ON products
FOR EACH ROW
WHEN (OLD.price IS DISTINCT FROM NEW.price)
EXECUTE FUNCTION log_price_change();

UPDATE products
SET price = ROUND(price * 1.05, 2)
WHERE category = 'Electronics';

UPDATE products
SET price = 10.99,
    stock = stock + 50
WHERE product_id = 5;

SELECT l.product_id, p.product_name,
       l.old_price, l.new_price,
       ROUND(100 * (l.new_price - l.old_price)
             / l.old_price, 1) AS pct_change
FROM product_price_log l
JOIN products p
    ON p.product_id = l.product_id
ORDER BY l.product_id;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  product_id | product_name | old_price | new_price | pct_change
-- ------------+--------------+-----------+-----------+------------
--           1 | Laptop       |   1200.00 |   1260.00 |        5.0
--           2 | Smartphone   |    800.00 |    840.00 |        5.0
--           3 | Tablet       |    450.00 |    472.50 |        5.0
--           4 | Monitor      |    300.00 |    315.00 |        5.0
-- (4 rows)

-- ------------------------------------------------------------
-- Exercise 14
-- Create a room_bookings table for one-hour meeting slots that can't
-- hold two bookings for the same room and hour. Write a function
-- that books a slot and, if it's already taken, returns who has it
-- instead of failing. Book the Oak room at 10:00 on March 4, 2024
-- for Michael (4), then for Sarah (5), then book the Elm room at the
-- same hour for Sarah. (Chapters 26 and 34)
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 14. The key stops a double booking; the
--     handler reports it
DROP FUNCTION IF EXISTS book_room;
DROP TABLE IF EXISTS room_bookings;

CREATE TABLE room_bookings (
    room_name   VARCHAR(30) NOT NULL,
    slot_date   DATE NOT NULL,
    start_hour  INT NOT NULL
        CHECK (start_hour BETWEEN 8 AND 17),
    employee_id INT NOT NULL
        REFERENCES employees (employee_id),
    PRIMARY KEY (room_name, slot_date,
                 start_hour)
);

CREATE FUNCTION book_room(
    p_room        VARCHAR(30),
    p_date        DATE,
    p_hour        INT,
    p_employee_id INT)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_holder INT;
BEGIN
    INSERT INTO room_bookings
        (room_name, slot_date, start_hour,
         employee_id)
    VALUES (p_room, p_date, p_hour,
            p_employee_id);
    RETURN 'booked';
EXCEPTION
    WHEN unique_violation THEN
        SELECT employee_id INTO v_holder
        FROM room_bookings
        WHERE room_name = p_room
            AND slot_date = p_date
            AND start_hour = p_hour;
        RETURN 'taken by employee ' || v_holder;
END;
$$;

SELECT v.call_no, v.room, v.emp_id,
       book_room(v.room, v.slot_date, v.hour,
                 v.emp_id) AS result
FROM (VALUES
        (1, 'Oak', DATE '2024-03-04', 10, 4),
        (2, 'Oak', DATE '2024-03-04', 10, 5),
        (3, 'Elm', DATE '2024-03-04', 10, 5))
     v (call_no, room, slot_date, hour, emp_id)
ORDER BY v.call_no;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  call_no | room | emp_id |       result
-- ---------+------+--------+---------------------
--        1 | Oak  |      4 | booked
--        2 | Oak  |      5 | taken by employee 4
--        3 | Elm  |      5 | booked
-- (3 rows)

-- ------------------------------------------------------------
-- Exercise 15
-- Create a payment_log table partitioned by quarter for 2024, with
-- twenty payments a day. Use EXPLAIN to show that a total of the
-- payments from February 15 to May 14 reads only the partitions it
-- needs. (Chapter 27)
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 15. Four quarterly partitions
DROP TABLE IF EXISTS payment_log;

CREATE TABLE payment_log (
    payment_id INT NOT NULL,
    paid_on    DATE NOT NULL,
    amount     DECIMAL(10, 2) NOT NULL,
    PRIMARY KEY (payment_id, paid_on)
) PARTITION BY RANGE (paid_on);

CREATE TABLE payment_log_q1
    PARTITION OF payment_log
    FOR VALUES FROM (DATE '2024-01-01')
               TO (DATE '2024-04-01');
CREATE TABLE payment_log_q2
    PARTITION OF payment_log
    FOR VALUES FROM (DATE '2024-04-01')
               TO (DATE '2024-07-01');
CREATE TABLE payment_log_q3
    PARTITION OF payment_log
    FOR VALUES FROM (DATE '2024-07-01')
               TO (DATE '2024-10-01');
CREATE TABLE payment_log_q4
    PARTITION OF payment_log
    FOR VALUES FROM (DATE '2024-10-01')
               TO (DATE '2025-01-01');

INSERT INTO payment_log
    (payment_id, paid_on, amount)
SELECT n,
       DATE '2024-01-01' + (n - 1) / 20,
       n % 400 + 5.00
FROM generate_series(1, 7320) n;

ANALYZE payment_log;

EXPLAIN (COSTS OFF)
SELECT SUM(amount) AS total_paid
FROM payment_log
WHERE paid_on >= DATE '2024-02-15'
    AND paid_on < DATE '2024-05-15';

ROLLBACK TO SAVEPOINT example;

-- Plan:
--   Aggregate
--     ->  Append
--           ->  Seq Scan on payment_log_q1 payment_log_1
--                 Filter: ((paid_on >= '2024-02-15'::date) AND (paid_on < '2024-05-15'::date))
--           ->  Seq Scan on payment_log_q2 payment_log_2
--                 Filter: ((paid_on >= '2024-02-15'::date) AND (paid_on < '2024-05-15'::date))

-- ------------------------------------------------------------
-- Exercise 16
-- The pricing team wants to try a 10% cut in Electronics prices
-- without touching the live prices. Copy products into a new schema,
-- price_review. Then use SET LOCAL to put that schema first on the
-- search path, so that an UPDATE of products without a schema name
-- changes the copy. Compare the live and review prices. (Chapter 29)
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 16. The first schema on the path wins
DROP SCHEMA IF EXISTS price_review CASCADE;

CREATE SCHEMA price_review;

CREATE TABLE price_review.products AS
SELECT product_id, product_name, category,
       price
FROM public.products;

SET LOCAL search_path = price_review, public;

UPDATE products
SET price = ROUND(price * 0.9, 2)
WHERE category = 'Electronics';

SELECT p.product_name,
       p.price AS live_price,
       r.price AS review_price
FROM public.products p
JOIN price_review.products r
    ON r.product_id = p.product_id
ORDER BY p.product_id;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  product_name | live_price | review_price
-- --------------+------------+--------------
--  Laptop       |    1200.00 |      1080.00
--  Smartphone   |     800.00 |       720.00
--  Tablet       |     450.00 |       405.00
--  Monitor      |     300.00 |       270.00
--  Coffee Mug   |      10.99 |        10.99
--  Desk Chair   |     249.00 |       249.00
-- (6 rows)

-- ------------------------------------------------------------
-- Exercise 17
-- A nightly check reports how many rows each sample table holds.
-- Write a function that takes a schema name and a table name and
-- counts the table's rows, quoting both names safely, and use it on
-- the seven sample tables. (Chapter 31)
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 17. %I quotes each name separately
DROP FUNCTION IF EXISTS table_row_count;

CREATE FUNCTION table_row_count(
    p_schema TEXT,
    p_table  TEXT)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    n BIGINT;
BEGIN
    EXECUTE format(
        'SELECT COUNT(*) FROM %I.%I',
        p_schema, p_table)
        INTO n;
    RETURN n;
END;
$$;

SELECT t.table_name,
       table_row_count('public', t.table_name)
           AS row_count
FROM (VALUES ('customers'), ('departments'),
             ('employees'), ('order_items'),
             ('orders'), ('products'),
             ('projects'))
     t (table_name)
ORDER BY t.table_name;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  table_name  | row_count
-- -------------+-----------
--  customers   |         5
--  departments |         5
--  employees   |         8
--  order_items |        10
--  orders      |         6
--  products    |         6
--  projects    |         4
-- (7 rows)

-- ------------------------------------------------------------
-- Exercise 18
-- A spreadsheet of distributors arrives with one row per product a
-- distributor sells, repeating the distributor's name and phone on
-- each row. Load it into a temporary table, then split it into a
-- distributors table and a linking table between products and
-- distributors. List each product's distributors, cheapest first,
-- with the margin between the product's price and the distributor's
-- cost. (Chapters 32 and 33)
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 18. One row per distributor, and one per
--     product and distributor pair
DROP TABLE IF EXISTS product_distributors,
    distributors, distributor_sheet;

CREATE TEMPORARY TABLE distributor_sheet (
    distributor_name VARCHAR(50) NOT NULL,
    phone            VARCHAR(20) NOT NULL,
    product_id       INT NOT NULL,
    unit_cost        DECIMAL(10, 2) NOT NULL
);

INSERT INTO distributor_sheet
    (distributor_name, phone, product_id,
     unit_cost)
VALUES
    ('Apex Wholesale', '555-0101', 1, 950.00),
    ('Apex Wholesale', '555-0101', 2, 610.00),
    ('Apex Wholesale', '555-0101', 4, 220.00),
    ('Brightline Goods', '555-0102', 2, 595.00),
    ('Brightline Goods', '555-0102', 3, 330.00),
    ('Brightline Goods', '555-0102', 5, 4.25),
    ('Cedar Trading', '555-0103', 5, 3.90),
    ('Cedar Trading', '555-0103', 6, 180.00);

CREATE TABLE distributors (
    distributor_id   INT GENERATED ALWAYS
                     AS IDENTITY PRIMARY KEY,
    distributor_name VARCHAR(50) NOT NULL
                     UNIQUE,
    phone            VARCHAR(20) NOT NULL
);

CREATE TABLE product_distributors (
    product_id     INT NOT NULL
        REFERENCES products (product_id),
    distributor_id INT NOT NULL
        REFERENCES distributors
            (distributor_id),
    unit_cost      DECIMAL(10, 2) NOT NULL,
    PRIMARY KEY (product_id, distributor_id)
);

INSERT INTO distributors
    (distributor_name, phone)
SELECT DISTINCT distributor_name, phone
FROM distributor_sheet
ORDER BY distributor_name;

INSERT INTO product_distributors
    (product_id, distributor_id, unit_cost)
SELECT s.product_id, d.distributor_id,
       s.unit_cost
FROM distributor_sheet s
JOIN distributors d
    ON d.distributor_name = s.distributor_name;

SELECT p.product_name, d.distributor_name,
       pd.unit_cost,
       p.price - pd.unit_cost AS margin
FROM product_distributors pd
JOIN products p
    ON p.product_id = pd.product_id
JOIN distributors d
    ON d.distributor_id = pd.distributor_id
ORDER BY p.product_id, pd.unit_cost;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  product_name | distributor_name | unit_cost | margin
-- --------------+------------------+-----------+--------
--  Laptop       | Apex Wholesale   |    950.00 | 250.00
--  Smartphone   | Brightline Goods |    595.00 | 205.00
--  Smartphone   | Apex Wholesale   |    610.00 | 190.00
--  Tablet       | Brightline Goods |    330.00 | 120.00
--  Monitor      | Apex Wholesale   |    220.00 |  80.00
--  Coffee Mug   | Cedar Trading    |      3.90 |   7.09
--  Coffee Mug   | Brightline Goods |      4.25 |   6.74
--  Desk Chair   | Cedar Trading    |    180.00 |  69.00
-- (8 rows)

-- ------------------------------------------------------------
-- Exercise 19
-- A web shop sends each new order as one JSON document with the
-- order's ID, customer, date and an array of items. Load order 108
-- from a document into orders and order_items, taking each unit
-- price from products, and show the new order's lines. (Chapter 37)
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 19. The header from ->>, the lines from
--     jsonb_to_recordset
DROP TABLE IF EXISTS incoming_orders;

CREATE TEMPORARY TABLE incoming_orders (
    doc JSONB NOT NULL
);

INSERT INTO incoming_orders (doc)
VALUES ('{"order_id": 108,
          "customer_id": 4,
          "order_date": "2024-03-21",
          "items": [
              {"product_id": 3, "quantity": 1},
              {"product_id": 5, "quantity": 2}
          ]}');

INSERT INTO orders
    (order_id, customer_id, order_date, status)
SELECT CAST(doc ->> 'order_id' AS INT),
       CAST(doc ->> 'customer_id' AS INT),
       CAST(doc ->> 'order_date' AS DATE),
       'processing'
FROM incoming_orders;

INSERT INTO order_items
    (order_id, product_id, quantity, unit_price)
SELECT CAST(i.doc ->> 'order_id' AS INT),
       r.product_id, r.quantity, p.price
FROM incoming_orders i
CROSS JOIN LATERAL
    jsonb_to_recordset(i.doc -> 'items')
        r(product_id INT, quantity INT)
JOIN products p
    ON p.product_id = r.product_id;

SELECT o.order_id, o.order_date,
       p.product_name, oi.quantity,
       oi.unit_price,
       oi.quantity * oi.unit_price AS line_total
FROM orders o
JOIN order_items oi
    ON oi.order_id = o.order_id
JOIN products p
    ON p.product_id = oi.product_id
WHERE o.order_id = 108
ORDER BY p.product_id;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  order_id | order_date | product_name | quantity | unit_price | line_total
-- ----------+------------+--------------+----------+------------+------------
--       108 | 2024-03-21 | Tablet       |        1 |     450.00 |     450.00
--       108 | 2024-03-21 | Coffee Mug   |        2 |      10.99 |      21.98
-- (2 rows)

-- ------------------------------------------------------------
-- Exercise 20
-- This query should list every department with its payroll and the
-- total budget of its projects. It returns only three departments,
-- and some of the totals are too big. Find the causes and fix it.
-- (Chapters 18 and 38)
-- ------------------------------------------------------------
-- 20. Total each table before joining, and
--     keep every department
WITH dept_pay AS (
    SELECT department_id,
           SUM(salary) AS payroll
    FROM employees
    GROUP BY department_id
),
dept_budgets AS (
    SELECT department_id,
           SUM(budget) AS project_budget
    FROM projects
    GROUP BY department_id
)
SELECT d.department_name,
       COALESCE(dp.payroll, 0.00) AS payroll,
       COALESCE(db.project_budget, 0.00)
           AS project_budget
FROM departments d
LEFT JOIN dept_pay dp
    ON dp.department_id = d.department_id
LEFT JOIN dept_budgets db
    ON db.department_id = d.department_id
ORDER BY d.department_id;

-- Result:
--  department_name |  payroll  | project_budget
-- -----------------+-----------+----------------
--  Executive       | 150000.00 |           0.00
--  Finance         | 155000.00 |       50000.00
--  Engineering     | 289000.00 |      135000.00
--  Sales           |  58000.00 |       45000.00
--  Legal           |      0.00 |           0.00
-- (5 rows)

-- ------------------------------------------------------------
-- Example 2: Answers
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

DROP TRIGGER IF EXISTS products_price_audit
    ON products;
DROP FUNCTION IF EXISTS log_price_change,
    book_room, table_row_count;
DROP PROCEDURE IF EXISTS raise_department_pay;
DROP VIEW IF EXISTS department_sizes;
DROP TABLE IF EXISTS product_distributors,
    distributors, payment_log,
    product_price_log, room_bookings,
    sales_history;
DROP SCHEMA IF EXISTS price_review CASCADE;

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Undo everything this file changed.
-- ------------------------------------------------------------
ROLLBACK;
