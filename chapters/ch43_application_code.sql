-- The Most Helpful SQL Guide, Second Edition
-- Chapter 43: SQL from Application Code
--
-- Every example in this chapter that runs on PostgreSQL,
-- in book order, with the result the book prints. Load
-- sample_db.sql first. To run the whole file in psql:
--   psql -d sqlguide -f chapters/ch43_application_code.sql
-- It runs as one transaction and rolls back at the end, so your
-- database is left unchanged. Examples that change data or fail on
-- purpose are wrapped in a savepoint and undone, as in the book.
-- You can also copy any single example into a query window.

BEGIN;

-- ------------------------------------------------------------
-- Example 1: When to write SQL yourself
-- ------------------------------------------------------------
SELECT c.customer_id, c.first_name,
       COUNT(o.order_id) AS order_count
FROM customers c
LEFT JOIN orders o
    ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name
ORDER BY c.customer_id;

-- Result:
--  customer_id | first_name | order_count
-- -------------+------------+-------------
--            1 | Alice      |           2
--            2 | Bob        |           1
--            3 | Charlie    |           2
--            4 | Dana       |           1
--            5 | Ethan      |           0
-- (5 rows)

-- ------------------------------------------------------------
-- Example 2: Files and a version table
-- ------------------------------------------------------------
CREATE TABLE applied_migrations (
    version    INT PRIMARY KEY,
    name       TEXT NOT NULL,
    applied_on TIMESTAMPTZ NOT NULL
        DEFAULT now()
);

-- Result: CREATE TABLE

-- ------------------------------------------------------------
-- Example 3: Files and a version table
-- ------------------------------------------------------------
-- 0001_add_newsletter_opt_in.sql
ALTER TABLE customers
    ADD COLUMN newsletter_opt_in BOOLEAN;

INSERT INTO applied_migrations (version, name)
VALUES (1, 'add_newsletter_opt_in');

-- Result: INSERT 0 1

-- ------------------------------------------------------------
-- Example 4: Files and a version table
-- ------------------------------------------------------------
-- 0002_require_newsletter_opt_in.sql
UPDATE customers
SET newsletter_opt_in = FALSE
WHERE newsletter_opt_in IS NULL;

ALTER TABLE customers
    ALTER COLUMN newsletter_opt_in SET NOT NULL;

INSERT INTO applied_migrations (version, name)
VALUES (2, 'require_newsletter_opt_in');

-- Result: INSERT 0 1

-- ------------------------------------------------------------
-- Example 5: Files and a version table
-- ------------------------------------------------------------
SELECT version, name
FROM applied_migrations
ORDER BY version;

-- Result:
--  version |           name
-- ---------+---------------------------
--        1 | add_newsletter_opt_in
--        2 | require_newsletter_opt_in
-- (2 rows)

-- ------------------------------------------------------------
-- Example 6: Files and a version table
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

ALTER TABLE customers
    DROP COLUMN newsletter_opt_in;
DROP TABLE applied_migrations;

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Example 7: Changing a live database
-- Fails on purpose, to show the error.
-- ------------------------------------------------------------
SAVEPOINT example;

CREATE INDEX CONCURRENTLY orders_status_idx
    ON orders (status);

ROLLBACK TO SAVEPOINT example;

-- Expected error:
--   ERROR:  CREATE INDEX CONCURRENTLY cannot run inside a transaction block

-- ------------------------------------------------------------
-- Example 8: A Job Queue with SKIP LOCKED
-- ------------------------------------------------------------
CREATE TABLE email_jobs (
    id          BIGINT GENERATED ALWAYS
                AS IDENTITY PRIMARY KEY,
    customer_id INT NOT NULL
        REFERENCES customers,
    status      TEXT NOT NULL DEFAULT 'queued'
        CHECK (status IN ('queued', 'running',
                          'done', 'failed')),
    attempts    INT NOT NULL DEFAULT 0,
    run_after   TIMESTAMPTZ NOT NULL
        DEFAULT now(),
    last_error  TEXT
);

CREATE INDEX email_jobs_queued_idx
    ON email_jobs (id)
    WHERE status = 'queued';

-- Result: CREATE INDEX

-- ------------------------------------------------------------
-- Example 9: A Job Queue with SKIP LOCKED
-- ------------------------------------------------------------
INSERT INTO email_jobs (customer_id)
SELECT customer_id
FROM customers
ORDER BY customer_id;

-- Result: INSERT 0 5

-- ------------------------------------------------------------
-- Example 10: Claiming a job
-- ------------------------------------------------------------
UPDATE email_jobs
SET status = 'running'
WHERE id = (
    SELECT id
    FROM email_jobs
    WHERE status = 'queued'
        AND run_after <= now()
    ORDER BY id
    LIMIT 1
    FOR UPDATE SKIP LOCKED
)
RETURNING id, customer_id, attempts;

-- Result:
--  id | customer_id | attempts
-- ----+-------------+----------
--   1 |           1 |        0
-- (1 row)

-- ------------------------------------------------------------
-- Example 11: Claiming a job
-- ------------------------------------------------------------
UPDATE email_jobs
SET status = 'done'
WHERE id = 1;

-- Result: UPDATE 1

-- ------------------------------------------------------------
-- Example 12: Failures and retries
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

UPDATE email_jobs
SET attempts = 2
WHERE id = 2;

UPDATE email_jobs
SET attempts = attempts + 1,
    last_error = 'mail server down',
    status = CASE WHEN attempts + 1 >= 3
                  THEN 'failed'
                  ELSE 'queued' END,
    run_after = now()
        + (attempts + 1) * INTERVAL '1 minute'
WHERE id = 2;

SELECT status, COUNT(*) AS jobs
FROM email_jobs
GROUP BY status
ORDER BY status;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  status | jobs
-- --------+------
--  done   |    1
--  failed |    1
--  queued |    3
-- (3 rows)

-- ------------------------------------------------------------
-- Example 13: LISTEN and NOTIFY
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

LISTEN email_jobs_ready;

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Example 14: LISTEN and NOTIFY
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

NOTIFY email_jobs_ready, '6';
SELECT pg_notify('email_jobs_ready', '6');

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Example 15: LISTEN and NOTIFY
-- Fails on purpose, to show the error.
-- ------------------------------------------------------------
SAVEPOINT example;

SELECT pg_notify('email_jobs_ready',
                 repeat('x', 8000));

ROLLBACK TO SAVEPOINT example;

-- Expected error:
--   ERROR:  payload string too long

-- ------------------------------------------------------------
-- Example 16: LISTEN and NOTIFY
-- ------------------------------------------------------------
CREATE FUNCTION notify_email_job()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM pg_notify('email_jobs_ready',
                      NEW.id::text);
    RETURN NEW;
END;
$$;

CREATE TRIGGER email_jobs_notify
AFTER INSERT ON email_jobs
FOR EACH ROW
EXECUTE FUNCTION notify_email_job();

-- Result: CREATE TRIGGER

-- ------------------------------------------------------------
-- Example 17: LISTEN and NOTIFY
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

DROP TABLE email_jobs;
DROP FUNCTION notify_email_job();
UNLISTEN *;

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Undo everything this file changed.
-- ------------------------------------------------------------
ROLLBACK;
