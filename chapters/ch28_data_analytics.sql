-- The Most Helpful SQL Guide, Second Edition
-- Chapter 28: Data Analytics
--
-- Every example in this chapter that runs on PostgreSQL,
-- in book order, with the result the book prints. Load
-- sample_db.sql first. To run the whole file in psql:
--   psql -d sqlguide -f chapters/ch28_data_analytics.sql
-- It runs as one transaction and rolls back at the end, so your
-- database is left unchanged. Examples that change data or fail on
-- purpose are wrapped in a savepoint and undone, as in the book.
-- You can also copy any single example into a query window.

BEGIN;

-- ------------------------------------------------------------
-- Example 1: A View of Sales
-- ------------------------------------------------------------
CREATE TEMPORARY VIEW sales AS
SELECT o.order_id,
       o.customer_id,
       o.order_date,
       CAST(DATE_TRUNC('month', o.order_date)
            AS DATE) AS order_month,
       p.category,
       p.product_name,
       oi.quantity * oi.unit_price AS amount
FROM orders o
JOIN order_items oi
    ON oi.order_id = o.order_id
JOIN products p
    ON p.product_id = oi.product_id
WHERE o.status <> 'cancelled';

SELECT order_id, order_month, category,
       product_name, amount
FROM sales
ORDER BY order_id, product_name;

-- Result:
--  order_id | order_month |  category   | product_name | amount
-- ----------+-------------+-------------+--------------+---------
--       101 | 2024-01-01  | Kitchen     | Coffee Mug   |   21.98
--       101 | 2024-01-01  | Electronics | Laptop       | 1200.00
--       102 | 2024-01-01  | Electronics | Smartphone   |  800.00
--       104 | 2024-02-01  | Electronics | Laptop       | 1200.00
--       104 | 2024-02-01  | Electronics | Monitor      |  600.00
--       105 | 2024-02-01  | Kitchen     | Coffee Mug   |   43.96
--       105 | 2024-02-01  | Furniture   | Desk Chair   |  249.00
--       106 | 2024-03-01  | Electronics | Monitor      |  300.00
--       106 | 2024-03-01  | Electronics | Smartphone   |  800.00
-- (9 rows)

-- ------------------------------------------------------------
-- Example 2: Subtotals with ROLLUP
-- ------------------------------------------------------------
SELECT category, product_name,
       SUM(amount) AS sales
FROM sales
GROUP BY ROLLUP (category, product_name)
ORDER BY category, product_name;

-- Result:
--   category   | product_name |  sales
-- -------------+--------------+---------
--  Electronics | Laptop       | 2400.00
--  Electronics | Monitor      |  900.00
--  Electronics | Smartphone   | 1600.00
--  Electronics | NULL         | 4900.00
--  Furniture   | Desk Chair   |  249.00
--  Furniture   | NULL         |  249.00
--  Kitchen     | Coffee Mug   |   65.94
--  Kitchen     | NULL         |   65.94
--  NULL        | NULL         | 5214.94
-- (9 rows)

-- ------------------------------------------------------------
-- Example 3: Telling totals apart with GROUPING
-- ------------------------------------------------------------
SELECT department_id,
       COUNT(*) AS staff,
       SUM(salary) AS payroll,
       GROUPING(department_id) AS is_total
FROM employees
GROUP BY ROLLUP (department_id)
ORDER BY is_total, department_id;

-- Result:
--  department_id | staff |  payroll  | is_total
-- ---------------+-------+-----------+----------
--             10 |     1 | 150000.00 |        0
--             20 |     2 | 155000.00 |        0
--             30 |     3 | 289000.00 |        0
--             40 |     1 |  58000.00 |        0
--           NULL |     1 |  71000.00 |        0
--           NULL |     8 | 723000.00 |        1
-- (6 rows)

-- ------------------------------------------------------------
-- Example 4: GROUPING SETS and CUBE
-- ------------------------------------------------------------
SELECT category, order_month,
       SUM(amount) AS sales
FROM sales
GROUP BY GROUPING SETS (
    (category), (order_month), ()
)
ORDER BY GROUPING(category), category,
         order_month;

