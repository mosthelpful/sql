# Chapter 43: Connection Pooling
import os

from psycopg_pool import ConnectionPool

DSN = os.environ["DATABASE_URL"]

# Create the pool once, at application start
pool = ConnectionPool(DSN, min_size=2,
                      max_size=10, open=True)


def customer_name(customer_id):
    with pool.connection() as conn:
        row = conn.execute(
            "SELECT first_name FROM customers "
            "WHERE customer_id = %s",
            (customer_id,),
        ).fetchone()
    return row[0] if row else None


for cid in (1, 4, 99):
    print(cid, customer_name(cid))

pool.close()  # when the application stops
