-- The Most Helpful SQL Guide, Second Edition
-- Chapter 44: Capstone Project: A Library Database
--
-- Every example in this part of the book that runs on PostgreSQL,
-- in book order, with the result the book prints. Load
-- sample_db.sql first. To run the whole file in psql:
--   psql -d sqlguide -f chapters/ch44_capstone_project.sql
-- It runs as one transaction and rolls back at the end, so your
-- database is left unchanged. Examples that change data or fail on
-- purpose are wrapped in a savepoint and undone, as in the book.
-- You can also copy any single example into a query window.

BEGIN;

-- ------------------------------------------------------------
-- Example 1: A Schema of Its Own
-- ------------------------------------------------------------
CREATE SCHEMA library;

SET search_path = library, public;

SHOW search_path;

-- Result:
--    search_path
-- -----------------
--  library, public
-- (1 row)

-- ------------------------------------------------------------
-- Example 2: The tables
-- ------------------------------------------------------------
CREATE TABLE members (
    member_id  INT GENERATED ALWAYS AS IDENTITY
               PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name  VARCHAR(50) NOT NULL,
    email      VARCHAR(100) NOT NULL UNIQUE,
    joined_on  DATE NOT NULL
);

CREATE TABLE books (
    book_id        INT PRIMARY KEY,
    title          VARCHAR(200) NOT NULL,
    published_year INT NOT NULL
);

CREATE TABLE authors (
    author_id   INT GENERATED ALWAYS AS IDENTITY
                PRIMARY KEY,
    author_name VARCHAR(100) NOT NULL
);

CREATE TABLE book_authors (
    book_id         INT NOT NULL
                    REFERENCES books (book_id)
                    ON DELETE CASCADE,
    author_id       INT NOT NULL REFERENCES
                    authors (author_id),
    author_position INT NOT NULL
                    CHECK (author_position > 0),
    PRIMARY KEY (book_id, author_id)
);

CREATE TABLE copies (
    copy_id     INT GENERATED ALWAYS AS IDENTITY
                PRIMARY KEY,
    book_id     INT NOT NULL
                REFERENCES books (book_id),
    barcode     VARCHAR(20) NOT NULL UNIQUE,
    acquired_on DATE NOT NULL
);

CREATE TABLE loans (
    loan_id     INT GENERATED ALWAYS AS IDENTITY
                PRIMARY KEY,
    copy_id     INT NOT NULL
                REFERENCES copies (copy_id),
    member_id   INT NOT NULL
                REFERENCES members (member_id),
    loaned_on   DATE NOT NULL,
    due_date    DATE GENERATED ALWAYS AS
                (loaned_on + 21) STORED,
    returned_on DATE,
    CONSTRAINT loans_returned_after_loaned
        CHECK (returned_on >= loaned_on)
);

-- Result: CREATE TABLE

-- ------------------------------------------------------------
-- Example 3: Books from a CSV file
-- Sets up data for the examples that follow.
-- ------------------------------------------------------------
INSERT INTO books
    (book_id, title, published_year)
VALUES
    (1, 'Pride and Prejudice', 1813),
    (2, 'Frankenstein', 1818),
    (3, 'Moby-Dick', 1851),
    (4, 'Dracula', 1897),
    (5, 'The Time Machine', 1895),
    (6, 'Good Omens', 1990),
    (7, 'Emma', 1815),
    (8, 'The Hound of the Baskervilles', 1902);

-- ------------------------------------------------------------
-- Example 4: Authors
-- ------------------------------------------------------------
INSERT INTO authors (author_name)
VALUES
    ('Jane Austen'), ('Mary Shelley'),
    ('Herman Melville'), ('Bram Stoker'),
    ('H. G. Wells'), ('Terry Pratchett'),
    ('Neil Gaiman'), ('Arthur Conan Doyle');

INSERT INTO book_authors
    (book_id, author_id, author_position)
VALUES
    (1, 1, 1), (2, 2, 1), (3, 3, 1), (4, 4, 1),
    (5, 5, 1), (6, 6, 1), (6, 7, 2), (7, 1, 1),
    (8, 8, 1);

SELECT b.title,
       STRING_AGG(a.author_name, ' and '
                  ORDER BY ba.author_position)
           AS authors
FROM books b
JOIN book_authors ba
    ON ba.book_id = b.book_id
JOIN authors a
    ON a.author_id = ba.author_id
GROUP BY b.book_id, b.title
ORDER BY b.book_id;

