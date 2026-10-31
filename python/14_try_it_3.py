# Chapter 43: Try It, answer 3
# 3. Roll back before the with block commits
import os

import psycopg

DSN = os.environ["DATABASE_URL"]

with psycopg.connect(DSN) as conn:
    cur = conn.execute(
        "UPDATE products "
        "SET price = price * 1.10 "
        "WHERE category = %s "
        "RETURNING product_name, price",
        ("Kitchen",),
    )
    print("Rows changed:", cur.rowcount)
    for name, price in cur:
        print(name, price)
    conn.rollback()

    price = conn.execute(
        "SELECT price FROM products "
        "WHERE product_id = 5"
    ).fetchone()[0]
    print("After rollback:", price)
