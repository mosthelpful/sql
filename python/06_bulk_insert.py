# Chapter 43: Inserting Many Rows
import os

import psycopg

DSN = os.environ["DATABASE_URL"]

with psycopg.connect(DSN) as conn:
    conn.execute(
        "CREATE TEMPORARY TABLE stock_scans ("
        " product_id INT NOT NULL,"
        " quantity   INT NOT NULL)"
    )
    with conn.cursor() as cur:
        # executemany: one statement, many rows
        scans = [(1, 2), (5, 12), (6, 1)]
        cur.executemany(
            "INSERT INTO stock_scans "
            "(product_id, quantity) "
            "VALUES (%s, %s)",
            scans,
        )
        print("executemany rows:", cur.rowcount)

        # COPY: stream rows in bulk
        with cur.copy(
            "COPY stock_scans "
            "(product_id, quantity) FROM STDIN"
        ) as copy:
            for i in range(100_000):
                copy.write_row((i % 6 + 1, 1))
        print("COPY rows:", cur.rowcount)

        cur.execute(
            "SELECT COUNT(*), SUM(quantity) "
            "FROM stock_scans"
        )
        print("Table now holds:", cur.fetchone())
