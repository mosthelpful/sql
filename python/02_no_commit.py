# Chapter 43: The Transaction You Didn't Start
import os

import psycopg

DSN = os.environ["DATABASE_URL"]

conn = psycopg.connect(DSN)
conn.execute(
    "INSERT INTO departments "
    "(department_id, department_name) "
    "VALUES (%s, %s)",
    (60, "Marketing"),
)
print(conn.info.transaction_status.name)
conn.close()  # no commit()

with psycopg.connect(DSN) as conn:
    row = conn.execute(
        "SELECT COUNT(*) FROM departments "
        "WHERE department_id = 60"
    ).fetchone()
    print("Marketing rows:", row[0])
