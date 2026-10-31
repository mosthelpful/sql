-- The Most Helpful SQL Guide, Second Edition
-- Appendix E: SQL Interview Practice
--
-- The answer to every question, with the result the book prints.
-- Load sample_db.sql first. To run the whole file in psql:
--   psql -d sqlguide -f appendix_e/interview.sql
-- It runs as one transaction and rolls back at the end, so your
-- database is left unchanged. Examples that change data or fail on
-- purpose are wrapped in a savepoint and undone, as in the book.
-- You can also copy any single example into a query window.

BEGIN;

-- ------------------------------------------------------------
-- Question 1
-- In what order does the database process a query's clauses? Write a
-- query that uses WHERE, GROUP BY, HAVING, ORDER BY and LIMIT,
-- number its clauses in that order and explain why ORDER BY can use
-- a column alias but WHERE and HAVING can't. (Chapter 10)
-- ------------------------------------------------------------
-- 1. Clauses in processing order
SELECT department_id,               -- 5
       SUM(salary) AS payroll
FROM employees                      -- 1
WHERE hire_date < DATE '2020-01-01' -- 2
GROUP BY department_id              -- 3
HAVING COUNT(*) > 1                 -- 4
ORDER BY payroll DESC               -- 6
LIMIT 1;                            -- 7

-- Result:
--  department_id |  payroll
-- ---------------+-----------
--             30 | 197000.00
-- (1 row)

-- ------------------------------------------------------------
-- Question 2
-- How many different last names do the employees and customers have
-- between them? Compare UNION with UNION ALL. (Chapter 11)
-- ------------------------------------------------------------
-- 2. UNION versus UNION ALL
SELECT (SELECT COUNT(*)
        FROM (SELECT last_name FROM employees
              UNION
              SELECT last_name FROM customers) u)
           AS union_rows,
       (SELECT COUNT(*)
        FROM (SELECT last_name FROM employees
              UNION ALL
              SELECT last_name FROM customers) a)
           AS union_all_rows;

-- Result:
--  union_rows | union_all_rows
-- ------------+----------------
--          12 |             13
-- (1 row)

-- ------------------------------------------------------------
-- Question 3
-- Find the second-highest salary. (Chapter 13)
-- ------------------------------------------------------------
-- 3. The second-highest salary
SELECT MAX(salary) AS second_highest
FROM employees
WHERE salary < (SELECT MAX(salary)
                FROM employees);

-- Result:
--  second_highest
-- ----------------
--       105000.00
-- (1 row)

-- ------------------------------------------------------------
-- Question 4
-- List the products priced above the average of their own category,
-- using a correlated subquery. (Chapter 13)
-- ------------------------------------------------------------
-- 4. Products above their category's average
SELECT p.product_name, p.category, p.price
FROM products p
WHERE p.price > (
    SELECT AVG(p2.price)
    FROM products p2
    WHERE p2.category = p.category
)
ORDER BY p.price DESC;

-- Result:
--  product_name |  category   |  price
-- --------------+-------------+---------
--  Laptop       | Electronics | 1200.00
--  Smartphone   | Electronics |  800.00
-- (2 rows)

-- ------------------------------------------------------------
-- Question 5
-- How many rows do an INNER JOIN, a LEFT JOIN and a FULL OUTER JOIN
-- of employees and departments return, and why? (Chapter 11)
-- ------------------------------------------------------------
-- 5. Row counts for each kind of join
SELECT (SELECT COUNT(*)
        FROM employees e
        JOIN departments d
            ON d.department_id = e.department_id)
           AS inner_join,
       (SELECT COUNT(*)
        FROM employees e
        LEFT JOIN departments d
            ON d.department_id = e.department_id)
           AS emp_left_join,
       (SELECT COUNT(*)
        FROM departments d
        LEFT JOIN employees e
            ON e.department_id = d.department_id)
           AS dept_left_join,
       (SELECT COUNT(*)
        FROM employees e
        FULL JOIN departments d
            ON d.department_id = e.department_id)
           AS full_join;

-- Result:
--  inner_join | emp_left_join | dept_left_join | full_join
-- ------------+---------------+----------------+-----------
--           7 |             8 |              8 |         9
-- (1 row)