-- Result:
--   category   | order_month |  sales
-- -------------+-------------+---------
--  Electronics | NULL        | 4900.00
--  Furniture   | NULL        |  249.00
--  Kitchen     | NULL        |   65.94
--  NULL        | 2024-01-01  | 2021.98
--  NULL        | 2024-02-01  | 2092.96
--  NULL        | 2024-03-01  | 1100.00
--  NULL        | NULL        | 5214.94
-- (7 rows)

-- ------------------------------------------------------------
-- Example 5: Share of Total
-- ------------------------------------------------------------
SELECT category,
       SUM(amount) AS sales,
       ROUND(100 * SUM(amount)
             / SUM(SUM(amount)) OVER (), 2)
           AS pct_of_total
FROM sales
GROUP BY category
ORDER BY sales DESC;

-- Result:
--   category   |  sales  | pct_of_total
-- -------------+---------+--------------
--  Electronics | 4900.00 |        93.96
--  Furniture   |  249.00 |         4.77
--  Kitchen     |   65.94 |         1.26
-- (3 rows)

-- ------------------------------------------------------------
-- Example 6: Filling Gaps with a Calendar
-- ------------------------------------------------------------
CREATE TEMPORARY VIEW monthly_sales AS
SELECT CAST(m.month_start AS DATE) AS month,
       COUNT(DISTINCT s.order_id) AS orders,
       COALESCE(SUM(s.amount), 0.00) AS sales
FROM generate_series(DATE '2024-01-01',
                     DATE '2024-04-01',
                     INTERVAL '1 month')
         m(month_start)
LEFT JOIN sales s
    ON s.order_month = m.month_start
GROUP BY m.month_start;

SELECT month, orders, sales
FROM monthly_sales
ORDER BY month;

-- Result:
--    month    | orders |  sales
-- ------------+--------+---------
--  2024-01-01 |      2 | 2021.98
--  2024-02-01 |      2 | 2092.96
--  2024-03-01 |      1 | 1100.00
--  2024-04-01 |      0 |    0.00
-- (4 rows)

-- ------------------------------------------------------------
-- Example 7: Period-over-Period Change
-- ------------------------------------------------------------
SELECT month,
       sales,
       LAG(sales) OVER w AS prev_sales,
       ROUND(100 * (sales - LAG(sales) OVER w)
             / NULLIF(LAG(sales) OVER w, 0), 1)
           AS pct_change
FROM monthly_sales
WINDOW w AS (ORDER BY month)
ORDER BY month;

-- Result:
--    month    |  sales  | prev_sales | pct_change
-- ------------+---------+------------+------------
--  2024-01-01 | 2021.98 |       NULL |       NULL
--  2024-02-01 | 2092.96 |    2021.98 |        3.5
--  2024-03-01 | 1100.00 |    2092.96 |      -47.4
--  2024-04-01 |    0.00 |    1100.00 |     -100.0
-- (4 rows)

-- ------------------------------------------------------------
-- Example 8: Medians and Percentiles
-- ------------------------------------------------------------
SELECT CAST(PERCENTILE_CONT(0.5) WITHIN GROUP
           (ORDER BY salary) AS DECIMAL(10, 2))
           AS median,
       PERCENTILE_DISC(0.5) WITHIN GROUP
           (ORDER BY salary) AS median_disc,
       CAST(PERCENTILE_CONT(0.9) WITHIN GROUP
           (ORDER BY salary) AS DECIMAL(10, 2))
           AS p90,
       ROUND(AVG(salary), 2) AS average
FROM employees;

-- Result:
--   median  | median_disc |    p90    | average
-- ----------+-------------+-----------+----------
--  90000.00 |    88000.00 | 118500.00 | 90375.00
-- (1 row)

-- ------------------------------------------------------------
-- Example 9: Customer Metrics
-- ------------------------------------------------------------
WITH order_totals AS (
    SELECT order_id, customer_id, order_date,
           SUM(amount) AS total
    FROM sales
    GROUP BY order_id, customer_id, order_date
)
SELECT c.first_name,
       MIN(t.order_date) AS first_order,
       COUNT(t.order_id) AS orders,
       COALESCE(SUM(t.total), 0.00) AS spent,
       ROUND(AVG(t.total), 2) AS avg_order
