# Chapter 43: A Complete Round Trip
import os

import psycopg

DSN = os.environ["DATABASE_URL"]

with psycopg.connect(DSN) as conn:
    with conn.cursor() as cur:
        cur.execute(
            "SELECT product_name, price "
            "FROM products "
            "WHERE category = %s "
            "ORDER BY price DESC",
            ("Electronics",),
        )
        for name, price in cur.fetchall():
            print(name, price)

        cur.execute(
            "UPDATE customers SET city = %s "
            "WHERE customer_id = %s",
            ("Denver", 5),
        )
        print("Rows updated:", cur.rowcount)

    conn.commit()
