# Chapter 43: Fetching Rows (server-side cursor)
import os

import psycopg

DSN = os.environ["DATABASE_URL"]

with psycopg.connect(DSN) as conn:
    with conn.cursor(name="big_result") as cur:
        cur.itersize = 5000
        cur.execute(
            "SELECT n, n * 2 AS doubled "
            "FROM generate_series(1, 1000000) n"
        )
        total = 0
        for n, doubled in cur:
            total += doubled
        print("Rows read:", cur.rownumber)
        print("Sum:", total)