FROM customers c
LEFT JOIN order_totals t
    ON t.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name
ORDER BY spent DESC, c.customer_id;

-- Result:
--  first_name | first_order | orders |  spent  | avg_order
-- ------------+-------------+--------+---------+-----------
--  Alice      | 2024-01-15  |      2 | 3021.98 |   1510.99
--  Charlie    | 2024-03-05  |      1 | 1100.00 |   1100.00
--  Bob        | 2024-01-16  |      1 |  800.00 |    800.00
--  Dana       | 2024-02-10  |      1 |  292.96 |    292.96
--  Ethan      | NULL        |      0 |    0.00 |      NULL
-- (5 rows)

-- ------------------------------------------------------------
-- Example 10: Basic Statistics
-- ------------------------------------------------------------
SELECT ROUND(STDDEV_SAMP(salary), 2)
           AS sd_sample,
       ROUND(STDDEV_POP(salary), 2)
           AS sd_population,
       CAST(CORR(EXTRACT(YEAR FROM hire_date),
                 salary) AS DECIMAL(4, 3))
           AS year_salary_corr
FROM employees;

-- Result:
--  sd_sample | sd_population | year_salary_corr
-- -----------+---------------+------------------
--   28660.26 |      26809.22 |           -0.722
-- (1 row)

-- ------------------------------------------------------------
-- Example 11: Time-Series Data
-- ------------------------------------------------------------
CREATE TEMPORARY TABLE sensor_readings (
    sensor_id CHAR(1),
    read_at   TIMESTAMP,
    temp_c    DECIMAL(4, 1),
    PRIMARY KEY (sensor_id, read_at)
);

INSERT INTO sensor_readings VALUES
    ('A', '2024-06-01 08:02', 18.0),
    ('A', '2024-06-01 08:09', 18.4),
    ('A', '2024-06-01 08:24', 19.1),
    ('A', '2024-06-01 08:51', 20.3),
    ('A', '2024-06-01 08:58', 20.1),
    ('B', '2024-06-01 08:05', 21.5),
    ('B', '2024-06-01 08:17', 21.9),
    ('B', '2024-06-01 08:19', 22.2),
    ('B', '2024-06-01 08:44', 23.0);

-- Result: INSERT 0 9

-- ------------------------------------------------------------
-- Example 12: Bucketing readings
-- ------------------------------------------------------------
SELECT sensor_id,
       date_bin(INTERVAL '15 minutes', read_at,
                TIMESTAMP '2024-06-01')
           AS bucket,
       COUNT(*) AS readings,
       ROUND(AVG(temp_c), 2) AS avg_temp,
       MAX(temp_c) AS max_temp
FROM sensor_readings
GROUP BY sensor_id, bucket
ORDER BY sensor_id, bucket;

-- Result:
--  sensor_id |       bucket        | readings | avg_temp | max_temp
-- -----------+---------------------+----------+----------+----------
--  A         | 2024-06-01 08:00:00 |        2 |    18.20 |     18.4
--  A         | 2024-06-01 08:15:00 |        1 |    19.10 |     19.1
--  A         | 2024-06-01 08:45:00 |        2 |    20.20 |     20.3
--  B         | 2024-06-01 08:00:00 |        1 |    21.50 |     21.5
--  B         | 2024-06-01 08:15:00 |        2 |    22.05 |     22.2
--  B         | 2024-06-01 08:30:00 |        1 |    23.00 |     23.0
-- (6 rows)

-- ------------------------------------------------------------
-- Example 13: Filling gaps and carrying values forward
-- ------------------------------------------------------------
CREATE TEMPORARY VIEW sensor_buckets AS
SELECT s.sensor_id, b.bucket,
       ROUND(AVG(r.temp_c), 2) AS avg_temp
FROM (VALUES ('A'), ('B')) s (sensor_id)
CROSS JOIN generate_series(
    TIMESTAMP '2024-06-01 08:00',
    TIMESTAMP '2024-06-01 08:45',
    INTERVAL '15 minutes') b(bucket)
LEFT JOIN sensor_readings r
    ON r.sensor_id = s.sensor_id
    AND date_bin(INTERVAL '15 minutes',
                 r.read_at,
                 TIMESTAMP '2024-06-01')
        = b.bucket
