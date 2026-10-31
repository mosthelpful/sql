-- The Most Helpful SQL Guide, Second Edition
-- Practical Exercises: Basic
--
-- The answer to every question, with the result the book prints.
-- Load sample_db.sql first. To run the whole file in psql:
--   psql -d sqlguide -f exercises/basic.sql
-- It runs as one transaction and rolls back at the end, so your
-- database is left unchanged. Examples that change data or fail on
-- purpose are wrapped in a savepoint and undone, as in the book.
-- You can also copy any single example into a query window.

BEGIN;

-- ------------------------------------------------------------
-- Exercise 1
-- Show every column and every row of the projects table. (Chapter
-- 10)
-- ------------------------------------------------------------
-- 1. Every column of projects
SELECT *
FROM projects
ORDER BY project_id;

-- Result:
--  project_id |  project_name   | department_id |  budget
-- ------------+-----------------+---------------+----------
--           1 | Payroll Upgrade |            20 | 50000.00
--           2 | Mobile App      |            30 | 75000.00
--           3 | Data Platform   |            30 | 60000.00
--           4 | Brand Refresh   |            40 | 45000.00
-- (4 rows)

-- ------------------------------------------------------------
-- Exercise 2
-- List the active customers who live in Chicago or New York.
-- (Chapter 10)
-- ------------------------------------------------------------
-- 2. Active customers in Chicago or New York
SELECT customer_id, first_name, last_name, city
FROM customers
WHERE status = 'active'
    AND city IN ('Chicago', 'New York')
ORDER BY customer_id;

-- Result:
--  customer_id | first_name | last_name |   city
-- -------------+------------+-----------+----------
--            1 | Alice      | Brown     | New York
--            3 | Charlie    | Evans     | New York
-- (2 rows)

-- ------------------------------------------------------------
-- Exercise 3
-- Find the products priced between 200 and 500, cheapest first.
-- (Chapter 10)
-- ------------------------------------------------------------
-- 3. Products priced from 200 to 500
SELECT product_name, price
FROM products
WHERE price BETWEEN 200 AND 500
ORDER BY price;

-- Result:
--  product_name | price
-- --------------+--------
--  Desk Chair   | 249.00
--  Monitor      | 300.00
--  Tablet       | 450.00
-- (3 rows)

-- ------------------------------------------------------------
-- Exercise 4
-- List the names and job titles of the employees whose title
-- contains the word Engineer. (Chapter 16)
-- ------------------------------------------------------------
-- 4. Employees with Engineer in their title
SELECT first_name, last_name, job_title
FROM employees
WHERE job_title LIKE '%Engineer%'
ORDER BY employee_id;

-- Result:
--  first_name | last_name |      job_title
-- ------------+-----------+---------------------
--  Emily      | Johnson   | Engineering Manager
--  Michael    | Williams  | Software Engineer
--  Sarah      | Chen      | Software Engineer
-- (3 rows)

-- ------------------------------------------------------------
-- Exercise 5
-- Show the three most expensive products and their prices. (Chapter
-- 10)
-- ------------------------------------------------------------
-- 5. The three most expensive products
SELECT product_name, price
FROM products
ORDER BY price DESC, product_id
LIMIT 3;

-- Result:
--  product_name |  price
-- --------------+---------
--  Laptop       | 1200.00
--  Smartphone   |  800.00
--  Tablet       |  450.00
-- (3 rows)

-- ------------------------------------------------------------
-- Exercise 6
-- Count the employees, and the number of different job titles they
-- hold. (Chapter 12)
-- ------------------------------------------------------------
-- 6. Employees and different job titles
SELECT COUNT(*) AS employees,
       COUNT(DISTINCT job_title) AS job_titles
FROM employees;

-- Result:
--  employees | job_titles
-- -----------+------------
--          8 |          7
-- (1 row)

-- ------------------------------------------------------------
-- Exercise 7
-- Find the highest, lowest and average product price, with the
-- average rounded to two decimal places. (Chapter 12)
-- ------------------------------------------------------------
-- 7. Highest, lowest and average price
SELECT MAX(price) AS highest,
       MIN(price) AS lowest,
       ROUND(AVG(price), 2) AS average
FROM products;

-- Result:
--  highest | lowest | average
-- ---------+--------+---------
--  1200.00 |  10.99 |  501.67
-- (1 row)

-- ------------------------------------------------------------
-- Exercise 8
-- For each product category, show the number of products and the
-- total number of units in stock. (Chapter 12)
-- ------------------------------------------------------------
-- 8. Products and stock per category
SELECT category,
       COUNT(*) AS products,
       SUM(stock) AS units_in_stock