-- ------------------------------------------------------------
-- Question 6
-- List each employee with their manager and their manager's manager.
-- (Chapter 11)
-- ------------------------------------------------------------
-- 6. Employee, manager and manager's manager
SELECT e.first_name AS employee,
       m.first_name AS manager,
       mm.first_name AS managers_manager
FROM employees e
LEFT JOIN employees m
    ON m.employee_id = e.manager_id
LEFT JOIN employees mm
    ON mm.employee_id = m.manager_id
ORDER BY e.employee_id;

-- Result:
--  employee | manager | managers_manager
-- ----------+---------+------------------
--  John     | NULL    | NULL
--  Jane     | John    | NULL
--  Emily    | John    | NULL
--  Michael  | Emily   | John
--  Sarah    | Emily   | John
--  David    | Jane    | John
--  Priya    | John    | NULL
--  Tom      | Emily   | John
-- (8 rows)

-- ------------------------------------------------------------
-- Question 7
-- Using a self join, list every pair of employees who work in the
-- same department, each pair once. (Chapter 11)
-- ------------------------------------------------------------
-- 7. Pairs of employees in the same department
SELECT d.department_name,
       a.first_name AS employee_1,
       b.first_name AS employee_2
FROM employees a
JOIN employees b
    ON b.department_id = a.department_id
    AND b.employee_id > a.employee_id
JOIN departments d
    ON d.department_id = a.department_id
ORDER BY d.department_name, a.employee_id,
         b.employee_id;

-- Result:
--  department_name | employee_1 | employee_2
-- -----------------+------------+------------
--  Engineering     | Emily      | Michael
--  Engineering     | Emily      | Sarah
--  Engineering     | Michael    | Sarah
--  Finance         | Jane       | David
-- (4 rows)

-- ------------------------------------------------------------
-- Question 8
-- List every customer with their number of shipped orders, including
-- customers with none. (Chapters 11 and 12)
-- ------------------------------------------------------------
-- 8. Shipped orders per customer, zeros kept
SELECT c.first_name,
       COUNT(o.order_id) AS shipped_orders
FROM customers c
LEFT JOIN orders o
    ON o.customer_id = c.customer_id
    AND o.status = 'shipped'
GROUP BY c.customer_id, c.first_name
ORDER BY c.customer_id;

-- Result:
--  first_name | shipped_orders
-- ------------+----------------
--  Alice      |              2
--  Bob        |              1
--  Charlie    |              1
--  Dana       |              0
--  Ethan      |              0
-- (5 rows)

-- ------------------------------------------------------------
-- Question 9
-- Find the departments with no employees. Why does WHERE
-- department_id NOT IN (SELECT department_id FROM employees) find
-- none? (Chapters 11 and 13)
-- ------------------------------------------------------------
-- 9. Departments with no employees
SELECT d.department_id, d.department_name
FROM departments d
LEFT JOIN employees e
    ON e.department_id = d.department_id
WHERE e.employee_id IS NULL
ORDER BY d.department_id;

-- Result:
--  department_id | department_name
-- ---------------+-----------------
--             50 | Legal
-- (1 row)

-- ------------------------------------------------------------
-- Question 10
-- Why does WHERE manager_id = NULL find nobody, not even John? Show
-- what =, IS NULL and NOT IN return when NULL is involved. (Chapter
-- 15)
-- ------------------------------------------------------------
-- 10. Comparisons with NULL
SELECT NULL = NULL AS equals_null,
       NULL IS NULL AS is_null,
       3 NOT IN (1, 2) AS not_in,
       3 NOT IN (1, 2, NULL) AS not_in_with_null;

-- Result:
--  equals_null | is_null | not_in | not_in_with_null
-- -------------+---------+--------+------------------
--  NULL        | true    | true   | NULL
-- (1 row)

-- ------------------------------------------------------------
-- Question 11
-- On a LEFT JOIN of customers to orders, compare COUNT(*),
-- COUNT(column) and COUNT(DISTINCT column). (Chapters 11 and 12)
-- ------------------------------------------------------------
-- 11. The forms of COUNT
SELECT COUNT(*) AS all_rows,
       COUNT(o.order_id) AS orders,
       COUNT(DISTINCT o.customer_id)
           AS customers_ordering,
       COUNT(c.city) AS rows_with_city,
       COUNT(DISTINCT c.city) AS cities
FROM customers c
LEFT JOIN orders o
    ON o.customer_id = c.customer_id;