GROUP BY s.sensor_id, b.bucket;

SELECT sensor_id, bucket, avg_temp
FROM sensor_buckets
ORDER BY sensor_id, bucket;

-- Result:
--  sensor_id |       bucket        | avg_temp
-- -----------+---------------------+----------
--  A         | 2024-06-01 08:00:00 |    18.20
--  A         | 2024-06-01 08:15:00 |    19.10
--  A         | 2024-06-01 08:30:00 |     NULL
--  A         | 2024-06-01 08:45:00 |    20.20
--  B         | 2024-06-01 08:00:00 |    21.50
--  B         | 2024-06-01 08:15:00 |    22.05
--  B         | 2024-06-01 08:30:00 |    23.00
--  B         | 2024-06-01 08:45:00 |     NULL
-- (8 rows)

-- ------------------------------------------------------------
-- Example 14: Filling gaps and carrying values forward
-- ------------------------------------------------------------
WITH grouped AS (
    SELECT sensor_id, bucket, avg_temp,
           COUNT(avg_temp) OVER (
               PARTITION BY sensor_id
               ORDER BY bucket) AS grp
    FROM sensor_buckets
)
SELECT sensor_id, bucket, avg_temp,
       MAX(avg_temp) OVER (
           PARTITION BY sensor_id, grp)
           AS filled_temp
FROM grouped
ORDER BY sensor_id, bucket;

-- Result:
--  sensor_id |       bucket        | avg_temp | filled_temp
-- -----------+---------------------+----------+-------------
--  A         | 2024-06-01 08:00:00 |    18.20 |       18.20
--  A         | 2024-06-01 08:15:00 |    19.10 |       19.10
--  A         | 2024-06-01 08:30:00 |     NULL |       19.10
--  A         | 2024-06-01 08:45:00 |    20.20 |       20.20
--  B         | 2024-06-01 08:00:00 |    21.50 |       21.50
--  B         | 2024-06-01 08:15:00 |    22.05 |       22.05
--  B         | 2024-06-01 08:30:00 |    23.00 |       23.00
--  B         | 2024-06-01 08:45:00 |     NULL |       23.00
-- (8 rows)

-- ------------------------------------------------------------
-- Example 15: Moving averages and rates of change
-- ------------------------------------------------------------
SELECT read_at,
       temp_c,
       ROUND(AVG(temp_c) OVER (
           ORDER BY read_at ROWS BETWEEN
           2 PRECEDING AND CURRENT ROW), 2)
           AS moving_avg,
       ROUND((temp_c - LAG(temp_c) OVER w)
             / (EXTRACT(EPOCH FROM read_at
                - LAG(read_at) OVER w) / 60), 3)
           AS c_per_min
FROM sensor_readings
WHERE sensor_id = 'A'
WINDOW w AS (ORDER BY read_at)
ORDER BY read_at;

-- Result:
--        read_at       | temp_c | moving_avg | c_per_min
-- ---------------------+--------+------------+-----------
--  2024-06-01 08:02:00 |   18.0 |      18.00 |      NULL
--  2024-06-01 08:09:00 |   18.4 |      18.20 |     0.057
--  2024-06-01 08:24:00 |   19.1 |      18.50 |     0.047
--  2024-06-01 08:51:00 |   20.3 |      19.27 |     0.044
--  2024-06-01 08:58:00 |   20.1 |      19.83 |    -0.029
-- (5 rows)

-- ------------------------------------------------------------
-- Example 16: The latest reading per device
-- ------------------------------------------------------------
SELECT DISTINCT ON (sensor_id)
       sensor_id, read_at, temp_c
FROM sensor_readings
ORDER BY sensor_id, read_at DESC;

-- Result:
--  sensor_id |       read_at       | temp_c
-- -----------+---------------------+--------
--  A         | 2024-06-01 08:58:00 |   20.1
--  B         | 2024-06-01 08:44:00 |   23.0
-- (2 rows)

-- ------------------------------------------------------------
-- Example 17: Storing time series at scale
-- ------------------------------------------------------------
CREATE TEMPORARY TABLE sensor_log AS
SELECT TIMESTAMP '2024-01-01'
           + n * INTERVAL '1 minute' AS read_at,
       (n % 100) / 10.0 AS temp_c
