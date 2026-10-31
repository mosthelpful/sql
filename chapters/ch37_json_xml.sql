-- The Most Helpful SQL Guide, Second Edition
-- Chapter 37: JSON and XML
--
-- Every example in this part of the book that runs on PostgreSQL,
-- in book order, with the result the book prints. Load
-- sample_db.sql first. To run the whole file in psql:
--   psql -d sqlguide -f chapters/ch37_json_xml.sql
-- It runs as one transaction and rolls back at the end, so your
-- database is left unchanged. Examples that change data or fail on
-- purpose are wrapped in a savepoint and undone, as in the book.
-- You can also copy any single example into a query window.

BEGIN;

-- ------------------------------------------------------------
-- Example 1: The JSON and JSONB Types
-- ------------------------------------------------------------
SELECT '{"b": 1, "a": 2, "a": 3}'::JSON
           AS as_json,
       '{"b": 1, "a": 2, "a": 3}'::JSONB
           AS as_jsonb;

-- Result:
--          as_json          |     as_jsonb
-- --------------------------+------------------
--  {"b": 1, "a": 2, "a": 3} | {"a": 3, "b": 1}
-- (1 row)

-- ------------------------------------------------------------
-- Example 2: Storing JSON in a Table
-- Sets up data for the examples that follow.
-- ------------------------------------------------------------
CREATE TABLE product_attributes (
    product_id INT PRIMARY KEY
        REFERENCES products (product_id),
    attributes JSONB NOT NULL
        CHECK (attributes IS JSON OBJECT)
);

INSERT INTO product_attributes
    (product_id, attributes)
VALUES
    (1, '{"color": "silver", "ram_gb": 16,
          "ports": ["usb-c", "hdmi"],
          "screen": {"size_in": 14,
                     "panel": "IPS"}}'),
    (2, '{"color": "black", "storage_gb": 128,
          "ports": ["usb-c"],
          "screen": {"size_in": 6.1,
                     "panel": "OLED"}}'),
    (3, '{"color": "silver", "storage_gb": 64,
          "ports": ["usb-c"],
          "screen": {"size_in": 11,
                     "panel": "IPS"}}'),
    (4, '{"color": "black",
          "ports": ["hdmi", "displayport"],
          "screen": {"size_in": 27,
                     "panel": "IPS"}}'),
    (5, '{"color": "white", "capacity_ml": 350,
          "dishwasher_safe": true}'),
    (6, '{"color": "black", "adjustable": true,
          "warranty_years": 5}');

-- ------------------------------------------------------------
-- Example 3: Storing JSON in a Table
-- Fails on purpose, to show the error.
-- ------------------------------------------------------------
SAVEPOINT example;

INSERT INTO product_attributes
    (product_id, attributes)
VALUES (7, '["usb-c", "hdmi"]');

ROLLBACK TO SAVEPOINT example;

-- Expected error:
--   ERROR:  new row for relation "product_attributes" violates check constraint "product_attributes_attributes_check"
--   DETAIL:  Failing row contains (7, ["usb-c", "hdmi"]).

-- ------------------------------------------------------------
-- Example 4: Reading Values
-- ------------------------------------------------------------
SELECT p.product_name,
       a.attributes ->> 'color' AS color,
       a.attributes #>> '{screen,size_in}'
           AS screen_in,
       a.attributes -> 'ports' ->> 0
           AS first_port
FROM product_attributes a
JOIN products p
    ON p.product_id = a.product_id
ORDER BY p.product_id;

-- Result:
--  product_name | color  | screen_in | first_port
-- --------------+--------+-----------+------------
--  Laptop       | silver |        14 | usb-c
--  Smartphone   | black  |       6.1 | usb-c
--  Tablet       | silver |        11 | usb-c
--  Monitor      | black  |        27 | hdmi
--  Coffee Mug   | white  |      NULL | NULL
--  Desk Chair   | black  |      NULL | NULL
-- (6 rows)

-- ------------------------------------------------------------
-- Example 5: Reading Values
-- ------------------------------------------------------------
SELECT p.product_name,
       a.attributes ->> 'storage_gb' AS storage_gb