-- Result:
--  all_rows | orders | customers_ordering | rows_with_city | cities
-- ----------+--------+--------------------+----------------+--------
--         7 |      6 |                  4 |              6 |      3
-- (1 row)

-- ------------------------------------------------------------
-- Question 12
-- For each department, count the employees who earn more than
-- 80,000, and keep only the departments with at least two of them.
-- Which condition goes in WHERE, and which in HAVING? (Chapter 12)
-- ------------------------------------------------------------
-- 12. WHERE before grouping, HAVING after
SELECT d.department_name,
       COUNT(*) AS high_earners
FROM employees e
JOIN departments d
    ON d.department_id = e.department_id
WHERE e.salary > 80000
GROUP BY d.department_id, d.department_name
HAVING COUNT(*) >= 2
ORDER BY d.department_name;

-- Result:
--  department_name | high_earners
-- -----------------+--------------
--  Engineering     |            3
-- (1 row)

-- ------------------------------------------------------------
-- Question 13
-- List every customer who shares a city with another customer: the
-- full rows, not just the city. (Chapters 12 and 17)
-- ------------------------------------------------------------
-- 13. Customers who share a city
SELECT first_name, last_name, city
FROM (
    SELECT customer_id, first_name, last_name,
           city,
           COUNT(*) OVER (PARTITION BY city)
               AS same_city
    FROM customers
) c
WHERE same_city > 1
ORDER BY city, customer_id;

-- Result:
--  first_name | last_name |   city
-- ------------+-----------+----------
--  Alice      | Brown     | New York
--  Charlie    | Evans     | New York
-- (2 rows)

-- ------------------------------------------------------------
-- Question 14
-- Show the number of orders for each status, with one column for
-- each month from January to March 2024 and a total. (Chapter 20)
-- ------------------------------------------------------------
-- 14. Orders per status and month
WITH monthly AS (
    SELECT status,
           EXTRACT(MONTH FROM order_date)
               AS month_no
    FROM orders
)
SELECT status,
       COUNT(CASE WHEN month_no = 1
                  THEN 1 END) AS jan,
       COUNT(CASE WHEN month_no = 2
                  THEN 1 END) AS feb,
       COUNT(CASE WHEN month_no = 3
                  THEN 1 END) AS mar,
       COUNT(*) AS total
FROM monthly
GROUP BY status
ORDER BY status;

-- Result:
--    status   | jan | feb | mar | total
-- ------------+-----+-----+-----+-------
--  cancelled  |   1 |   0 |   0 |     1
--  processing |   0 |   1 |   0 |     1
--  shipped    |   2 |   1 |   1 |     4
-- (3 rows)

-- ------------------------------------------------------------
-- Question 15
-- Rank the customers by their number of orders with ROW_NUMBER, RANK
-- and DENSE_RANK, and explain the difference. (Chapter 17)
-- ------------------------------------------------------------
-- 15. Three ways to number rows
WITH order_counts AS (
    SELECT c.customer_id, c.first_name,
           COUNT(o.order_id) AS order_count
    FROM customers c
    LEFT JOIN orders o
        ON o.customer_id = c.customer_id
    GROUP BY c.customer_id, c.first_name
)
SELECT first_name, order_count,
       ROW_NUMBER() OVER (
           ORDER BY order_count DESC, customer_id
       ) AS row_num,
       RANK() OVER (
           ORDER BY order_count DESC
       ) AS count_rank,
       DENSE_RANK() OVER (
           ORDER BY order_count DESC
       ) AS dense_count_rank
FROM order_counts
ORDER BY order_count DESC, customer_id;

-- Result:
--  first_name | order_count | row_num | count_rank | dense_count_rank
-- ------------+-------------+---------+------------+------------------
--  Alice      |           2 |       1 |          1 |                1
--  Charlie    |           2 |       2 |          1 |                1
--  Bob        |           1 |       3 |          3 |                2
--  Dana       |           1 |       4 |          3 |                2
--  Ethan      |           0 |       5 |          5 |                3
-- (5 rows)