FROM generate_series(0, 287999) g(n);

CREATE INDEX sensor_log_brin
    ON sensor_log USING brin (read_at);

ANALYZE sensor_log;

EXPLAIN (COSTS OFF)
SELECT AVG(temp_c)
FROM sensor_log
WHERE read_at >= TIMESTAMP '2024-03-01'
    AND read_at < TIMESTAMP '2024-03-02';

-- Plan:
--   Aggregate
--     ->  Bitmap Heap Scan on sensor_log
--           Recheck Cond: ((read_at >= '2024-03-01 00:00:00'::timestamp without time zone) AND (read_at < '2024-03-02 00:00:00'::timestamp without time zone))
--           ->  Bitmap Index Scan on sensor_log_brin
--                 Index Cond: ((read_at >= '2024-03-01 00:00:00'::timestamp without time zone) AND (read_at < '2024-03-02 00:00:00'::timestamp without time zone))

-- ------------------------------------------------------------
-- Try It 1
-- Show sales by month and category, with a subtotal for each month
-- and a grand total. Label the total rows.
-- ------------------------------------------------------------
-- 1. Sales by month and category, with totals
SELECT CASE WHEN GROUPING(order_month) = 1
            THEN 'All months'
            ELSE TO_CHAR(order_month, 'Mon YYYY')
       END AS month,
       CASE WHEN GROUPING(category) = 1
            THEN 'All categories'
            ELSE category
       END AS category,
       SUM(amount) AS sales
FROM sales
GROUP BY ROLLUP (order_month, category)
ORDER BY GROUPING(order_month), order_month,
         GROUPING(category), category;

-- Result:
--    month    |    category    |  sales
-- ------------+----------------+---------
--  Jan 2024   | Electronics    | 2000.00
--  Jan 2024   | Kitchen        |   21.98
--  Jan 2024   | All categories | 2021.98
--  Feb 2024   | Electronics    | 1800.00
--  Feb 2024   | Furniture      |  249.00
--  Feb 2024   | Kitchen        |   43.96
--  Feb 2024   | All categories | 2092.96
--  Mar 2024   | Electronics    | 1100.00
--  Mar 2024   | All categories | 1100.00
--  All months | All categories | 5214.94
-- (10 rows)

-- ------------------------------------------------------------
-- Try It 2
-- Find the median order value, not counting the cancelled order, and
-- compare it with the average.
-- ------------------------------------------------------------
-- 2. Median and average order value
WITH order_totals AS (
    SELECT order_id, SUM(amount) AS total
    FROM sales
    GROUP BY order_id
)
SELECT CAST(PERCENTILE_CONT(0.5) WITHIN GROUP
           (ORDER BY total) AS DECIMAL(10, 2))
           AS median_order,
       ROUND(AVG(total), 2) AS avg_order
FROM order_totals;

-- Result:
--  median_order | avg_order
-- --------------+-----------
--       1100.00 |   1042.99
-- (1 row)

-- ------------------------------------------------------------
-- Try It 3
-- Show each product's share of its category's sales, as a percentage
-- with one decimal place.
-- ------------------------------------------------------------
-- 3. Each product's share of its category
SELECT category, product_name,
       SUM(amount) AS sales,
       ROUND(100 * SUM(amount)
             / SUM(SUM(amount)) OVER (
                 PARTITION BY category), 1)
           AS pct_of_category
FROM sales
GROUP BY category, product_name
ORDER BY category, sales DESC;

-- Result:
--   category   | product_name |  sales  | pct_of_category
-- -------------+--------------+---------+-----------------
--  Electronics | Laptop       | 2400.00 |            49.0
--  Electronics | Smartphone   | 1600.00 |            32.7
--  Electronics | Monitor      |  900.00 |            18.4
--  Furniture   | Desk Chair   |  249.00 |           100.0
--  Kitchen     | Coffee Mug   |   65.94 |           100.0
-- (5 rows)

-- ------------------------------------------------------------
-- Undo everything this file changed.
-- ------------------------------------------------------------
ROLLBACK;
