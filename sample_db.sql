-- The Most Helpful SQL Guide, 2nd Edition
-- Sample database (PostgreSQL). Appendix D has
-- notes for MySQL, SQL Server and Oracle.
-- Running it again resets the data.

DROP TABLE IF EXISTS order_items, orders,
    projects, employees, departments,
    customers, products CASCADE;

CREATE TABLE departments (
    department_id   INT PRIMARY KEY,
    department_name VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE employees (
    employee_id   INT PRIMARY KEY,
    first_name    VARCHAR(50)  NOT NULL,
    last_name     VARCHAR(50)  NOT NULL,
    email         VARCHAR(100) NOT NULL UNIQUE,
    job_title     VARCHAR(50)  NOT NULL,
    department_id INT
        REFERENCES departments (department_id),
    manager_id    INT
        REFERENCES employees (employee_id),
    hire_date     DATE NOT NULL,
    salary        DECIMAL(10, 2) NOT NULL
        CHECK (salary > 0)
);

CREATE TABLE customers (
    customer_id INT PRIMARY KEY,
    first_name  VARCHAR(50)  NOT NULL,
    last_name   VARCHAR(50)  NOT NULL,
    email       VARCHAR(100) NOT NULL UNIQUE,
    city        VARCHAR(50),
    status      VARCHAR(10)  NOT NULL
        CHECK (status IN ('active', 'inactive')),
    created_on  DATE NOT NULL
);

CREATE TABLE products (
    product_id   INT PRIMARY KEY,
    product_name VARCHAR(50)    NOT NULL,
    category     VARCHAR(30)    NOT NULL,
    price        DECIMAL(10, 2) NOT NULL
        CHECK (price >= 0),
    stock        INT            NOT NULL
        CHECK (stock >= 0)
);

CREATE TABLE orders (
    order_id    INT PRIMARY KEY,
    customer_id INT  NOT NULL
        REFERENCES customers (customer_id),
    order_date  DATE NOT NULL,
    status      VARCHAR(12) NOT NULL
        CHECK (status IN ('processing',
                          'shipped',
                          'cancelled'))
);

CREATE TABLE order_items (
    order_id   INT NOT NULL
        REFERENCES orders (order_id),
    product_id INT NOT NULL
        REFERENCES products (product_id),
    quantity   INT NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(10, 2) NOT NULL,
    PRIMARY KEY (order_id, product_id)
);

CREATE TABLE projects (
    project_id    INT PRIMARY KEY,
    project_name  VARCHAR(50) NOT NULL,
    department_id INT NOT NULL
        REFERENCES departments (department_id),
    budget        DECIMAL(12, 2) NOT NULL
);

INSERT INTO departments
    (department_id, department_name)
VALUES
    (10, 'Executive'),
    (20, 'Finance'),
    (30, 'Engineering'),
    (40, 'Sales'),
    (50, 'Legal');

INSERT INTO employees
    (employee_id, first_name, last_name, email,
     job_title, department_id, manager_id,
     hire_date, salary)
VALUES
    (1, 'John', 'Doe', 'john.doe@example.com',
     'Managing Director', 10, NULL,
     '2015-06-15', 150000),
    (2, 'Jane', 'Smith',
     'jane.smith@example.com',
     'Finance Manager', 20, 1,
     '2016-09-23', 88000),
    (3, 'Emily', 'Johnson',
     'emily.johnson@example.com',
     'Engineering Manager', 30, 1,
     '2017-03-11', 105000),
    (4, 'Michael', 'Williams',
     'michael.w@example.com',
     'Software Engineer', 30, 3,
     '2018-05-29', 92000),
    (5, 'Sarah', 'Chen',
     'sarah.chen@example.com',
     'Software Engineer', 30, 3,
     '2020-02-03', 92000),
    (6, 'David', 'Brown',
     'david.brown@example.com',
     'Accountant', 20, 2,
     '2019-11-12', 67000),
    (7, 'Priya', 'Patel',
     'priya.patel@example.com',
     'Sales Representative', 40, 1,
     '2021-08-30', 58000),
    (8, 'Tom', 'Wilson',
     'tom.wilson@example.com',
     'Data Analyst', NULL, 3,
     '2024-01-08', 71000);

INSERT INTO customers
    (customer_id, first_name, last_name, email,
     city, status, created_on)
VALUES
    (1, 'Alice', 'Brown', 'alice@example.com',
     'New York', 'active', '2020-01-15'),
    (2, 'Bob', 'Davis', 'bob@example.com',
     'Chicago', 'inactive', '2019-08-09'),
    (3, 'Charlie', 'Evans', 'charlie@example.com',
     'New York', 'active', '2021-07-19'),
    (4, 'Dana', 'Kim', 'dana@example.com',
     'Austin', 'active', '2023-03-02'),
    (5, 'Ethan', 'Ruiz', 'ethan@example.com',
     NULL, 'active', '2024-05-20');

INSERT INTO products
    (product_id, product_name, category, price,
     stock)
VALUES
    (1, 'Laptop', 'Electronics', 1200.00, 15),
    (2, 'Smartphone', 'Electronics', 800.00, 40),
    (3, 'Tablet', 'Electronics', 450.00, 25),
    (4, 'Monitor', 'Electronics', 300.00, 30),
    (5, 'Coffee Mug', 'Kitchen', 10.99, 100),
    (6, 'Desk Chair', 'Furniture', 249.00, 8);

INSERT INTO orders
    (order_id, customer_id, order_date, status)
VALUES
    (101, 1, '2024-01-15', 'shipped'),
    (102, 2, '2024-01-16', 'shipped'),
    (103, 3, '2024-01-17', 'cancelled'),
    (104, 1, '2024-02-03', 'shipped'),
    (105, 4, '2024-02-10', 'processing'),
    (106, 3, '2024-03-05', 'shipped');

INSERT INTO order_items
    (order_id, product_id, quantity, unit_price)
VALUES
    (101, 1, 1, 1200.00),
    (101, 5, 2, 10.99),
    (102, 2, 1, 800.00),
    (103, 3, 2, 450.00),
    (104, 1, 1, 1200.00),
    (104, 4, 2, 300.00),
    (105, 6, 1, 249.00),
    (105, 5, 4, 10.99),
    (106, 2, 1, 800.00),
    (106, 4, 1, 300.00);

INSERT INTO projects
    (project_id, project_name, department_id,
     budget)
VALUES
    (1, 'Payroll Upgrade', 20, 50000),
    (2, 'Mobile App', 30, 75000),
    (3, 'Data Platform', 30, 60000),
    (4, 'Brand Refresh', 40, 45000);
