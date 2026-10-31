# Chapter 43: Try It, answer 1
# 1. dict_row, and a parameter for the ID
import os

import psycopg
from psycopg.rows import dict_row

DSN = os.environ["DATABASE_URL"]


def customer_orders(conn, customer_id):
    cur = conn.cursor(row_factory=dict_row)
    cur.execute(
        "SELECT o.order_id, o.status, "
        "       SUM(oi.quantity * oi.unit_price)"
        "           AS total "
        "FROM orders o "
        "JOIN order_items oi "
        "    ON oi.order_id = o.order_id "
        "WHERE o.customer_id = %s "
        "GROUP BY o.order_id, o.status "
        "ORDER BY o.order_id",
        (customer_id,),
    )
    return cur.fetchall()


with psycopg.connect(DSN) as conn:
    for order in customer_orders(conn, 3):
        print(order["order_id"], order["status"],
              order["total"])
