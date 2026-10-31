# Chapter 43: Handling Errors
import os

import psycopg
from psycopg import errors

DSN = os.environ["DATABASE_URL"]
ADD_DEPT = (
    "INSERT INTO departments "
    "(department_id, department_name) "
    "VALUES (%s, %s)"
)

with psycopg.connect(DSN) as conn:
    try:
        conn.execute(ADD_DEPT, (60, "Finance"))
    except errors.UniqueViolation as e:
        diag = e.diag
        print("SQLSTATE:  ", e.sqlstate)
        print("Constraint:", diag.constraint_name)
        print(diag.message_detail)

    try:
        conn.execute("SELECT 1")
    except psycopg.Error as e:
        print(type(e).__name__, e.sqlstate)

    conn.rollback()
    row = conn.execute(
        "SELECT COUNT(*) FROM orders"
    ).fetchone()
    print("After rollback:", row[0])