-- Result:
--              title             |             authors
-- -------------------------------+---------------------------------
--  Pride and Prejudice           | Jane Austen
--  Frankenstein                  | Mary Shelley
--  Moby-Dick                     | Herman Melville
--  Dracula                       | Bram Stoker
--  The Time Machine              | H. G. Wells
--  Good Omens                    | Terry Pratchett and Neil Gaiman
--  Emma                          | Jane Austen
--  The Hound of the Baskervilles | Arthur Conan Doyle
-- (8 rows)

-- ------------------------------------------------------------
-- Example 5: Members, copies and loans
-- ------------------------------------------------------------
INSERT INTO members
    (first_name, last_name, email, joined_on)
VALUES
    ('Maya', 'Lopez', 'maya.lopez@example.com',
     DATE '2023-11-02'),
    ('Sam', 'Reed', 'sam.reed@example.com',
     DATE '2023-11-15'),
    ('Priya', 'Nair', 'priya.nair@example.com',
     DATE '2023-12-01'),
    ('Leo', 'Martin', 'leo.martin@example.com',
     DATE '2024-01-08'),
    ('Grace', 'Kim', 'grace.kim@example.com',
     DATE '2024-02-20'),
    ('Omar', 'Haddad', 'omar.haddad@example.com',
     DATE '2024-06-03');

INSERT INTO copies
    (book_id, barcode, acquired_on)
VALUES
    (1, 'B0001', DATE '2023-10-01'),
    (1, 'B0002', DATE '2023-10-01'),
    (2, 'B0003', DATE '2023-10-01'),
    (2, 'B0004', DATE '2023-10-01'),
    (3, 'B0005', DATE '2023-10-01'),
    (4, 'B0006', DATE '2023-10-01'),
    (4, 'B0007', DATE '2023-10-01'),
    (5, 'B0008', DATE '2023-10-01'),
    (6, 'B0009', DATE '2023-10-01'),
    (6, 'B0010', DATE '2023-10-01'),
    (7, 'B0011', DATE '2023-10-01'),
    (8, 'B0012', DATE '2024-05-15');

-- Result: INSERT 0 12

-- ------------------------------------------------------------
-- Example 6: Members, copies and loans
-- ------------------------------------------------------------
INSERT INTO loans
    (copy_id, member_id, loaned_on, returned_on)
VALUES
    (3, 1, DATE '2024-01-05', DATE '2024-01-20'),
    (6, 2, DATE '2024-01-12', DATE '2024-01-30'),
    (1, 3, DATE '2024-01-15', DATE '2024-02-02'),
    (4, 2, DATE '2024-02-03', DATE '2024-02-21'),
    (9, 4, DATE '2024-02-10', DATE '2024-03-05'),
    (7, 1, DATE '2024-04-02', DATE '2024-04-18'),
    (5, 5, DATE '2024-04-20', DATE '2024-05-08'),
    (3, 3, DATE '2024-05-06', NULL),
    (6, 4, DATE '2024-05-28', DATE '2024-06-10'),
    (11, 2, DATE '2024-06-01', NULL),
    (8, 1, DATE '2024-06-15', NULL),
    (10, 5, DATE '2024-06-24', NULL);

SELECT loan_id, copy_id, member_id, loaned_on,
       due_date, returned_on
FROM loans
WHERE returned_on IS NULL
ORDER BY loan_id;

-- Result:
--  loan_id | copy_id | member_id | loaned_on  |  due_date  | returned_on
-- ---------+---------+-----------+------------+------------+-------------
--        8 |       3 |         3 | 2024-05-06 | 2024-05-27 | NULL
--       10 |      11 |         2 | 2024-06-01 | 2024-06-22 | NULL
--       11 |       8 |         1 | 2024-06-15 | 2024-07-06 | NULL
--       12 |      10 |         5 | 2024-06-24 | 2024-07-15 | NULL
-- (4 rows)

-- ------------------------------------------------------------
-- Example 7: Overdue loans
-- ------------------------------------------------------------
SELECT m.first_name, m.last_name, b.title,
       l.due_date,
       DATE '2024-06-30' - l.due_date
           AS days_overdue
FROM loans l
JOIN members m
    ON m.member_id = l.member_id
JOIN copies c
    ON c.copy_id = l.copy_id
JOIN books b
    ON b.book_id = c.book_id
WHERE l.returned_on IS NULL
    AND l.due_date < DATE '2024-06-30'
ORDER BY days_overdue DESC, l.loan_id;

-- Result:
--  first_name | last_name |    title     |  due_date  | days_overdue
-- ------------+-----------+--------------+------------+--------------
--  Priya      | Nair      | Frankenstein | 2024-05-27 |           34
--  Sam        | Reed      | Emma         | 2024-06-22 |            8
-- (2 rows)

