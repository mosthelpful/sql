# Chapter 43: ORMs (models used by 10 and 11)
import os

from sqlalchemy import ForeignKey, create_engine
from sqlalchemy.orm import (
    DeclarativeBase, Mapped, mapped_column,
    relationship)


class Base(DeclarativeBase):
    pass


class Customer(Base):
    __tablename__ = "customers"
    customer_id: Mapped[int] = mapped_column(
        primary_key=True)
    first_name: Mapped[str]
    city: Mapped[str | None]
    orders: Mapped[list["Order"]] = relationship(
        order_by="Order.order_id")


class Order(Base):
    __tablename__ = "orders"
    order_id: Mapped[int] = mapped_column(
        primary_key=True)
    customer_id: Mapped[int] = mapped_column(
        ForeignKey("customers.customer_id"))
    status: Mapped[str]


def make_engine(echo=False):
    url = os.environ["DATABASE_URL"]
    url = url.replace("postgresql://",
                      "postgresql+psycopg://", 1)
    return create_engine(url, echo=echo)
