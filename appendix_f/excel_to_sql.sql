-- The Most Helpful SQL Guide, Second Edition
-- Appendix F: From Excel to SQL
--
-- Every example in this appendix that runs on PostgreSQL,
-- in book order, with the result the book prints. Load
-- sample_db.sql first. To run the whole file in psql:
--   psql -d sqlguide -f appendix_f/excel_to_sql.sql
-- It runs as one transaction and rolls back at the end, so your
-- database is left unchanged. Examples that change data or fail on
-- purpose are wrapped in a savepoint and undone, as in the book.
-- You can also copy any single example into a query window.

BEGIN;

-- ------------------------------------------------------------
-- Example 1: VLOOKUP and XLOOKUP: a department name
-- ------------------------------------------------------------
SELECT e.first_name, e.department_id,
       d.department_name
FROM employees e
LEFT JOIN departments d
    ON d.department_id = e.department_id
ORDER BY e.employee_id;

-- Result:
--  first_name | department_id | department_name
-- ------------+---------------+-----------------
--  John       |            10 | Executive
--  Jane       |            20 | Finance
--  Emily      |            30 | Engineering
--  Michael    |            30 | Engineering
--  Sarah      |            30 | Engineering
--  David      |            20 | Finance
--  Priya      |            40 | Sales
--  Tom        |          NULL | NULL
-- (8 rows)

-- ------------------------------------------------------------
-- Example 2: VLOOKUP and XLOOKUP: a department name
-- ------------------------------------------------------------
SELECT e.first_name,
       COALESCE(d.department_name,
                'No department') AS department
FROM employees e
LEFT JOIN departments d
    ON d.department_id = e.department_id
WHERE e.employee_id IN (7, 8)
ORDER BY e.employee_id;

-- Result:
--  first_name |  department
-- ------------+---------------
--  Priya      | Sales
--  Tom        | No department
-- (2 rows)

-- ------------------------------------------------------------
-- Example 3: SUMIFS: revenue for one category
-- ------------------------------------------------------------
SELECT SUM(oi.quantity * oi.unit_price)
           AS electronics_revenue
FROM order_items oi
JOIN orders o
    ON o.order_id = oi.order_id
JOIN products p
    ON p.product_id = oi.product_id
WHERE p.category = 'Electronics'
    AND o.status <> 'cancelled';

-- Result:
--  electronics_revenue
-- ---------------------
--              4900.00
-- (1 row)

-- ------------------------------------------------------------
-- Example 4: SUMIFS: revenue for one category
-- ------------------------------------------------------------
SELECT p.category,
       SUM(oi.quantity * oi.unit_price)
           AS revenue,
       SUM(oi.quantity * oi.unit_price)
           FILTER (WHERE o.status = 'shipped')
           AS shipped
FROM order_items oi
JOIN orders o
    ON o.order_id = oi.order_id
JOIN products p
    ON p.product_id = oi.product_id
WHERE o.status <> 'cancelled'
GROUP BY p.category
ORDER BY p.category;

-- Result:
--   category   | revenue | shipped
-- -------------+---------+---------
--  Electronics | 4900.00 | 4900.00
--  Furniture   |  249.00 |    NULL
--  Kitchen     |   65.94 |   21.98
-- (3 rows)

-- ------------------------------------------------------------
-- Example 5: COUNTIF: customers per city
-- ------------------------------------------------------------
SELECT city, COUNT(*) AS customers
FROM customers
GROUP BY city
ORDER BY city;

-- Result:
--    city   | customers
-- ----------+-----------
--  Austin   |         1
--  Chicago  |         1
--  New York |         2
--  NULL     |         1
-- (4 rows)

-- ------------------------------------------------------------
-- Example 6: Pivot table: sales by category and month
-- ------------------------------------------------------------
SELECT p.category,
       SUM(oi.quantity * oi.unit_price)
           FILTER (WHERE o.order_date
                   < DATE '2024-02-01')
           AS jan,
       SUM(oi.quantity * oi.unit_price)
           FILTER (WHERE o.order_date
                   >= DATE '2024-02-01'
               AND o.order_date
                   < DATE '2024-03-01')
           AS feb,
       SUM(oi.quantity * oi.unit_price)
           FILTER (WHERE o.order_date
                   >= DATE '2024-03-01')
           AS mar,
       SUM(oi.quantity * oi.unit_price)
           AS total
FROM order_items oi
JOIN orders o
    ON o.order_id = oi.order_id
JOIN products p
    ON p.product_id = oi.product_id
WHERE o.status <> 'cancelled'
GROUP BY ROLLUP (p.category)
ORDER BY p.category;

-- Result:
--   category   |   jan   |   feb   |   mar   |  total
-- -------------+---------+---------+---------+---------
--  Electronics | 2000.00 | 1800.00 | 1100.00 | 4900.00
--  Furniture   |    NULL |  249.00 |    NULL |  249.00
--  Kitchen     |   21.98 |   43.96 |    NULL |   65.94
--  NULL        | 2021.98 | 2092.96 | 1100.00 | 5214.94
-- (4 rows)

-- ------------------------------------------------------------
-- Example 7: IF and IFS: salary bands
-- ------------------------------------------------------------
SELECT first_name, salary,
       CASE
           WHEN salary >= 100000 THEN 'High'
           WHEN salary >= 80000 THEN 'Middle'
           ELSE 'Standard'
       END AS band
