-- The Most Helpful SQL Guide, Second Edition
-- Chapter 16: Wildcards and Pattern Matching
--
-- Every example in this part of the book that runs on PostgreSQL,
-- in book order, with the result the book prints. Load
-- sample_db.sql first. To run the whole file in psql:
--   psql -d sqlguide -f chapters/ch16_wildcards.sql
-- It runs as one transaction and rolls back at the end, so your
-- database is left unchanged. Examples that change data or fail on
-- purpose are wrapped in a savepoint and undone, as in the book.
-- You can also copy any single example into a query window.

BEGIN;

-- ------------------------------------------------------------
-- Example 1: LIKE and Its Two Wildcards
-- ------------------------------------------------------------
SELECT first_name, last_name
FROM employees
WHERE last_name LIKE '%son'
ORDER BY last_name;

-- Result:
--  first_name | last_name
-- ------------+-----------
--  Emily      | Johnson
--  Tom        | Wilson
-- (2 rows)

-- ------------------------------------------------------------
-- Example 2: LIKE and Its Two Wildcards
-- ------------------------------------------------------------
SELECT first_name, last_name
FROM employees
WHERE first_name LIKE '_a%'
ORDER BY first_name;

-- Result:
--  first_name | last_name
-- ------------+-----------
--  David      | Brown
--  Jane       | Smith
--  Sarah      | Chen
-- (3 rows)

-- ------------------------------------------------------------
-- Example 3: NOT LIKE
-- ------------------------------------------------------------
SELECT first_name, last_name, city
FROM customers
WHERE city NOT LIKE 'New%'
ORDER BY customer_id;

-- Result:
--  first_name | last_name |  city
-- ------------+-----------+---------
--  Bob        | Davis     | Chicago
--  Dana       | Kim       | Austin
-- (2 rows)

-- ------------------------------------------------------------
-- Example 4: Case Sensitivity
-- ------------------------------------------------------------
SELECT product_name
FROM products
WHERE product_name LIKE '%m%'
ORDER BY product_name;

-- Result:
--  product_name
-- --------------
--  Smartphone
-- (1 row)

-- ------------------------------------------------------------
-- Example 5: Case Sensitivity
-- ------------------------------------------------------------
SELECT product_name
FROM products
WHERE product_name ILIKE '%m%'
ORDER BY product_name;

-- Result:
--  product_name
-- --------------
--  Coffee Mug
--  Monitor
--  Smartphone
-- (3 rows)

-- ------------------------------------------------------------
-- Example 6: Matching a Literal % or _
-- Sets up data for the examples that follow.
-- ------------------------------------------------------------
CREATE TEMPORARY TABLE promotions (
    promo_code  VARCHAR(20) PRIMARY KEY,
    description VARCHAR(50) NOT NULL
);

INSERT INTO promotions (promo_code, description)
VALUES
    ('SAVE10',    '10% off any monitor'),
    ('MUG_FREE',  'Free mug with a laptop'),
    ('BULK100',   '100 off orders over 1000'),
    ('SPRING_10', '10% off desk chairs');

-- ------------------------------------------------------------
-- Example 7: Matching a Literal % or _
-- ------------------------------------------------------------
SELECT promo_code
FROM promotions
WHERE promo_code LIKE '%_%'
ORDER BY promo_code;

-- Result:
--  promo_code
-- ------------
--  BULK100
--  MUG_FREE
--  SAVE10
--  SPRING_10
-- (4 rows)

-- ------------------------------------------------------------
-- Example 8: Matching a Literal % or _
-- ------------------------------------------------------------
SELECT promo_code
FROM promotions
WHERE promo_code LIKE '%!_%' ESCAPE '!'
ORDER BY promo_code;

-- Result:
--  promo_code
-- ------------
--  MUG_FREE
--  SPRING_10
-- (2 rows)

-- ------------------------------------------------------------
-- Example 9: Checking email addresses
-- ------------------------------------------------------------
CREATE TEMPORARY TABLE signups (
    email VARCHAR(100) PRIMARY KEY
);

INSERT INTO signups (email)
VALUES ('ann@example.com'),
       ('bob@example'),
       ('carl@@example.com'),
       ('dee @example.com'),
       ('eve.example.com');

SELECT email
FROM signups
WHERE email NOT LIKE '_%@__%.__%'
ORDER BY email;

-- Result:
--       email
-- -----------------
--  bob@example
--  eve.example.com
-- (2 rows)

-- ------------------------------------------------------------
-- Example 10: Checking email addresses
-- ------------------------------------------------------------
SELECT email
FROM signups
WHERE email !~ '^[^@ ]+@[^@ ]+\.[a-z]{2,}$'
ORDER BY email;

-- Result:
--        email
-- -------------------
--  bob@example
--  carl@@example.com
--  dee @example.com
--  eve.example.com
-- (4 rows)