FROM products
GROUP BY category
ORDER BY category;

-- Result:
--   category   | products | units_in_stock
-- -------------+----------+----------------
--  Electronics |        4 |            110
--  Furniture   |        1 |              8
--  Kitchen     |        1 |            100
-- (3 rows)

-- ------------------------------------------------------------
-- Exercise 9
-- List every order with its date and the first and last name of the
-- customer who placed it. (Chapter 11)
-- ------------------------------------------------------------
-- 9. Orders with customer names
SELECT o.order_id, o.order_date,
       c.first_name, c.last_name
FROM orders o
JOIN customers c
    ON c.customer_id = o.customer_id
ORDER BY o.order_id;

-- Result:
--  order_id | order_date | first_name | last_name
-- ----------+------------+------------+-----------
--       101 | 2024-01-15 | Alice      | Brown
--       102 | 2024-01-16 | Bob        | Davis
--       103 | 2024-01-17 | Charlie    | Evans
--       104 | 2024-02-03 | Alice      | Brown
--       105 | 2024-02-10 | Dana       | Kim
--       106 | 2024-03-05 | Charlie    | Evans
-- (6 rows)

-- ------------------------------------------------------------
-- Exercise 10
-- Find the orders worth more than 1,000. An order's value is the sum
-- of quantity × unit_price over its lines in order_items. (Chapter
-- 12)
-- ------------------------------------------------------------
-- 10. Orders worth more than 1,000
SELECT order_id,
       SUM(quantity * unit_price) AS order_value
FROM order_items
GROUP BY order_id
HAVING SUM(quantity * unit_price) > 1000
ORDER BY order_id;

-- Result:
--  order_id | order_value
-- ----------+-------------
--       101 |     1221.98
--       104 |     1800.00
--       106 |     1100.00
-- (3 rows)

-- ------------------------------------------------------------
-- Exercise 11
-- Show each employee's monthly salary, salary / 12, as a whole
-- number of dollars, using CAST. (Chapter 21)
-- ------------------------------------------------------------
-- 11. Monthly salary in whole dollars
SELECT first_name, last_name, salary,
       CAST(salary / 12 AS INTEGER) AS monthly
FROM employees
ORDER BY employee_id;

-- Result:
--  first_name | last_name |  salary   | monthly
-- ------------+-----------+-----------+---------
--  John       | Doe       | 150000.00 |   12500
--  Jane       | Smith     |  88000.00 |    7333
--  Emily      | Johnson   | 105000.00 |    8750
--  Michael    | Williams  |  92000.00 |    7667
--  Sarah      | Chen      |  92000.00 |    7667
--  David      | Brown     |  67000.00 |    5583
--  Priya      | Patel     |  58000.00 |    4833
--  Tom        | Wilson    |  71000.00 |    5917
-- (8 rows)

-- ------------------------------------------------------------
-- Exercise 12
-- Create a product_ratings table with a rating_id primary key, a
-- product_id that must refer to a product and a rating that must be
-- from 1 to 5. Add a rating of 5 for the Laptop and 4 for the Desk
-- Chair, then list the ratings. (Chapters 7 and 9)
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 12. A product_ratings table
DROP TABLE IF EXISTS product_ratings;

CREATE TABLE product_ratings (
    rating_id  INT PRIMARY KEY,
    product_id INT NOT NULL
        REFERENCES products (product_id),
    rating     INT NOT NULL,
    CONSTRAINT chk_product_ratings_rating
        CHECK (rating BETWEEN 1 AND 5)
);

INSERT INTO product_ratings
    (rating_id, product_id, rating)
VALUES
    (1, 1, 5),
    (2, 6, 4);

SELECT rating_id, product_id, rating
FROM product_ratings
ORDER BY rating_id;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  rating_id | product_id | rating
-- -----------+------------+--------
--          1 |          1 |      5
--          2 |          6 |      4
-- (2 rows)

-- ------------------------------------------------------------
-- Exercise 13
-- Bob Davis (customer 2) moves to Austin and becomes active again.
-- Record both changes with one UPDATE, then list the customers in
-- Austin. (Chapter 10)
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 13. Bob moves to Austin and is active again
UPDATE customers
SET city = 'Austin',
    status = 'active'
WHERE customer_id = 2;

SELECT customer_id, first_name, last_name,
       city, status
FROM customers
WHERE city = 'Austin'
ORDER BY customer_id;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  customer_id | first_name | last_name |  city  | status
-- -------------+------------+-----------+--------+--------
--            2 | Bob        | Davis     | Austin | active
--            4 | Dana       | Kim       | Austin | active
-- (2 rows)

