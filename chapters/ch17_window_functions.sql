-- The Most Helpful SQL Guide, Second Edition
-- Chapter 17: Window Functions
--
-- Every example in this part of the book that runs on PostgreSQL,
-- in book order, with the result the book prints. Load
-- sample_db.sql first. To run the whole file in psql:
--   psql -d sqlguide -f chapters/ch17_window_functions.sql
-- It runs as one transaction and rolls back at the end, so your
-- database is left unchanged. Examples that change data or fail on
-- purpose are wrapped in a savepoint and undone, as in the book.
-- You can also copy any single example into a query window.

BEGIN;

-- ------------------------------------------------------------
-- Example 1: Windows Versus GROUP BY
-- ------------------------------------------------------------
SELECT first_name,
       department_id,
       salary,
       ROUND(AVG(salary) OVER (
           PARTITION BY department_id
       ), 2) AS dept_avg
FROM employees
ORDER BY department_id, employee_id;

-- Result:
--  first_name | department_id |  salary   | dept_avg
-- ------------+---------------+-----------+-----------
--  John       |            10 | 150000.00 | 150000.00
--  Jane       |            20 |  88000.00 |  77500.00
--  David      |            20 |  67000.00 |  77500.00
--  Emily      |            30 | 105000.00 |  96333.33
--  Michael    |            30 |  92000.00 |  96333.33
--  Sarah      |            30 |  92000.00 |  96333.33
--  Priya      |            40 |  58000.00 |  58000.00
--  Tom        |          NULL |  71000.00 |  71000.00
-- (8 rows)

-- ------------------------------------------------------------
-- Example 2: Ranking Rows
-- ------------------------------------------------------------
SELECT first_name,
       salary,
       ROW_NUMBER() OVER (
           ORDER BY salary DESC, employee_id
       ) AS row_num,
       RANK() OVER (
           ORDER BY salary DESC
       ) AS salary_rank,
       DENSE_RANK() OVER (
           ORDER BY salary DESC
       ) AS dense_salary_rank
FROM employees
ORDER BY salary DESC, employee_id;

-- Result:
--  first_name |  salary   | row_num | salary_rank | dense_salary_rank
-- ------------+-----------+---------+-------------+-------------------
--  John       | 150000.00 |       1 |           1 |                 1
--  Emily      | 105000.00 |       2 |           2 |                 2
--  Michael    |  92000.00 |       3 |           3 |                 3
--  Sarah      |  92000.00 |       4 |           3 |                 3
--  Jane       |  88000.00 |       5 |           5 |                 4
--  Tom        |  71000.00 |       6 |           6 |                 5
--  David      |  67000.00 |       7 |           7 |                 6
--  Priya      |  58000.00 |       8 |           8 |                 7
-- (8 rows)

-- ------------------------------------------------------------
-- Example 3: Ranking within groups
-- ------------------------------------------------------------
SELECT department_id,
       first_name,
       salary,
       RANK() OVER (
           PARTITION BY department_id
           ORDER BY salary DESC
       ) AS dept_salary_rank
FROM employees
ORDER BY department_id, dept_salary_rank,
         employee_id;

-- Result:
--  department_id | first_name |  salary   | dept_salary_rank
-- ---------------+------------+-----------+------------------
--             10 | John       | 150000.00 |                1
--             20 | Jane       |  88000.00 |                1
--             20 | David      |  67000.00 |                2
--             30 | Emily      | 105000.00 |                1
--             30 | Michael    |  92000.00 |                2
--             30 | Sarah      |  92000.00 |                2
--             40 | Priya      |  58000.00 |                1
--           NULL | Tom        |  71000.00 |                1
-- (8 rows)

-- ------------------------------------------------------------
-- Example 4: Top N per Group
-- Fails on purpose, to show the error.
-- ------------------------------------------------------------
SAVEPOINT example;

SELECT department_id, first_name, salary
FROM employees
WHERE ROW_NUMBER() OVER (
          PARTITION BY department_id
          ORDER BY salary DESC) = 1;