-- ------------------------------------------------------------
-- Example 8: The most-borrowed titles
-- ------------------------------------------------------------
SELECT b.title,
       COUNT(*) AS loans,
       RANK() OVER (ORDER BY COUNT(*) DESC)
           AS loan_rank
FROM loans l
JOIN copies c
    ON c.copy_id = l.copy_id
JOIN books b
    ON b.book_id = c.book_id
GROUP BY b.book_id, b.title
ORDER BY loan_rank, b.title;

-- Result:
--         title        | loans | loan_rank
-- ---------------------+-------+-----------
--  Dracula             |     3 |         1
--  Frankenstein        |     3 |         1
--  Good Omens          |     2 |         3
--  Emma                |     1 |         4
--  Moby-Dick           |     1 |         4
--  Pride and Prejudice |     1 |         4
--  The Time Machine    |     1 |         4
-- (7 rows)

-- ------------------------------------------------------------
-- Example 9: Member activity
-- ------------------------------------------------------------
SELECT m.first_name, m.last_name,
       COUNT(l.loan_id) AS loans,
       COUNT(l.loan_id) FILTER (
           WHERE l.returned_on IS NULL)
           AS on_loan,
       COALESCE(TO_CHAR(MAX(l.loaned_on),
                        'YYYY-MM-DD'),
                'never') AS last_loan
FROM members m
LEFT JOIN loans l
    ON l.member_id = m.member_id
GROUP BY m.member_id, m.first_name, m.last_name
ORDER BY loans DESC, m.member_id;

-- Result:
--  first_name | last_name | loans | on_loan | last_loan
-- ------------+-----------+-------+---------+------------
--  Maya       | Lopez     |     3 |       1 | 2024-06-15
--  Sam        | Reed      |     3 |       1 | 2024-06-01
--  Priya      | Nair      |     2 |       1 | 2024-05-06
--  Leo        | Martin    |     2 |       0 | 2024-05-28
--  Grace      | Kim       |     2 |       1 | 2024-06-24
--  Omar       | Haddad    |     0 |       0 | never
-- (6 rows)

-- ------------------------------------------------------------
-- Example 10: Loans per month
-- ------------------------------------------------------------
SELECT CAST(m.month_start AS DATE) AS month,
       COUNT(l.loan_id) AS loans
FROM generate_series(DATE '2024-01-01',
                     DATE '2024-06-01',
                     INTERVAL '1 month')
         m(month_start)
LEFT JOIN loans l
    ON l.loaned_on >= m.month_start
    AND l.loaned_on < m.month_start
                     + INTERVAL '1 month'
GROUP BY m.month_start
ORDER BY m.month_start;

-- Result:
--    month    | loans
-- ------------+-------
--  2024-01-01 |     3
--  2024-02-01 |     2
--  2024-03-01 |     0
--  2024-04-01 |     2
--  2024-05-01 |     2
--  2024-06-01 |     3
-- (6 rows)

-- ------------------------------------------------------------
-- Example 11: Copies never lent
-- ------------------------------------------------------------
SELECT c.barcode, b.title, c.acquired_on
FROM copies c
JOIN books b
    ON b.book_id = c.book_id
WHERE NOT EXISTS (
    SELECT 1
    FROM loans l
    WHERE l.copy_id = c.copy_id
)
ORDER BY c.barcode;

-- Result:
--  barcode |             title             | acquired_on
-- ---------+-------------------------------+-------------
--  B0002   | Pride and Prejudice           | 2023-10-01
--  B0012   | The Hound of the Baskervilles | 2024-05-15
-- (2 rows)

-- ------------------------------------------------------------
-- Example 12: A view for the front desk
-- ------------------------------------------------------------
CREATE VIEW front_desk AS
SELECT c.barcode, b.title,
       m.first_name, m.last_name,
       l.loaned_on, l.due_date
FROM loans l
JOIN copies c
    ON c.copy_id = l.copy_id
JOIN books b
    ON b.book_id = c.book_id
JOIN members m
    ON m.member_id = l.member_id
WHERE l.returned_on IS NULL;

SELECT barcode, title, first_name, due_date
FROM front_desk
ORDER BY due_date;

-- Result:
--  barcode |      title       | first_name |  due_date
-- ---------+------------------+------------+------------
--  B0003   | Frankenstein     | Priya      | 2024-05-27
--  B0011   | Emma             | Sam        | 2024-06-22
--  B0008   | The Time Machine | Maya       | 2024-07-06
--  B0010   | Good Omens       | Grace      | 2024-07-15
-- (4 rows)

-- ------------------------------------------------------------
-- Example 13: Returning a copy
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