FROM product_attributes a
JOIN products p
    ON p.product_id = a.product_id
WHERE a.attributes ->> 'storage_gb' >= '100'
ORDER BY p.product_id;

-- Result:
--  product_name | storage_gb
-- --------------+------------
--  Smartphone   |        128
--  Tablet       |         64
-- (2 rows)

-- ------------------------------------------------------------
-- Example 6: Searching with @> and ?
-- ------------------------------------------------------------
SELECT p.product_name
FROM product_attributes a
JOIN products p
    ON p.product_id = a.product_id
WHERE a.attributes @> '{"color": "black"}'
ORDER BY p.product_id;

-- Result:
--  product_name
-- --------------
--  Smartphone
--  Monitor
--  Desk Chair
-- (3 rows)

-- ------------------------------------------------------------
-- Example 7: Searching with @> and ?
-- ------------------------------------------------------------
SELECT p.product_name
FROM product_attributes a
JOIN products p
    ON p.product_id = a.product_id
WHERE a.attributes ? 'storage_gb'
ORDER BY p.product_id;

-- Result:
--  product_name
-- --------------
--  Smartphone
--  Tablet
-- (2 rows)

-- ------------------------------------------------------------
-- Example 8: Indexing JSONB
-- ------------------------------------------------------------
CREATE TABLE web_events (
    event_id INT PRIMARY KEY,
    payload  JSONB NOT NULL
);

INSERT INTO web_events (event_id, payload)
SELECT n,
       jsonb_build_object(
           'customer_id', n % 2000 + 1,
           'type',
           (ARRAY['view', 'search', 'cart',
                  'purchase'])[n % 4 + 1])
FROM generate_series(1, 20000) n;

ANALYZE web_events;

EXPLAIN (COSTS OFF)
SELECT event_id
FROM web_events
WHERE payload @> '{"customer_id": 42}';

-- Plan:
--   Seq Scan on web_events
--     Filter: (payload @> '{"customer_id": 42}'::jsonb)

-- ------------------------------------------------------------
-- Example 9: Indexing JSONB
-- ------------------------------------------------------------
CREATE INDEX idx_web_events_payload
    ON web_events USING GIN (payload);

EXPLAIN (COSTS OFF)
SELECT event_id
FROM web_events
WHERE payload @> '{"customer_id": 42}';

-- Plan:
--   Bitmap Heap Scan on web_events
--     Recheck Cond: (payload @> '{"customer_id": 42}'::jsonb)
--     ->  Bitmap Index Scan on idx_web_events_payload
--           Index Cond: (payload @> '{"customer_id": 42}'::jsonb)

-- ------------------------------------------------------------
-- Example 10: Indexing JSONB
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

CREATE INDEX idx_web_events_customer
    ON web_events ((payload ->> 'customer_id'));

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Example 11: Building JSON from Tables
-- ------------------------------------------------------------
SELECT jsonb_build_object(
           'order_id', o.order_id,
           'customer', c.first_name,
           'items', jsonb_agg(
               jsonb_build_object(
                   'product', p.product_name,
                   'qty', oi.quantity)
               ORDER BY p.product_id)
       ) AS order_doc
FROM orders o
JOIN customers c
    ON c.customer_id = o.customer_id
JOIN order_items oi
    ON oi.order_id = o.order_id
JOIN products p
    ON p.product_id = oi.product_id
WHERE o.customer_id = 1
GROUP BY o.order_id, c.first_name
ORDER BY o.order_id;

-- Result:
--                                                         order_doc
-- -------------------------------------------------------------------------------------------------------------------------
--  {"items": [{"qty": 1, "product": "Laptop"}, {"qty": 2, "product": "Coffee Mug"}], "customer": "Alice", "order_id": 101}
--  {"items": [{"qty": 1, "product": "Laptop"}, {"qty": 2, "product": "Monitor"}], "customer": "Alice", "order_id": 104}
-- (2 rows)

-- ------------------------------------------------------------
-- Example 12: Building JSON from Tables
-- ------------------------------------------------------------
SELECT d.department_name,
       JSON_ARRAYAGG(e.first_name
                     ORDER BY e.employee_id
                     RETURNING JSONB)
           AS employees
