# Chapter 43: Fetching Rows
import os

import psycopg
from psycopg.rows import dict_row

DSN = os.environ["DATABASE_URL"]

with psycopg.connect(DSN) as conn:
    # Iterate over the cursor: one row at a time
    cur = conn.execute(
        "SELECT order_id, status FROM orders "
        "ORDER BY order_id"
    )
    for order_id, status in cur:
        print(order_id, status)

    # fetchmany: a few rows per call
    cur = conn.execute(
        "SELECT first_name FROM employees "
        "ORDER BY employee_id"
    )
    while batch := cur.fetchmany(3):
        print([name for (name,) in batch])

    # dict_row: each row is a dictionary
    cur = conn.cursor(row_factory=dict_row)
    cur.execute(
        "SELECT first_name, city FROM customers "
        "WHERE customer_id = %s",
        (5,),
    )
    print(cur.fetchone())