UPDATE loans
SET returned_on = DATE '2024-06-30'
WHERE copy_id = (SELECT copy_id
                 FROM copies
                 WHERE barcode = 'B0011')
    AND returned_on IS NULL;

SELECT barcode, title, first_name, due_date
FROM front_desk
ORDER BY due_date;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  barcode |      title       | first_name |  due_date
-- ---------+------------------+------------+------------
--  B0003   | Frankenstein     | Priya      | 2024-05-27
--  B0008   | The Time Machine | Maya       | 2024-07-06
--  B0010   | Good Omens       | Grace      | 2024-07-15
-- (3 rows)

-- ------------------------------------------------------------
-- Example 14: Lending a copy
-- ------------------------------------------------------------
CREATE FUNCTION library.lend_copy(
    p_copy_id   INT,
    p_member_id INT,
    p_loaned_on DATE DEFAULT CURRENT_DATE)
RETURNS DATE
LANGUAGE plpgsql
AS $$
DECLARE
    v_due DATE;
BEGIN
    IF EXISTS (
        SELECT 1 FROM library.loans
        WHERE copy_id = p_copy_id
            AND returned_on IS NULL
    ) THEN
        RAISE EXCEPTION
            'Copy % is already on loan',
            p_copy_id;
    ELSIF EXISTS (
        SELECT 1 FROM library.loans
        WHERE member_id = p_member_id
            AND returned_on IS NULL
            AND due_date < p_loaned_on
    ) THEN
        RAISE EXCEPTION
            'Member % has overdue books',
            p_member_id;
    END IF;

    INSERT INTO library.loans
        (copy_id, member_id, loaned_on)
    VALUES (p_copy_id, p_member_id, p_loaned_on)
    RETURNING due_date INTO v_due;

    RETURN v_due;
END;
$$;

-- Result: CREATE FUNCTION

-- ------------------------------------------------------------
-- Example 15: Lending a copy
-- Fails on purpose, to show the error.
-- ------------------------------------------------------------
SAVEPOINT example;

SELECT library.lend_copy(3, 6, DATE '2024-06-30');

ROLLBACK TO SAVEPOINT example;

-- Expected error:
--   ERROR:  Copy 3 is already on loan

-- ------------------------------------------------------------
-- Example 16: Lending a copy
-- Fails on purpose, to show the error.
-- ------------------------------------------------------------
SAVEPOINT example;

SELECT library.lend_copy(2, 3, DATE '2024-06-30');

ROLLBACK TO SAVEPOINT example;

-- Expected error:
--   ERROR:  Member 3 has overdue books

-- ------------------------------------------------------------
-- Example 17: Lending a copy
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

SELECT library.lend_copy(12, 6, DATE '2024-06-30')
           AS due_date;

ROLLBACK TO SAVEPOINT example;

-- Result:
--   due_date
-- ------------
--  2024-07-21
-- (1 row)

-- ------------------------------------------------------------
-- Example 18: One open loan per copy
-- ------------------------------------------------------------
CREATE UNIQUE INDEX loans_one_open_per_copy
    ON loans (copy_id)
    WHERE returned_on IS NULL;

-- Result: CREATE INDEX

-- ------------------------------------------------------------
-- Example 19: One open loan per copy
-- Fails on purpose, to show the error.
-- ------------------------------------------------------------
SAVEPOINT example;

INSERT INTO loans
    (copy_id, member_id, loaned_on)
VALUES (3, 6, DATE '2024-06-30');

ROLLBACK TO SAVEPOINT example;

-- Expected error:
--   ERROR:  duplicate key value violates unique constraint "loans_one_open_per_copy"
--   DETAIL:  Key (copy_id)=(3) already exists.

-- ------------------------------------------------------------
-- Example 20: Performance at Scale
-- ------------------------------------------------------------
INSERT INTO members
    (first_name, last_name, email, joined_on)
SELECT 'Reader', 'No. ' || n,
       'reader' || n || '@example.com',
       DATE '2017-01-01'
FROM generate_series(1, 1000) n;

INSERT INTO copies
    (book_id, barcode, acquired_on)
SELECT n % 8 + 1,
       'H' || LPAD(CAST(n AS VARCHAR), 4, '0'),
       DATE '2017-01-01'
FROM generate_series(1, 500) n;

INSERT INTO loans
    (copy_id, member_id, loaned_on, returned_on)
SELECT n % 500 + 13,
       n % 1000 + 7,
       DATE '2017-01-01' + n / 10,
       DATE '2017-01-01' + n / 10 + n % 15
FROM generate_series(1, 25000) n;

ANALYZE members, copies, loans;