FROM employees
ORDER BY salary DESC, employee_id;

-- Result:
--  first_name |  salary   |   band
-- ------------+-----------+----------
--  John       | 150000.00 | High
--  Emily      | 105000.00 | High
--  Michael    |  92000.00 | Middle
--  Sarah      |  92000.00 | Middle
--  Jane       |  88000.00 | Middle
--  Tom        |  71000.00 | Standard
--  David      |  67000.00 | Standard
--  Priya      |  58000.00 | Standard
-- (8 rows)

-- ------------------------------------------------------------
-- Example 8: Running total
-- ------------------------------------------------------------
SELECT order_id, order_date,
       SUM(quantity * unit_price) AS total,
       SUM(SUM(quantity * unit_price)) OVER (
           ORDER BY order_date, order_id
           ROWS BETWEEN UNBOUNDED PRECEDING
                    AND CURRENT ROW
       ) AS running_total
FROM orders
JOIN order_items
    USING (order_id)
WHERE status <> 'cancelled'
GROUP BY order_id, order_date
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
-- Example 9: RANK: salary ranking
-- ------------------------------------------------------------
SELECT first_name, salary,
       RANK() OVER (
           ORDER BY salary DESC
       ) AS salary_rank
FROM employees
ORDER BY salary_rank, employee_id;

-- Result:
--  first_name |  salary   | salary_rank
-- ------------+-----------+-------------
--  John       | 150000.00 |           1
--  Emily      | 105000.00 |           2
--  Michael    |  92000.00 |           3
--  Sarah      |  92000.00 |           3
--  Jane       |  88000.00 |           5
--  Tom        |  71000.00 |           6
--  David      |  67000.00 |           7
--  Priya      |  58000.00 |           8
-- (8 rows)

-- ------------------------------------------------------------
-- Example 10: Remove Duplicates and flagging them
-- ------------------------------------------------------------
SELECT DISTINCT city
FROM customers
ORDER BY city;

-- Result:
--    city
-- ----------
--  Austin
--  Chicago
--  New York
--  NULL
-- (4 rows)

-- ------------------------------------------------------------
-- Example 11: Remove Duplicates and flagging them
-- ------------------------------------------------------------
SELECT city, COUNT(*) AS customers
FROM customers
GROUP BY city
HAVING COUNT(*) > 1
ORDER BY city;

-- Result:
--    city   | customers
-- ----------+-----------
--  New York |         2
-- (1 row)

-- ------------------------------------------------------------
-- Example 12: Remove Duplicates and flagging them
-- ------------------------------------------------------------
SELECT first_name, city,
       COUNT(*) OVER (PARTITION BY city) > 1
           AS duplicate_city
FROM customers
ORDER BY customer_id;

-- Result:
--  first_name |   city   | duplicate_city
-- ------------+----------+----------------
--  Alice      | New York | true
--  Bob        | Chicago  | false
--  Charlie    | New York | true
--  Dana       | Austin   | false
--  Ethan      | NULL     | false
-- (5 rows)

-- ------------------------------------------------------------
-- Example 13: TRIM and clean-up
-- ------------------------------------------------------------
SELECT raw,
       INITCAP(TRIM(raw)) AS cleaned,
       NULLIF(TRIM(raw), '') AS no_blanks
FROM (VALUES (1, '  new york'),
             (2, 'NEW YORK '),
             (3, '   ')) v (id, raw)
ORDER BY id;

-- Result:
--     raw     | cleaned  | no_blanks
-- ------------+----------+-----------
--    new york | New York | new york
--  NEW YORK   | New York | NEW YORK
--             |          | NULL
-- (3 rows)

-- ------------------------------------------------------------
-- Example 14: IFERROR: dividing by zero
-- ------------------------------------------------------------
SELECT c.first_name,
       COUNT(o.order_id) AS orders,
       ROUND(COUNT(o.order_id)
                 FILTER (WHERE o.status
                         = 'shipped')
             * 100.0
             / NULLIF(COUNT(o.order_id), 0), 1)
           AS pct_shipped
FROM customers c
LEFT JOIN orders o
    ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name
ORDER BY c.customer_id;

-- Result:
--  first_name | orders | pct_shipped
-- ------------+--------+-------------
--  Alice      |      2 |       100.0
--  Bob        |      1 |       100.0
--  Charlie    |      2 |        50.0
--  Dana       |      1 |         0.0
--  Ethan      |      0 |        NULL
-- (5 rows)

-- ------------------------------------------------------------
-- Example 15: Editor steps and their SQL
-- ------------------------------------------------------------
SELECT p.product_name,
       v.attribute,
       v.value
FROM products p
CROSS JOIN LATERAL (
    VALUES ('price', p.price),
           ('stock', p.stock)
) v (attribute, value)
WHERE p.category = 'Kitchen'
ORDER BY p.product_name, v.attribute;

-- Result:
--  product_name | attribute | value
-- --------------+-----------+-------
--  Coffee Mug   | price     | 10.99
--  Coffee Mug   | stock     |   100
-- (2 rows)

-- ------------------------------------------------------------
-- Undo everything this file changed.
-- ------------------------------------------------------------
ROLLBACK;