FROM departments d
JOIN employees e
    ON e.department_id = d.department_id
GROUP BY d.department_id, d.department_name
ORDER BY d.department_id;

-- Result:
--  department_name |           employees
-- -----------------+-------------------------------
--  Executive       | ["John"]
--  Finance         | ["Jane", "David"]
--  Engineering     | ["Emily", "Michael", "Sarah"]
--  Sales           | ["Priya"]
-- (4 rows)

-- ------------------------------------------------------------
-- Example 13: Turning JSON into Rows
-- ------------------------------------------------------------
SELECT p.product_name, t.port
FROM product_attributes a
JOIN products p
    ON p.product_id = a.product_id
CROSS JOIN LATERAL
    jsonb_array_elements_text(
        a.attributes -> 'ports') t(port)
ORDER BY p.product_id, t.port;

-- Result:
--  product_name |    port
-- --------------+-------------
--  Laptop       | hdmi
--  Laptop       | usb-c
--  Smartphone   | usb-c
--  Tablet       | usb-c
--  Monitor      | displayport
--  Monitor      | hdmi
-- (6 rows)

-- ------------------------------------------------------------
-- Example 14: Turning JSON into Rows
-- ------------------------------------------------------------
SELECT r.product_id, p.product_name,
       r.quantity,
       p.price * r.quantity AS line_total
FROM jsonb_to_recordset(
         '[{"product_id": 2, "quantity": 1},
           {"product_id": 5, "quantity": 3}]'
     ) r(product_id INT, quantity INT)
JOIN products p
    ON p.product_id = r.product_id
ORDER BY r.product_id;

-- Result:
--  product_id | product_name | quantity | line_total
-- ------------+--------------+----------+------------
--           2 | Smartphone   |        1 |     800.00
--           5 | Coffee Mug   |        3 |      32.97
-- (2 rows)

-- ------------------------------------------------------------
-- Example 15: SQL/JSON Path
-- ------------------------------------------------------------
SELECT p.product_name,
       a.attributes #>> '{screen,size_in}'
           AS screen_in
FROM product_attributes a
JOIN products p
    ON p.product_id = a.product_id
WHERE jsonb_path_exists(a.attributes,
          '$.screen.size_in ? (@ > 10)')
ORDER BY p.product_id;

-- Result:
--  product_name | screen_in
-- --------------+-----------
--  Laptop       |        14
--  Tablet       |        11
--  Monitor      |        27
-- (3 rows)

-- ------------------------------------------------------------
-- Example 16: SQL/JSON Path
-- ------------------------------------------------------------
SELECT a.product_id,
       jsonb_path_query(a.attributes,
           '$.ports[*] ? (@ <> "usb-c")')
           AS port
FROM product_attributes a
ORDER BY a.product_id, port;

-- Result:
--  product_id |     port
-- ------------+---------------
--           1 | "hdmi"
--           4 | "displayport"
--           4 | "hdmi"
-- (3 rows)

-- ------------------------------------------------------------
-- Example 17: Changing JSON
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

UPDATE product_attributes
SET attributes =
        jsonb_set(attributes,
                  '{screen,size_in}', '15')
        || '{"ram_gb": 32}'
WHERE product_id = 1;

SELECT attributes
FROM product_attributes
WHERE product_id = 1;

ROLLBACK TO SAVEPOINT example;

-- Result:
--                                                 attributes
-- ----------------------------------------------------------------------------------------------------------
--  {"color": "silver", "ports": ["usb-c", "hdmi"], "ram_gb": 32, "screen": {"panel": "IPS", "size_in": 15}}
-- (1 row)

-- ------------------------------------------------------------
-- Example 18: XML
-- ------------------------------------------------------------
CREATE TEMPORARY TABLE price_feed (feed XML);