-- ------------------------------------------------------------
-- Question 16
-- Find the fourth-highest salary. Why do DENSE_RANK and LIMIT 1
-- OFFSET 3 give different answers? (Chapters 10 and 17)
-- ------------------------------------------------------------
-- 16. The fourth-highest salary, three ways
WITH ranked AS (
    SELECT salary,
           DENSE_RANK() OVER (
               ORDER BY salary DESC
           ) AS salary_rank
    FROM employees
)
SELECT (SELECT DISTINCT salary
        FROM ranked
        WHERE salary_rank = 4) AS by_dense_rank,
       (SELECT salary
        FROM employees
        ORDER BY salary DESC
        LIMIT 1 OFFSET 3) AS by_offset,
       (SELECT DISTINCT salary
        FROM employees
        ORDER BY salary DESC
        LIMIT 1 OFFSET 3) AS by_distinct_offset;

-- Result:
--  by_dense_rank | by_offset | by_distinct_offset
-- ---------------+-----------+--------------------
--       88000.00 |  92000.00 |           88000.00
-- (1 row)

-- ------------------------------------------------------------
-- Question 17
-- Find the second-highest salary in each department, and who earns
-- it. Why do some departments have no row? (Chapters 17 and 18)
-- ------------------------------------------------------------
-- 17. Second-highest salary per department
WITH ranked AS (
    SELECT d.department_name, e.first_name,
           e.salary,
           DENSE_RANK() OVER (
               PARTITION BY e.department_id
               ORDER BY e.salary DESC
           ) AS salary_rank
    FROM employees e
    JOIN departments d
        ON d.department_id = e.department_id
)
SELECT department_name, first_name, salary
FROM ranked
WHERE salary_rank = 2
ORDER BY department_name, first_name;

-- Result:
--  department_name | first_name |  salary
-- -----------------+------------+----------
--  Engineering     | Michael    | 92000.00
--  Engineering     | Sarah      | 92000.00
--  Finance         | David      | 67000.00
-- (3 rows)

-- ------------------------------------------------------------
-- Question 18
-- Show the company's payroll growing with each hire: every
-- employee's hire date, salary and the running total of salaries.
-- (Chapter 17)
-- ------------------------------------------------------------
-- 18. Running payroll by hire date
SELECT first_name, hire_date, salary,
       SUM(salary) OVER (
           ORDER BY hire_date, employee_id
           ROWS BETWEEN UNBOUNDED PRECEDING
                    AND CURRENT ROW
       ) AS running_payroll
FROM employees
ORDER BY hire_date, employee_id;

-- Result:
--  first_name | hire_date  |  salary   | running_payroll
-- ------------+------------+-----------+-----------------
--  John       | 2015-06-15 | 150000.00 |       150000.00
--  Jane       | 2016-09-23 |  88000.00 |       238000.00
--  Emily      | 2017-03-11 | 105000.00 |       343000.00
--  Michael    | 2018-05-29 |  92000.00 |       435000.00
--  David      | 2019-11-12 |  67000.00 |       502000.00
--  Sarah      | 2020-02-03 |  92000.00 |       594000.00
--  Priya      | 2021-08-30 |  58000.00 |       652000.00
--  Tom        | 2024-01-08 |  71000.00 |       723000.00
-- (8 rows)

-- ------------------------------------------------------------
-- Question 19
-- Show the units sold each month, not counting cancelled orders,
-- with the change from the month before, in units and as a
-- percentage. (Chapters 14 and 17)
-- ------------------------------------------------------------
-- 19. Units sold, month over month
WITH monthly AS (
    SELECT CAST(DATE_TRUNC('month', o.order_date)
                AS DATE) AS month,
           SUM(oi.quantity) AS units
    FROM orders o
    JOIN order_items oi
        ON oi.order_id = o.order_id
    WHERE o.status <> 'cancelled'
    GROUP BY DATE_TRUNC('month', o.order_date)
)
SELECT month, units,
       units - LAG(units) OVER w AS change,
       ROUND(100.0 * (units - LAG(units) OVER w)
             / NULLIF(LAG(units) OVER w, 0), 1)
           AS pct_change
FROM monthly
WINDOW w AS (ORDER BY month)
ORDER BY month;

-- Result:
--    month    | units | change | pct_change
-- ------------+-------+--------+------------
--  2024-01-01 |     4 |   NULL |       NULL
--  2024-02-01 |     8 |      4 |      100.0
--  2024-03-01 |     2 |     -6 |      -75.0
-- (3 rows)

