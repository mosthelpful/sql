-- The Most Helpful SQL Guide, Second Edition
-- Chapter 14: Dates and Times
--
-- Every example in this part of the book that runs on PostgreSQL,
-- in book order, with the result the book prints. Load
-- sample_db.sql first. To run the whole file in psql:
--   psql -d sqlguide -f chapters/ch14_dates_times.sql
-- It runs as one transaction and rolls back at the end, so your
-- database is left unchanged. Examples that change data or fail on
-- purpose are wrapped in a savepoint and undone, as in the book.
-- You can also copy any single example into a query window.

BEGIN;

-- ------------------------------------------------------------
-- Example 1: The Current Date and Time
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

SELECT CURRENT_DATE AS today,
       CURRENT_TIMESTAMP AS right_now,
       NOW() AS also_now;

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Example 2: Extracting Parts of a Date
-- ------------------------------------------------------------
SELECT order_id, order_date,
       EXTRACT(YEAR FROM order_date) AS year,
       EXTRACT(MONTH FROM order_date) AS month,
       EXTRACT(DOW FROM order_date) AS weekday
FROM orders
ORDER BY order_id;

-- Result:
--  order_id | order_date | year | month | weekday
-- ----------+------------+------+-------+---------
--       101 | 2024-01-15 | 2024 |     1 |       1
--       102 | 2024-01-16 | 2024 |     1 |       2
--       103 | 2024-01-17 | 2024 |     1 |       3
--       104 | 2024-02-03 | 2024 |     2 |       6
--       105 | 2024-02-10 | 2024 |     2 |       6
--       106 | 2024-03-05 | 2024 |     3 |       2
-- (6 rows)

-- ------------------------------------------------------------
-- Example 3: Adding and Subtracting Intervals
-- ------------------------------------------------------------
SELECT order_id, order_date,
       order_date + 30 AS due_date,
       CAST(order_date + INTERVAL '1 month'
            AS DATE) AS follow_up
FROM orders
ORDER BY order_id;

-- Result:
--  order_id | order_date |  due_date  | follow_up
-- ----------+------------+------------+------------
--       101 | 2024-01-15 | 2024-02-14 | 2024-02-15
--       102 | 2024-01-16 | 2024-02-15 | 2024-02-16
--       103 | 2024-01-17 | 2024-02-16 | 2024-02-17
--       104 | 2024-02-03 | 2024-03-04 | 2024-03-03
--       105 | 2024-02-10 | 2024-03-11 | 2024-03-10
--       106 | 2024-03-05 | 2024-04-04 | 2024-04-05
-- (6 rows)

-- ------------------------------------------------------------
-- Example 4: Adding and Subtracting Intervals
-- ------------------------------------------------------------
SELECT DATE '2024-01-31' + INTERVAL '1 month'
           AS jan_31_plus,
       DATE '2024-03-31' - INTERVAL '1 month'
           AS mar_31_minus;

-- Result:
--      jan_31_plus     |    mar_31_minus
-- ---------------------+---------------------
--  2024-02-29 00:00:00 | 2024-02-29 00:00:00
-- (1 row)

-- ------------------------------------------------------------
-- Example 5: The Difference Between Two Dates
-- ------------------------------------------------------------
SELECT o.order_id, c.first_name,
       c.created_on, o.order_date,
       o.order_date - c.created_on AS days_later
FROM orders o
JOIN customers c
    ON c.customer_id = o.customer_id
ORDER BY o.order_id;

-- Result:
--  order_id | first_name | created_on | order_date | days_later
-- ----------+------------+------------+------------+------------
--       101 | Alice      | 2020-01-15 | 2024-01-15 |       1461
--       102 | Bob        | 2019-08-09 | 2024-01-16 |       1621
--       103 | Charlie    | 2021-07-19 | 2024-01-17 |        912
--       104 | Alice      | 2020-01-15 | 2024-02-03 |       1480
--       105 | Dana       | 2023-03-02 | 2024-02-10 |        345
--       106 | Charlie    | 2021-07-19 | 2024-03-05 |        960
-- (6 rows)

-- ------------------------------------------------------------
-- Example 6: Grouping by Month
-- ------------------------------------------------------------
SELECT CAST(DATE_TRUNC('month', o.order_date)
            AS DATE) AS order_month,
       COUNT(DISTINCT o.order_id) AS orders,
       SUM(oi.quantity * oi.unit_price) AS sales
FROM orders o
JOIN order_items oi
    ON oi.order_id = o.order_id
WHERE o.status <> 'cancelled'
GROUP BY DATE_TRUNC('month', o.order_date)
ORDER BY order_month;

-- Result:
--  order_month | orders |  sales
-- -------------+--------+---------
--  2024-01-01  |      2 | 2021.98
--  2024-02-01  |      2 | 2092.96
--  2024-03-01  |      1 | 1100.00
-- (3 rows)

-- ------------------------------------------------------------
-- Example 7: Formatting Dates
-- ------------------------------------------------------------
SELECT order_id,
       TO_CHAR(order_date, 'YYYY-MM') AS period,
       TO_CHAR(order_date, 'FMMonth FMDD, YYYY')
           AS long_form,
       TO_CHAR(order_date, 'Dy') AS day
FROM orders
ORDER BY order_id;