INSERT INTO price_feed (feed)
VALUES ('<prices>
           <product id="1">
             <price>1150.00</price>
           </product>
           <product id="4">
             <price>289.00</price>
           </product>
         </prices>');

SELECT xpath('/prices/product/@id', feed)
           AS ids
FROM price_feed;

-- Result:
--   ids
-- -------
--  {1,4}
-- (1 row)

-- ------------------------------------------------------------
-- Example 19: XML
-- ------------------------------------------------------------
SELECT x.product_id, p.product_name,
       p.price AS old_price, x.new_price
FROM price_feed f
CROSS JOIN XMLTABLE(
         '/prices/product' PASSING f.feed
         COLUMNS
             product_id INT PATH '@id',
             new_price DECIMAL(10, 2)
                 PATH 'price'
     ) x
JOIN products p
    ON p.product_id = x.product_id
ORDER BY x.product_id;

-- Result:
--  product_id | product_name | old_price | new_price
-- ------------+--------------+-----------+-----------
--           1 | Laptop       |   1200.00 |   1150.00
--           4 | Monitor      |    300.00 |    289.00
-- (2 rows)

-- ------------------------------------------------------------
-- Example 20: XML
-- ------------------------------------------------------------
SELECT XMLELEMENT(
           NAME department,
           XMLATTRIBUTES(d.department_name
                         AS name),
           XMLAGG(XMLELEMENT(NAME employee,
                             e.first_name)
                  ORDER BY e.employee_id)
       ) AS dept_xml
FROM departments d
JOIN employees e
    ON e.department_id = d.department_id
WHERE d.department_id = 30
GROUP BY d.department_id, d.department_name;

-- Result:
--                                                            dept_xml
-- ------------------------------------------------------------------------------------------------------------------------------
--  <department name="Engineering"><employee>Emily</employee><employee>Michael</employee><employee>Sarah</employee></department>
-- (1 row)

-- ------------------------------------------------------------
-- Try It 1
-- List the products with an IPS screen, and their screen sizes.
-- ------------------------------------------------------------
-- 1. Products with an IPS screen
SELECT p.product_name,
       a.attributes #>> '{screen,size_in}'
           AS screen_in
FROM product_attributes a
JOIN products p
    ON p.product_id = a.product_id
WHERE a.attributes
      @> '{"screen": {"panel": "IPS"}}'
ORDER BY p.product_id;

-- Result:
--  product_name | screen_in
-- --------------+-----------
--  Laptop       |        14
--  Tablet       |        11
--  Monitor      |        27
-- (3 rows)

-- ------------------------------------------------------------
-- Try It 2
-- Build one JSON object per customer who has ordered, with the
-- customer's first name and an array of their order IDs.
-- ------------------------------------------------------------
-- 2. Each customer's order IDs as JSON
SELECT jsonb_build_object(
           'customer', c.first_name,
           'orders', jsonb_agg(o.order_id
                         ORDER BY o.order_id)
       ) AS customer_doc
FROM customers c
JOIN orders o
    ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name
ORDER BY c.customer_id;

-- Result:
--                  customer_doc
-- -----------------------------------------------
--  {"orders": [101, 104], "customer": "Alice"}
--  {"orders": [102], "customer": "Bob"}
--  {"orders": [103, 106], "customer": "Charlie"}
--  {"orders": [105], "customer": "Dana"}
-- (4 rows)

-- ------------------------------------------------------------
-- Try It 3
-- A stock count arrives as [{"product_id": 3, "stock": 30},
-- {"product_id": 6, "stock": 12}]. Update products from it, then
-- list every product's stock.
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 3. Update stock from a JSON array
UPDATE products p
SET stock = r.stock
FROM jsonb_to_recordset(
         '[{"product_id": 3, "stock": 30},
           {"product_id": 6, "stock": 12}]'
     ) r(product_id INT, stock INT)
WHERE p.product_id = r.product_id;

SELECT product_id, product_name, stock
FROM products
ORDER BY product_id;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  product_id | product_name | stock
-- ------------+--------------+-------
--           1 | Laptop       |    15
--           2 | Smartphone   |    40
--           3 | Tablet       |    30
--           4 | Monitor      |    30
--           5 | Coffee Mug   |   100
--           6 | Desk Chair   |    12
-- (6 rows)

-- ------------------------------------------------------------
-- Example 21: Try It
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

DROP TABLE IF EXISTS product_attributes,
    web_events;

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Undo everything this file changed.
-- ------------------------------------------------------------
ROLLBACK;