ROLLBACK TO SAVEPOINT example;

-- Expected error:
--   ERROR:  window functions are not allowed in WHERE

-- ------------------------------------------------------------
-- Example 5: Top N per Group
-- ------------------------------------------------------------
SELECT department_id, first_name, salary
FROM (
    SELECT department_id,
           first_name,
           salary,
           ROW_NUMBER() OVER (
               PARTITION BY department_id
               ORDER BY salary DESC, employee_id
           ) AS row_num
    FROM employees
) ranked
WHERE row_num = 1
ORDER BY department_id;

-- Result:
--  department_id | first_name |  salary
-- ---------------+------------+-----------
--             10 | John       | 150000.00
--             20 | Jane       |  88000.00
--             30 | Emily      | 105000.00
--             40 | Priya      |  58000.00
--           NULL | Tom        |  71000.00
-- (5 rows)

-- ------------------------------------------------------------
-- Example 6: Top N per Group
-- ------------------------------------------------------------
SELECT DISTINCT ON (department_id)
       department_id, first_name, salary
FROM employees
ORDER BY department_id, salary DESC,
         employee_id;

-- Result:
--  department_id | first_name |  salary
-- ---------------+------------+-----------
--             10 | John       | 150000.00
--             20 | Jane       |  88000.00
--             30 | Emily      | 105000.00
--             40 | Priya      |  58000.00
--           NULL | Tom        |  71000.00
-- (5 rows)

-- ------------------------------------------------------------
-- Example 7: Order Totals
-- ------------------------------------------------------------
CREATE TEMPORARY TABLE order_totals AS
SELECT o.order_id,
       o.customer_id,
       o.order_date,
       SUM(oi.quantity * oi.unit_price) AS total
FROM orders o
JOIN order_items oi
    ON oi.order_id = o.order_id
GROUP BY o.order_id, o.customer_id,
         o.order_date;

SELECT order_id, customer_id, order_date, total
FROM order_totals
ORDER BY order_date;

-- Result:
--  order_id | customer_id | order_date |  total
-- ----------+-------------+------------+---------
--       101 |           1 | 2024-01-15 | 1221.98
--       102 |           2 | 2024-01-16 |  800.00
--       103 |           3 | 2024-01-17 |  900.00
--       104 |           1 | 2024-02-03 | 1800.00
--       105 |           4 | 2024-02-10 |  292.96
--       106 |           3 | 2024-03-05 | 1100.00
-- (6 rows)

-- ------------------------------------------------------------
-- Example 8: Comparing Rows: LAG and LEAD
-- ------------------------------------------------------------
SELECT customer_id,
       order_id,
       order_date,
       order_date - LAG(order_date) OVER (
           PARTITION BY customer_id
           ORDER BY order_date
       ) AS days_since_prev
FROM order_totals
ORDER BY customer_id, order_date;

-- Result:
--  customer_id | order_id | order_date | days_since_prev
-- -------------+----------+------------+-----------------
--            1 |      101 | 2024-01-15 |            NULL
--            1 |      104 | 2024-02-03 |              19
--            2 |      102 | 2024-01-16 |            NULL
--            3 |      103 | 2024-01-17 |            NULL
--            3 |      106 | 2024-03-05 |              48
--            4 |      105 | 2024-02-10 |            NULL
-- (6 rows)

-- ------------------------------------------------------------
-- Example 9: Running Totals
-- ------------------------------------------------------------
SELECT order_id,
       order_date,
       total,
       SUM(total) OVER (
           ORDER BY order_date
       ) AS running_total
FROM order_totals
ORDER BY order_date;