-- ------------------------------------------------------------
-- Question 20
-- Find the runs of consecutive years in which the company hired
-- someone, and the gap between them. (Chapter 17 and Appendix C)
-- ------------------------------------------------------------
-- 20. Runs of consecutive hiring years
WITH hire_years AS (
    SELECT DISTINCT
           CAST(EXTRACT(YEAR FROM hire_date)
                AS INT) AS hire_year
    FROM employees
),
grouped AS (
    SELECT hire_year,
           hire_year - ROW_NUMBER() OVER (
               ORDER BY hire_year) AS grp
    FROM hire_years
)
SELECT MIN(hire_year) AS first_year,
       MAX(hire_year) AS last_year,
       COUNT(*) AS years
FROM grouped
GROUP BY grp
ORDER BY first_year;

-- Result:
--  first_year | last_year | years
-- ------------+-----------+-------
--        2015 |      2021 |     7
--        2024 |      2024 |     1
-- (2 rows)

-- ------------------------------------------------------------
-- Question 21
-- Using a CTE, list the customers whose spending, not counting
-- cancelled orders, is above the average customer's. (Chapter 18)
-- ------------------------------------------------------------
-- 21. Customers who spend more than average
WITH customer_spend AS (
    SELECT o.customer_id,
           SUM(oi.quantity * oi.unit_price)
               AS spend
    FROM orders o
    JOIN order_items oi
        ON oi.order_id = o.order_id
    WHERE o.status <> 'cancelled'
    GROUP BY o.customer_id
)
SELECT c.first_name, cs.spend
FROM customer_spend cs
JOIN customers c
    ON c.customer_id = cs.customer_id
WHERE cs.spend > (SELECT AVG(spend)
                  FROM customer_spend)
ORDER BY cs.spend DESC;

-- Result:
--  first_name |  spend
-- ------------+---------
--  Alice      | 3021.98
-- (1 row)

-- ------------------------------------------------------------
-- Question 22
-- For each manager, count everyone who reports to them, directly or
-- indirectly. (Chapter 18)
-- ------------------------------------------------------------
-- 22. Direct and indirect reports per manager
WITH RECURSIVE reports AS (
    SELECT manager_id, employee_id
    FROM employees
    WHERE manager_id IS NOT NULL

    UNION ALL

    SELECT r.manager_id, e.employee_id
    FROM reports r
    JOIN employees e
        ON e.manager_id = r.employee_id
)
SELECT m.first_name AS manager,
       COUNT(*) AS total_reports
FROM reports r
JOIN employees m
    ON m.employee_id = r.manager_id
GROUP BY m.employee_id, m.first_name
ORDER BY total_reports DESC, m.employee_id;

-- Result:
--  manager | total_reports
-- ---------+---------------
--  John    |             7
--  Emily   |             3
--  Jane    |             1
-- (3 rows)

-- ------------------------------------------------------------
-- Question 23
-- What is the difference between DELETE and TRUNCATE? Delete the
-- cancelled order 103, and empty the projects table. (Chapter 10)
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 23. DELETE some rows, TRUNCATE a table
DELETE FROM order_items
WHERE order_id = 103;

DELETE FROM orders
WHERE order_id = 103;

TRUNCATE TABLE projects;

SELECT (SELECT COUNT(*) FROM orders)
           AS orders_left,
       (SELECT COUNT(*) FROM order_items)
           AS lines_left,
       (SELECT COUNT(*) FROM projects)
           AS projects_left;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  orders_left | lines_left | projects_left
-- -------------+------------+---------------
--            5 |          9 |             0
-- (1 row)

-- ------------------------------------------------------------
-- Question 24
-- A bug marked every shipped order processing, and every processing
-- order shipped. Swap the two values with one UPDATE. (Chapters 10
-- and 20)
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 24. Swap two status values in one UPDATE
UPDATE orders
SET status = CASE status
                 WHEN 'shipped' THEN 'processing'
                 ELSE 'shipped'
             END
WHERE status IN ('shipped', 'processing');

SELECT order_id, status
FROM orders
ORDER BY order_id;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  order_id |   status
-- ----------+------------
--       101 | processing
--       102 | processing
--       103 | cancelled
--       104 | processing
--       105 | shipped
--       106 | processing
-- (6 rows)

-- ------------------------------------------------------------
-- Question 25
-- What does ACID stand for? Show atomicity with one INSERT that adds
-- three order lines, one of them invalid. (Chapters 25 and 34)
-- Fails on purpose, to show the error.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 25. Atomicity: all three lines or none
INSERT INTO order_items
    (order_id, product_id, quantity, unit_price)