-- Result:
--  order_id | period  |     long_form     | day
-- ----------+---------+-------------------+-----
--       101 | 2024-01 | January 15, 2024  | Mon
--       102 | 2024-01 | January 16, 2024  | Tue
--       103 | 2024-01 | January 17, 2024  | Wed
--       104 | 2024-02 | February 3, 2024  | Sat
--       105 | 2024-02 | February 10, 2024 | Sat
--       106 | 2024-03 | March 5, 2024     | Tue
-- (6 rows)

-- ------------------------------------------------------------
-- Example 8: Filtering by Period
-- ------------------------------------------------------------
SELECT order_id, order_date, status
FROM orders
WHERE order_date >= DATE '2024-02-01'
    AND order_date < DATE '2024-03-01'
ORDER BY order_id;

-- Result:
--  order_id | order_date |   status
-- ----------+------------+------------
--       104 | 2024-02-03 | shipped
--       105 | 2024-02-10 | processing
-- (2 rows)

-- ------------------------------------------------------------
-- Example 9: Filtering by Period
-- Sets up data for the examples that follow.
-- ------------------------------------------------------------
CREATE TEMPORARY TABLE payments (
    payment_id INT PRIMARY KEY,
    paid_at    TIMESTAMP NOT NULL
);

INSERT INTO payments (payment_id, paid_at)
VALUES
    (1, TIMESTAMP '2024-02-01 00:00:00'),
    (2, TIMESTAMP '2024-02-29 15:45:00'),
    (3, TIMESTAMP '2024-03-01 00:00:00');

-- ------------------------------------------------------------
-- Example 10: Filtering by Period
-- ------------------------------------------------------------
SELECT payment_id, paid_at,
       paid_at BETWEEN DATE '2024-02-01'
                   AND DATE '2024-02-29'
           AS to_29th,
       paid_at BETWEEN DATE '2024-02-01'
                   AND DATE '2024-03-01'
           AS to_1st,
       paid_at >= DATE '2024-02-01'
           AND paid_at < DATE '2024-03-01'
           AS half_open
FROM payments
ORDER BY payment_id;

-- Result:
--  payment_id |       paid_at       | to_29th | to_1st | half_open
-- ------------+---------------------+---------+--------+-----------
--           1 | 2024-02-01 00:00:00 | true    | true   | true
--           2 | 2024-02-29 15:45:00 | false   | true   | true
--           3 | 2024-03-01 00:00:00 | false   | true   | false
-- (3 rows)

-- ------------------------------------------------------------
-- Example 11: Time Zones
-- ------------------------------------------------------------
SELECT TIMESTAMP WITH TIME ZONE
           '2024-03-05 09:30:00+00'
           AT TIME ZONE 'America/New_York'
           AS march_5,
       TIMESTAMP WITH TIME ZONE
           '2024-03-15 09:30:00+00'
           AT TIME ZONE 'America/New_York'
           AS march_15;

-- Result:
--        march_5       |      march_15
-- ---------------------+---------------------
--  2024-03-05 04:30:00 | 2024-03-15 05:30:00
-- (1 row)

-- ------------------------------------------------------------
-- Try It 1
-- List the employees hired in 2019 or 2020, using a half-open range.
-- ------------------------------------------------------------
-- 1. Employees hired in 2019 or 2020
SELECT first_name, last_name, hire_date
FROM employees
WHERE hire_date >= DATE '2019-01-01'
    AND hire_date < DATE '2021-01-01'
ORDER BY hire_date;

-- Result:
--  first_name | last_name | hire_date
-- ------------+-----------+------------
--  David      | Brown     | 2019-11-12
--  Sarah      | Chen      | 2020-02-03
-- (2 rows)

-- ------------------------------------------------------------
-- Try It 2
-- Count the orders placed in each month, labeled like 'Jan 2024', in
-- date order.
-- ------------------------------------------------------------
-- 2. Orders per month, labeled, in date order
SELECT TO_CHAR(DATE_TRUNC('month', order_date),
               'Mon YYYY') AS order_month,
       COUNT(*) AS orders
FROM orders
GROUP BY DATE_TRUNC('month', order_date)
ORDER BY DATE_TRUNC('month', order_date);

-- Result:
--  order_month | orders
-- -------------+--------
--  Jan 2024    |      3
--  Feb 2024    |      2
--  Mar 2024    |      1
-- (3 rows)

-- ------------------------------------------------------------
-- Try It 3
-- A call is set for 9:00 a.m. New York time on March 15, 2024. What
-- time is it then in London and in Tokyo?
-- ------------------------------------------------------------
-- 3. A New York call in London and Tokyo
SELECT TIMESTAMP '2024-03-15 09:00'
           AT TIME ZONE 'America/New_York'
           AT TIME ZONE 'Europe/London'
           AS london,
       TIMESTAMP '2024-03-15 09:00'
           AT TIME ZONE 'America/New_York'
           AT TIME ZONE 'Asia/Tokyo'
           AS tokyo;

-- Result:
--        london        |        tokyo
-- ---------------------+---------------------
--  2024-03-15 13:00:00 | 2024-03-15 22:00:00
-- (1 row)

-- ------------------------------------------------------------
-- Undo everything this file changed.
-- ------------------------------------------------------------
ROLLBACK;