-- Result:
--  order_id | order_date |  total  | running_total
-- ----------+------------+---------+---------------
--       101 | 2024-01-15 | 1221.98 |       1221.98
--       102 | 2024-01-16 |  800.00 |       2021.98
--       103 | 2024-01-17 |  900.00 |       2921.98
--       104 | 2024-02-03 | 1800.00 |       4721.98
--       105 | 2024-02-10 |  292.96 |       5014.94
--       106 | 2024-03-05 | 1100.00 |       6114.94
-- (6 rows)

-- ------------------------------------------------------------
-- Example 10: The default frame
-- ------------------------------------------------------------
SELECT o.order_date,
       oi.product_id,
       oi.quantity * oi.unit_price AS line_total,
       SUM(oi.quantity * oi.unit_price) OVER (
           ORDER BY o.order_date
       ) AS range_total,
       SUM(oi.quantity * oi.unit_price) OVER (
           ORDER BY o.order_date, oi.product_id
           ROWS BETWEEN UNBOUNDED PRECEDING
                    AND CURRENT ROW
       ) AS rows_total
FROM orders o
JOIN order_items oi
    ON oi.order_id = o.order_id
WHERE o.order_date < DATE '2024-02-01'
ORDER BY o.order_date, oi.product_id;

-- Result:
--  order_date | product_id | line_total | range_total | rows_total
-- ------------+------------+------------+-------------+------------
--  2024-01-15 |          1 |    1200.00 |     1221.98 |    1200.00
--  2024-01-15 |          5 |      21.98 |     1221.98 |    1221.98
--  2024-01-16 |          2 |     800.00 |     2021.98 |    2021.98
--  2024-01-17 |          3 |     900.00 |     2921.98 |    2921.98
-- (4 rows)

-- ------------------------------------------------------------
-- Example 11: Moving Averages
-- ------------------------------------------------------------
SELECT order_id,
       order_date,
       total,
       ROUND(AVG(total) OVER (
           ORDER BY order_date
           ROWS BETWEEN 2 PRECEDING
                    AND CURRENT ROW
       ), 2) AS moving_avg
FROM order_totals
ORDER BY order_date;

-- Result:
--  order_id | order_date |  total  | moving_avg
-- ----------+------------+---------+------------
--       101 | 2024-01-15 | 1221.98 |    1221.98
--       102 | 2024-01-16 |  800.00 |    1010.99
--       103 | 2024-01-17 |  900.00 |     973.99
--       104 | 2024-02-03 | 1800.00 |    1166.67
--       105 | 2024-02-10 |  292.96 |     997.65
--       106 | 2024-03-05 | 1100.00 |    1064.32
-- (6 rows)

-- ------------------------------------------------------------
-- Example 12: NTILE and FIRST_VALUE
-- ------------------------------------------------------------
SELECT first_name,
       department_id,
       salary,
       NTILE(4) OVER (
           ORDER BY salary DESC
       ) AS salary_quartile,
       FIRST_VALUE(first_name) OVER (
           PARTITION BY department_id
           ORDER BY salary DESC
       ) AS dept_top_earner
FROM employees
ORDER BY salary DESC, employee_id;

-- Result:
--  first_name | department_id |  salary   | salary_quartile | dept_top_earner
-- ------------+---------------+-----------+-----------------+-----------------
--  John       |            10 | 150000.00 |               1 | John
--  Emily      |            30 | 105000.00 |               1 | Emily
--  Michael    |            30 |  92000.00 |               2 | Emily
--  Sarah      |            30 |  92000.00 |               2 | Emily
--  Jane       |            20 |  88000.00 |               3 | Jane
--  Tom        |          NULL |  71000.00 |               3 | Tom
--  David      |            20 |  67000.00 |               4 | Jane
--  Priya      |            40 |  58000.00 |               4 | Priya
-- (8 rows)

-- ------------------------------------------------------------
-- Example 13: Named Windows
-- ------------------------------------------------------------
SELECT order_id,
       order_date,
       total,
       LAG(total) OVER w AS prev_total,
       total - LAG(total) OVER w AS difference
FROM order_totals
WINDOW w AS (ORDER BY order_date)
ORDER BY order_date;