VALUES
    (106, 1, 1, 1200.00),
    (106, 3, 1, 450.00),
    (106, 5, 0, 10.99);

ROLLBACK TO SAVEPOINT example;

-- Expected error:
--   ERROR:  new row for relation "order_items" violates check constraint "order_items_quantity_check"
--   DETAIL:  Failing row contains (106, 5, 0, 10.99).

-- ------------------------------------------------------------
-- Question 26
-- Two clerks each sell 5 Desk Chairs at the same moment, and there
-- are 8 in stock. If each reads the stock and then writes back the
-- stock minus 5, what goes wrong? Write the sale so that it can't.
-- (Chapters 25 and 34)
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 26. A sale that can't oversell
UPDATE products
SET stock = stock - 5
WHERE product_id = 6
    AND stock >= 5
RETURNING product_name, stock;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  product_name | stock
-- --------------+-------
--  Desk Chair   |     3
-- (1 row)

-- ------------------------------------------------------------
-- Question 27
-- What is the difference between a primary key and a UNIQUE
-- constraint? Show how each treats NULL. (Chapters 7 and 15)
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 27. A primary key and a UNIQUE column
DROP TABLE IF EXISTS interview_badges;

CREATE TEMPORARY TABLE interview_badges (
    badge_id    INT PRIMARY KEY,
    employee_id INT UNIQUE
);

INSERT INTO interview_badges
    (badge_id, employee_id)
VALUES
    (1, 4),
    (2, NULL),
    (3, NULL);

SELECT badge_id, employee_id
FROM interview_badges
ORDER BY badge_id;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  badge_id | employee_id
-- ----------+-------------
--         1 |           4
--         2 |        NULL
--         3 |        NULL
-- (3 rows)

-- ------------------------------------------------------------
-- Question 28
-- On a table of 20,000 logins with an index on logged_at, does WHERE
-- CAST(logged_at AS DATE) = DATE '2024-03-05' use the index? Read
-- the plan, explain it and rewrite the condition. (Chapter 19)
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 28. A cast on an indexed column
DROP TABLE IF EXISTS interview_logins;

CREATE TABLE interview_logins (
    login_id  INT PRIMARY KEY,
    logged_at TIMESTAMP NOT NULL
);

INSERT INTO interview_logins
    (login_id, logged_at)
SELECT n,
       TIMESTAMP '2024-01-01 00:00'
           + n * INTERVAL '10 minutes'
FROM generate_series(1, 20000) n;

CREATE INDEX idx_interview_logins_at
    ON interview_logins (logged_at);

ANALYZE interview_logins;

EXPLAIN (COSTS OFF)
SELECT COUNT(*)
FROM interview_logins
WHERE CAST(logged_at AS DATE)
      = DATE '2024-03-05';

ROLLBACK TO SAVEPOINT example;

-- Plan:
--   Aggregate
--     ->  Seq Scan on interview_logins
--           Filter: ((logged_at)::date = '2024-03-05'::date)

-- ------------------------------------------------------------
-- Question 29
-- What is normalization for? Copy the employees and their department
-- names into one table, and show what goes wrong when a department
-- is renamed on only one row. (Chapter 33)
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 29. An update anomaly in a copied table
DROP TABLE IF EXISTS interview_staff_sheet;

CREATE TEMPORARY TABLE interview_staff_sheet AS
SELECT e.employee_id, e.first_name,
       d.department_id, d.department_name
FROM employees e
JOIN departments d
    ON d.department_id = e.department_id;

UPDATE interview_staff_sheet
SET department_name = 'Product Engineering'
WHERE employee_id = 3;

SELECT department_id, department_name,
       COUNT(*) AS staff
FROM interview_staff_sheet
GROUP BY department_id, department_name
ORDER BY department_id, department_name;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  department_id |   department_name   | staff
-- ---------------+---------------------+-------
--             10 | Executive           |     1
--             20 | Finance             |     2
--             30 | Engineering         |     2
--             30 | Product Engineering |     1
--             40 | Sales               |     1
-- (5 rows)

-- ------------------------------------------------------------
-- Example 1: Answers
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

DROP TABLE IF EXISTS interview_logins;

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Undo everything this file changed.
-- ------------------------------------------------------------
ROLLBACK;