-- ------------------------------------------------------------
-- Exercise 14
-- Using EXCEPT, list the IDs of the departments that have no
-- employees. (Chapter 11)
-- ------------------------------------------------------------
-- 14. Departments with no employees
SELECT department_id FROM departments
EXCEPT
SELECT department_id FROM employees;

-- Result:
--  department_id
-- ---------------
--             50
-- (1 row)

-- ------------------------------------------------------------
-- Exercise 15
-- Using IN with a subquery, list the orders placed by customers who
-- live in New York. (Chapter 13)
-- ------------------------------------------------------------
-- 15. Orders from New York customers
SELECT order_id, customer_id, order_date
FROM orders
WHERE customer_id IN (SELECT customer_id
                      FROM customers
                      WHERE city = 'New York')
ORDER BY order_id;

-- Result:
--  order_id | customer_id | order_date
-- ----------+-------------+------------
--       101 |           1 | 2024-01-15
--       103 |           3 | 2024-01-17
--       104 |           1 | 2024-02-03
--       106 |           3 | 2024-03-05
-- (4 rows)

-- ------------------------------------------------------------
-- Exercise 16
-- List the orders placed on a Saturday or a Sunday. (Chapter 14)
-- ------------------------------------------------------------
-- 16. Orders placed on a weekend
SELECT order_id, order_date,
       EXTRACT(DOW FROM order_date) AS weekday
FROM orders
WHERE EXTRACT(DOW FROM order_date) IN (0, 6)
ORDER BY order_id;

-- Result:
--  order_id | order_date | weekday
-- ----------+------------+---------
--       104 | 2024-02-03 |       6
--       105 | 2024-02-10 |       6
-- (2 rows)

-- ------------------------------------------------------------
-- Exercise 17
-- Find the employees who aren't assigned to any department. (Chapter
-- 15)
-- ------------------------------------------------------------
-- 17. Employees with no department
SELECT employee_id, first_name, last_name
FROM employees
WHERE department_id IS NULL;

-- Result:
--  employee_id | first_name | last_name
-- -------------+------------+-----------
--            8 | Tom        | Wilson
-- (1 row)

-- ------------------------------------------------------------
-- Exercise 18
-- List every customer's name and city, showing Unknown where no city
-- is recorded. (Chapter 15)
-- ------------------------------------------------------------
-- 18. Customers' cities, with a default
SELECT first_name, last_name,
       COALESCE(city, 'Unknown') AS city
FROM customers
ORDER BY customer_id;

-- Result:
--  first_name | last_name |   city
-- ------------+-----------+----------
--  Alice      | Brown     | New York
--  Bob        | Davis     | Chicago
--  Charlie    | Evans     | New York
--  Dana       | Kim       | Austin
--  Ethan      | Ruiz      | Unknown
-- (5 rows)

-- ------------------------------------------------------------
-- Exercise 19
-- Show each product's shipping class: Fragile for Electronics,
-- Oversized for Furniture and Standard for everything else. (Chapter
-- 20)
-- ------------------------------------------------------------
-- 19. Shipping class by category
SELECT product_name, category,
       CASE category
           WHEN 'Electronics' THEN 'Fragile'
           WHEN 'Furniture' THEN 'Oversized'
           ELSE 'Standard'
       END AS shipping_class
FROM products
ORDER BY product_id;

-- Result:
--  product_name |  category   | shipping_class
-- --------------+-------------+----------------
--  Laptop       | Electronics | Fragile
--  Smartphone   | Electronics | Fragile
--  Tablet       | Electronics | Fragile
--  Monitor      | Electronics | Fragile
--  Coffee Mug   | Kitchen     | Standard
--  Desk Chair   | Furniture   | Oversized
-- (6 rows)

-- ------------------------------------------------------------
-- Exercise 20
-- Name badges have room for 12 characters. List the employees whose
-- full name, first name and last name with a space between, is
-- longer than that, with its length. (Chapter 21)
-- ------------------------------------------------------------
-- 20. Names too long for a badge
SELECT first_name || ' ' || last_name
           AS full_name,
       LENGTH(first_name || ' ' || last_name)
           AS name_length
FROM employees
WHERE LENGTH(first_name || ' ' || last_name) > 12
ORDER BY employee_id;

-- Result:
--     full_name     | name_length
-- ------------------+-------------
--  Emily Johnson    |          13
--  Michael Williams |          16
-- (2 rows)

-- ------------------------------------------------------------
-- Example 1: Answers
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

DROP TABLE IF EXISTS product_ratings;

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Undo everything this file changed.
-- ------------------------------------------------------------
ROLLBACK;
