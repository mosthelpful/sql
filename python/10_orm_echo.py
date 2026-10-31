# Chapter 43: ORMs, Briefly
from sqlalchemy import select
from sqlalchemy.orm import Session

from orm_models import Customer, make_engine

engine = make_engine(echo=True)

with Session(engine) as session:
    stmt = (
        select(Customer)
        .where(Customer.city == "New York")
        .order_by(Customer.customer_id)
    )
    for c in session.scalars(stmt):
        print(c.customer_id, c.first_name)
