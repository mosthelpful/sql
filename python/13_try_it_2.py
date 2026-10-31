# Chapter 43: Try It, answer 2
# 2. Inside an open transaction, each
#    conn.transaction() block is a savepoint
import os

import psycopg
from psycopg import errors

DSN = os.environ["DATABASE_URL"]


def add_department(conn, dept_id, name):
    sql = ("INSERT INTO departments "
           "(department_id, department_name) "
           "VALUES (%s, %s)")
    try:
        with conn.transaction():
            conn.execute(sql, (dept_id, name))
    except errors.UniqueViolation as e:
        if "name" in e.diag.constraint_name:
            return f"{name} already exists"
        return f"ID {dept_id} is taken"
    return f"Added {name}"


with psycopg.connect(DSN) as conn:
    with conn.transaction():  # the outer one
        for args in [(60, "Marketing"),
                     (70, "Finance"),
                     (20, "Support")]:
            print(add_department(conn, *args))