-- Result:
--  order_id | order_date |  total  | prev_total | difference
-- ----------+------------+---------+------------+------------
--       101 | 2024-01-15 | 1221.98 |       NULL |       NULL
--       102 | 2024-01-16 |  800.00 |    1221.98 |    -421.98
--       103 | 2024-01-17 |  900.00 |     800.00 |     100.00
--       104 | 2024-02-03 | 1800.00 |     900.00 |     900.00
--       105 | 2024-02-10 |  292.96 |    1800.00 |   -1507.04
--       106 | 2024-03-05 | 1100.00 |     292.96 |     807.04
-- (6 rows)

-- ------------------------------------------------------------
-- Try It 1
-- List the two highest-paid employees in each department, keeping
-- ties.
-- ------------------------------------------------------------
-- 1. Top two earners per department, with ties
SELECT department_id, first_name, salary
FROM (
    SELECT department_id,
           first_name,
           salary,
           RANK() OVER (
               PARTITION BY department_id
               ORDER BY salary DESC
           ) AS dept_salary_rank
    FROM employees
) ranked
WHERE dept_salary_rank <= 2
ORDER BY department_id, salary DESC, first_name;

-- Result:
--  department_id | first_name |  salary
-- ---------------+------------+-----------
--             10 | John       | 150000.00
--             20 | Jane       |  88000.00
--             20 | David      |  67000.00
--             30 | Emily      | 105000.00
--             30 | Michael    |  92000.00
--             30 | Sarah      |  92000.00
--             40 | Priya      |  58000.00
--           NULL | Tom        |  71000.00
-- (8 rows)

-- ------------------------------------------------------------
-- Try It 2
-- List the employees in order of hire date, with a running total of
-- their salaries: the payroll after each hire.
-- ------------------------------------------------------------
-- 2. Payroll after each hire
SELECT first_name,
       hire_date,
       salary,
       SUM(salary) OVER (
           ORDER BY hire_date, employee_id
           ROWS BETWEEN UNBOUNDED PRECEDING
                    AND CURRENT ROW
       ) AS payroll
FROM employees
ORDER BY hire_date, employee_id;

-- Result:
--  first_name | hire_date  |  salary   |  payroll
-- ------------+------------+-----------+-----------
--  John       | 2015-06-15 | 150000.00 | 150000.00
--  Jane       | 2016-09-23 |  88000.00 | 238000.00
--  Emily      | 2017-03-11 | 105000.00 | 343000.00
--  Michael    | 2018-05-29 |  92000.00 | 435000.00
--  David      | 2019-11-12 |  67000.00 | 502000.00
--  Sarah      | 2020-02-03 |  92000.00 | 594000.00
--  Priya      | 2021-08-30 |  58000.00 | 652000.00
--  Tom        | 2024-01-08 |  71000.00 | 723000.00
-- (8 rows)

-- ------------------------------------------------------------
-- Try It 3
-- Show each product's price as a percentage of the most expensive
-- product in its category, to one decimal place.
-- ------------------------------------------------------------
-- 3. Price as a percentage of the category's
--    most expensive product
SELECT product_name,
       category,
       price,
       ROUND(100 * price / MAX(price) OVER (
           PARTITION BY category
       ), 1) AS pct_of_max
FROM products
ORDER BY category, price DESC;

-- Result:
--  product_name |  category   |  price  | pct_of_max
-- --------------+-------------+---------+------------
--  Laptop       | Electronics | 1200.00 |      100.0
--  Smartphone   | Electronics |  800.00 |       66.7
--  Tablet       | Electronics |  450.00 |       37.5
--  Monitor      | Electronics |  300.00 |       25.0
--  Desk Chair   | Furniture   |  249.00 |      100.0
--  Coffee Mug   | Kitchen     |   10.99 |      100.0
-- (6 rows)

-- ------------------------------------------------------------
-- Undo everything this file changed.
-- ------------------------------------------------------------
ROLLBACK;