-- ------------------------------------------------------------
-- Example 11: Replacing with REGEXP_REPLACE
-- ------------------------------------------------------------
SELECT email,
       REGEXP_REPLACE(email, '^(.)[^@]*', '\1***')
           AS masked_email
FROM customers
ORDER BY customer_id;

-- Result:
--         email        |   masked_email
-- ---------------------+------------------
--  alice@example.com   | a***@example.com
--  bob@example.com     | b***@example.com
--  charlie@example.com | c***@example.com
--  dana@example.com    | d***@example.com
--  ethan@example.com   | e***@example.com
-- (5 rows)

-- ------------------------------------------------------------
-- Example 12: Searching for Words
-- Sets up data for the examples that follow.
-- ------------------------------------------------------------
CREATE TEMPORARY TABLE reviews (
    review_id  INT PRIMARY KEY,
    product_id INT NOT NULL,
    body       TEXT NOT NULL
);

INSERT INTO reviews (review_id, product_id, body)
VALUES
    (1, 6, 'Comfortable chair, easy to build.'),
    (2, 1, 'Fast, but the battery drains fast.'),
    (3, 3, 'Sharp screen; the battery lasts.'),
    (4, 6, 'Both chairs arrived scratched.'),
    (5, 2, 'Fine for reading in an armchair.');

-- ------------------------------------------------------------
-- Example 13: Searching for Words
-- ------------------------------------------------------------
SELECT to_tsvector('english', body) AS words
FROM reviews
WHERE review_id = 4;

-- Result:
--               words
-- ---------------------------------
--  'arriv':3 'chair':2 'scratch':4
-- (1 row)

-- ------------------------------------------------------------
-- Example 14: Searching for Words
-- ------------------------------------------------------------
SELECT review_id, body
FROM reviews
WHERE to_tsvector('english', body)
      @@ websearch_to_tsquery('english', 'chair')
ORDER BY review_id;

-- Result:
--  review_id |               body
-- -----------+-----------------------------------
--          1 | Comfortable chair, easy to build.
--          4 | Both chairs arrived scratched.
-- (2 rows)

-- ------------------------------------------------------------
-- Example 15: Searching for Words
-- ------------------------------------------------------------
SELECT r.review_id, r.body
FROM reviews r
CROSS JOIN websearch_to_tsquery(
    'english', 'battery OR screen') q
WHERE to_tsvector('english', r.body) @@ q
ORDER BY ts_rank(
    to_tsvector('english', r.body), q) DESC;

-- Result:
--  review_id |                body
-- -----------+------------------------------------
--          3 | Sharp screen; the battery lasts.
--          2 | Fast, but the battery drains fast.
-- (2 rows)

-- ------------------------------------------------------------
-- Example 16: Searching for Words
-- ------------------------------------------------------------
CREATE INDEX idx_reviews_body
    ON reviews
    USING GIN (to_tsvector('english', body));

-- Result: CREATE INDEX

-- ------------------------------------------------------------
-- Try It 1
-- Find the employees whose last name is exactly five letters long.
-- ------------------------------------------------------------
-- 1. Last names of exactly five letters
SELECT first_name, last_name
FROM employees
WHERE last_name LIKE '_____'
ORDER BY last_name;

-- Result:
--  first_name | last_name
-- ------------+-----------
--  David      | Brown
--  Priya      | Patel
--  Jane       | Smith
-- (3 rows)

-- ------------------------------------------------------------
-- Try It 2
-- Find the promotions whose description contains "10%".
-- ------------------------------------------------------------
-- 2. Descriptions containing "10%"
SELECT promo_code, description
FROM promotions
WHERE description LIKE '%10!%%' ESCAPE '!'
ORDER BY promo_code;

-- Result:
--  promo_code |     description
-- ------------+---------------------
--  SAVE10     | 10% off any monitor
--  SPRING_10  | 10% off desk chairs
-- (2 rows)

-- ------------------------------------------------------------
-- Try It 3
-- Using a regular expression, find the employees whose job title
-- ends in "Manager" or "Engineer".
-- ------------------------------------------------------------
-- 3. Job titles ending in Manager or Engineer
SELECT first_name, last_name, job_title
FROM employees
WHERE job_title ~ '(Manager|Engineer)$'
ORDER BY employee_id;

-- Result:
--  first_name | last_name |      job_title
-- ------------+-----------+---------------------
--  Jane       | Smith     | Finance Manager
--  Emily      | Johnson   | Engineering Manager
--  Michael    | Williams  | Software Engineer
--  Sarah      | Chen      | Software Engineer
-- (4 rows)

-- ------------------------------------------------------------
-- Undo everything this file changed.
-- ------------------------------------------------------------
ROLLBACK;
