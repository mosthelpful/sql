# Chapter 43: Handling Errors (retries)
import os
import time

import psycopg
from psycopg import errors, IsolationLevel

DSN = os.environ["DATABASE_URL"]
RETRYABLE = (errors.SerializationFailure,
             errors.DeadlockDetected)


def run_transaction(conn, work, attempts=3):
    for attempt in range(1, attempts + 1):
        try:
            with conn.transaction():
                return work(conn)
        except RETRYABLE as e:
            print("Attempt", attempt, e.sqlstate)
            if attempt == attempts:
                raise
            time.sleep(0.05 * 2 ** attempt)


sold_one = False


def add_chairs(conn):
    global sold_one
    stock = conn.execute(
        "SELECT stock FROM products "
        "WHERE product_id = 6"
    ).fetchone()[0]
    if not sold_one:
        # meanwhile, another session sells one
        other.execute(
            "UPDATE products "
            "SET stock = stock - 1 "
            "WHERE product_id = 6"
        )
        sold_one = True
    conn.execute(
        "UPDATE products SET stock = %s "
        "WHERE product_id = 6",
        (stock + 10,),
    )
    return stock + 10


conn = psycopg.connect(DSN, autocommit=True)
other = psycopg.connect(DSN, autocommit=True)
conn.isolation_level = (
    IsolationLevel.REPEATABLE_READ)

stock = run_transaction(conn, add_chairs)
print("New stock:", stock)

conn.close()
other.close()
