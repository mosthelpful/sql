# Chapter 43: ORMs, Briefly (the N+1 problem)
from sqlalchemy import event, select
from sqlalchemy.orm import (Session, joinedload,
                            selectinload)

from orm_models import Customer, make_engine

engine = make_engine()
statements = []


@event.listens_for(engine,
                   "before_cursor_execute")
def log_sql(conn, cursor, sql, *args):
    statements.append(sql)


def order_counts(*options):
    statements.clear()
    with Session(engine) as session:
        stmt = (
            select(Customer)
            .options(*options)
            .order_by(Customer.customer_id)
        )
        rows = session.scalars(stmt).unique()
        counts = [
            f"{c.first_name} {len(c.orders)}"
            for c in rows
        ]
    return ", ".join(counts), len(statements)


counts, n = order_counts()
print(counts)
print("Lazy loading:", n, "statements")

counts, n = order_counts(
    selectinload(Customer.orders))
print("selectinload:", n, "statements")

counts, n = order_counts(
    joinedload(Customer.orders))
print("joinedload:  ", n, "statement")