SELECT COUNT(*) AS loans,
       MIN(loaned_on) AS first_loan,
       MAX(loaned_on) AS last_loan
FROM loans;

-- Result:
--  loans | first_loan | last_loan
-- -------+------------+------------
--  25012 | 2017-01-01 | 2024-06-24
-- (1 row)

-- ------------------------------------------------------------
-- Example 21: Performance at Scale
-- ------------------------------------------------------------
EXPLAIN (COSTS OFF)
SELECT loaned_on, due_date, returned_on
FROM loans
WHERE member_id = 42
ORDER BY loaned_on;

-- Plan:
--   Sort
--     Sort Key: loaned_on
--     ->  Seq Scan on loans
--           Filter: (member_id = 42)

-- ------------------------------------------------------------
-- Example 22: Performance at Scale
-- ------------------------------------------------------------
CREATE INDEX loans_member_id_idx
    ON loans (member_id);

EXPLAIN (COSTS OFF)
SELECT loaned_on, due_date, returned_on
FROM loans
WHERE member_id = 42
ORDER BY loaned_on;

-- Plan:
--   Sort
--     Sort Key: loaned_on
--     ->  Bitmap Heap Scan on loans
--           Recheck Cond: (member_id = 42)
--           ->  Bitmap Index Scan on loans_member_id_idx
--                 Index Cond: (member_id = 42)

-- ------------------------------------------------------------
-- Example 23: Performance at Scale
-- ------------------------------------------------------------
EXPLAIN (COSTS OFF)
SELECT loan_id, due_date
FROM loans
WHERE returned_on IS NULL
    AND due_date < DATE '2024-06-30'
ORDER BY due_date;

-- Plan:
--   Sort
--     Sort Key: due_date
--     ->  Bitmap Heap Scan on loans
--           Recheck Cond: (returned_on IS NULL)
--           Filter: (due_date < '2024-06-30'::date)
--           ->  Bitmap Index Scan on loans_one_open_per_copy

-- ------------------------------------------------------------
-- Try It 1
-- The library charges 25 cents for each day a book is overdue. List
-- each overdue loan with the member's name and the fine so far, as
-- of June 30, 2024.
-- ------------------------------------------------------------
-- 1. Fines on overdue loans
SELECT m.first_name, m.last_name,
       DATE '2024-06-30' - l.due_date
           AS days_overdue,
       (DATE '2024-06-30' - l.due_date) * 0.25
           AS fine
FROM loans l
JOIN members m
    ON m.member_id = l.member_id
WHERE l.returned_on IS NULL
    AND l.due_date < DATE '2024-06-30'
ORDER BY fine DESC, l.loan_id;

-- Result:
--  first_name | last_name | days_overdue | fine
-- ------------+-----------+--------------+------
--  Priya      | Nair      |           34 | 8.50
--  Sam        | Reed      |            8 | 2.00
-- (2 rows)

-- ------------------------------------------------------------
-- Try It 2
-- List every returned loan that came back after its due date, with
-- the barcode and the number of days late.
-- ------------------------------------------------------------
-- 2. Late returns
SELECT c.barcode, l.due_date, l.returned_on,
       l.returned_on - l.due_date AS days_late
FROM loans l
JOIN copies c
    ON c.copy_id = l.copy_id
WHERE l.returned_on > l.due_date
ORDER BY days_late DESC, l.loan_id;

-- Result:
--  barcode |  due_date  | returned_on | days_late
-- ---------+------------+-------------+-----------
--  B0009   | 2024-03-02 | 2024-03-05  |         3
-- (1 row)

-- ------------------------------------------------------------
-- Try It 3
-- The library starts allowing renewals: a loan that isn't overdue
-- can be extended by 21 days. Change due_date into a plain column,
-- then renew Maya's loan of copy B0008 and show its new due date.
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 3. Renewals
ALTER TABLE loans
    ALTER COLUMN due_date DROP EXPRESSION;

UPDATE loans
SET due_date = due_date + 21
WHERE copy_id = (SELECT copy_id
                 FROM copies
                 WHERE barcode = 'B0008')
    AND returned_on IS NULL
    AND due_date >= DATE '2024-06-30';

SELECT copy_id, loaned_on, due_date
FROM loans
WHERE copy_id = 8
    AND returned_on IS NULL;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  copy_id | loaned_on  |  due_date
-- ---------+------------+------------
--        8 | 2024-06-15 | 2024-07-27
-- (1 row)

-- ------------------------------------------------------------
-- Example 24: Try It
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

DROP SCHEMA IF EXISTS library CASCADE;
RESET search_path;

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Undo everything this file changed.
-- ------------------------------------------------------------
ROLLBACK;
