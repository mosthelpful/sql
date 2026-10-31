# Chapter 43: A Job Queue with SKIP LOCKED
# Creates the email_jobs table, runs two
# workers on it and drops the table at the end.
import os
import threading

import psycopg

DSN = os.environ["DATABASE_URL"]

CLAIM = """
    SELECT id, customer_id, attempts
    FROM email_jobs
    WHERE status = 'queued'
        AND run_after <= now()
    ORDER BY id
    LIMIT 1
    FOR UPDATE SKIP LOCKED"""

DONE = ("UPDATE email_jobs "
        "SET status = 'done' WHERE id = %s")

FAIL = """
    UPDATE email_jobs
    SET attempts = attempts + 1,
        last_error = %s,
        status = CASE WHEN attempts + 1 >= 3
                      THEN 'failed'
                      ELSE 'queued' END,
        run_after = now()
            + (attempts + 1) * INTERVAL '1 minute'
    WHERE id = %s"""


def send_email(customer_id):
    # Stands in for the real work
    if customer_id == 4:
        raise RuntimeError("mail server down")


def work_one(conn, log):
    with conn.transaction():
        row = conn.execute(CLAIM).fetchone()
        if row is None:
            return False
        job_id, customer_id, attempts = row
        try:
            send_email(customer_id)
        except Exception as e:
            conn.execute(FAIL, (str(e), job_id))
            log.append((job_id, "retry later"))
        else:
            conn.execute(DONE, (job_id,))
            log.append((job_id, "done"))
    return True


def worker(name, log):
    with psycopg.connect(DSN,
                         autocommit=True) as conn:
        while work_one(conn, log):
            pass


with psycopg.connect(DSN,
                     autocommit=True) as conn:
    conn.execute("""
        CREATE TABLE email_jobs (
            id          BIGINT GENERATED ALWAYS
                        AS IDENTITY PRIMARY KEY,
            customer_id INT NOT NULL
                REFERENCES customers,
            status      TEXT NOT NULL
                DEFAULT 'queued'
                CHECK (status IN (
                    'queued', 'running',
                    'done', 'failed')),
            attempts    INT NOT NULL DEFAULT 0,
            run_after   TIMESTAMPTZ NOT NULL
                DEFAULT now(),
            last_error  TEXT)""")
    conn.execute("""
        CREATE INDEX email_jobs_queued_idx
            ON email_jobs (id)
            WHERE status = 'queued'""")
    try:
        conn.execute(
            "INSERT INTO email_jobs "
            "(customer_id) "
            "SELECT customer_id FROM customers "
            "ORDER BY customer_id")
        logs = {"A": [], "B": []}
        threads = [
            threading.Thread(target=worker,
                             args=(n, logs[n]))
            for n in logs]
        for t in threads:
            t.start()
        for t in threads:
            t.join()
        handled = sorted(logs["A"] + logs["B"])
        print("Jobs handled:", len(handled))
        for job_id, outcome in handled:
            print(job_id, outcome)
        for row in conn.execute(
                "SELECT id, status, attempts "
                "FROM email_jobs ORDER BY id"):
            print(row)
    finally:
        conn.execute("DROP TABLE email_jobs")
