# Chapter 43: The Transaction You Didn't Start
import os

import psycopg

DSN = os.environ["DATABASE_URL"]
ADD_DEPT = (
    "INSERT INTO departments "
    "(department_id, department_name) "
    "VALUES (%s, %s)"
)

# Commits when the block ends normally
with psycopg.connect(DSN) as conn:
    conn.execute(ADD_DEPT, (60, "Marketing"))

# Rolls back when an exception leaves it
try:
    with psycopg.connect(DSN) as conn:
        conn.execute(ADD_DEPT, (70, "Support"))
        raise RuntimeError("payment failed")
except RuntimeError as e:
    print("Error:", e)

# Autocommit: each statement is saved at once
with psycopg.connect(DSN,
                     autocommit=True) as conn:
    conn.execute(ADD_DEPT, (80, "Research"))
    with conn.transaction():
        conn.execute(ADD_DEPT, (90, "Training"))
        conn.execute(ADD_DEPT, (95, "Facilities"))

    cur = conn.execute(
        "SELECT department_id, department_name "
        "FROM departments "
        "WHERE department_id >= 60 "
        "ORDER BY department_id"
    )
    for row in cur:
        print(row)
