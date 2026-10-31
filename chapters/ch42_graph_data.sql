-- The Most Helpful SQL Guide, Second Edition
-- Chapter 42: Graph-Shaped Data
--
-- Every example in this chapter that runs on PostgreSQL,
-- in book order, with the result the book prints. Load
-- sample_db.sql first. To run the whole file in psql:
--   psql -d sqlguide -f chapters/ch42_graph_data.sql
-- It runs as one transaction and rolls back at the end, so your
-- database is left unchanged. Examples that change data or fail on
-- purpose are wrapped in a savepoint and undone, as in the book.
-- You can also copy any single example into a query window.

BEGIN;

-- ------------------------------------------------------------
-- Example 1: Nodes and Edges in Tables
-- ------------------------------------------------------------
CREATE TABLE rail_stations (
    station_code VARCHAR(3) PRIMARY KEY,
    station_name VARCHAR(30) NOT NULL
);

CREATE TABLE rail_links (
    from_code VARCHAR(3) NOT NULL
        REFERENCES rail_stations,
    to_code   VARCHAR(3) NOT NULL
        REFERENCES rail_stations,
    minutes   INT NOT NULL CHECK (minutes > 0),
    PRIMARY KEY (from_code, to_code),
    CHECK (from_code <> to_code)
);

CREATE INDEX rail_links_to_idx
    ON rail_links (to_code, from_code);

-- Result: CREATE INDEX

-- ------------------------------------------------------------
-- Example 2: Nodes and Edges in Tables
-- ------------------------------------------------------------
INSERT INTO rail_stations
VALUES ('ASH', 'Ashford'), ('BEX', 'Bexley'),
       ('CAR', 'Carlow'), ('DUN', 'Dunmore'),
       ('ELM', 'Elmhurst'), ('FEN', 'Fenwick');

INSERT INTO rail_links
VALUES ('ASH', 'BEX', 10), ('ASH', 'CAR', 30),
       ('BEX', 'CAR', 15), ('BEX', 'DUN', 40),
       ('CAR', 'DUN', 10), ('CAR', 'ELM', 35),
       ('DUN', 'ELM', 20), ('ELM', 'ASH', 25),
       ('FEN', 'DUN', 5);

-- Result: INSERT 0 9

-- ------------------------------------------------------------
-- Example 3: Nodes and Edges in Tables
-- ------------------------------------------------------------
SELECT l.to_code, s.station_name, l.minutes
FROM rail_links l
JOIN rail_stations s
    ON s.station_code = l.to_code
WHERE l.from_code = 'ASH'
ORDER BY l.minutes;

-- Result:
--  to_code | station_name | minutes
-- ---------+--------------+---------
--  BEX     | Bexley       |      10
--  CAR     | Carlow       |      30
-- (2 rows)

-- ------------------------------------------------------------
-- Example 4: Directed and undirected edges
-- ------------------------------------------------------------
SELECT to_code AS neighbor, minutes
FROM rail_links
WHERE from_code = 'CAR'
UNION ALL
SELECT from_code, minutes
FROM rail_links
WHERE to_code = 'CAR'
ORDER BY neighbor;

-- Result:
--  neighbor | minutes
-- ----------+---------
--  ASH      |      30
--  BEX      |      15
--  DUN      |      10
--  ELM      |      35
-- (4 rows)

-- ------------------------------------------------------------
-- Example 5: Reachability and paths
-- ------------------------------------------------------------
WITH RECURSIVE trips AS (
    SELECT to_code AS station,
           ARRAY[from_code, to_code]::TEXT[]
               AS path,
           minutes AS total_minutes
    FROM rail_links
    WHERE from_code = 'ASH'
    UNION ALL
    SELECT l.to_code,
           t.path || l.to_code,
           t.total_minutes + l.minutes
    FROM trips t
    JOIN rail_links l
        ON l.from_code = t.station
    WHERE l.to_code <> ALL (t.path)
)
SELECT array_to_string(path, '>') AS route,
       total_minutes
FROM trips
ORDER BY station, total_minutes, route;

-- Result:
--         route        | total_minutes
-- ---------------------+---------------
--  ASH>BEX             |            10
--  ASH>BEX>CAR         |            25
--  ASH>CAR             |            30
--  ASH>BEX>CAR>DUN     |            35
--  ASH>CAR>DUN         |            40
--  ASH>BEX>DUN         |            50
--  ASH>BEX>CAR>DUN>ELM |            55
--  ASH>BEX>CAR>ELM     |            60
--  ASH>CAR>DUN>ELM     |            60
--  ASH>CAR>ELM         |            65
--  ASH>BEX>DUN>ELM     |            70
-- (11 rows)

-- ------------------------------------------------------------
-- Example 6: Reachability and paths
-- ------------------------------------------------------------
WITH RECURSIVE trips AS (
    SELECT station_code AS to_code
    FROM rail_stations
    WHERE station_code = 'ASH'
    UNION ALL
    SELECT l.to_code
    FROM trips t
    JOIN rail_links l
        ON l.from_code = t.to_code
) CYCLE to_code SET is_cycle USING visited
SELECT COUNT(*) AS paths,
       COUNT(DISTINCT to_code) AS stations
FROM trips
WHERE NOT is_cycle
    AND to_code <> 'ASH';

-- Result:
--  paths | stations
-- -------+----------
--     11 |        4
-- (1 row)

-- ------------------------------------------------------------
-- Example 7: Reachability and paths
-- ------------------------------------------------------------
WITH RECURSIVE reach AS (
    SELECT 'ASH'::VARCHAR(3) AS station
    UNION
    SELECT l.to_code
    FROM reach r
    JOIN rail_links l
        ON l.from_code = r.station
)
SELECT station
FROM reach
ORDER BY station;

-- Result:
--  station
-- ---------
--  ASH
--  BEX
--  CAR
--  DUN
--  ELM
-- (5 rows)

-- ------------------------------------------------------------
-- Example 8: Hop limits and search order
-- ------------------------------------------------------------
WITH RECURSIVE trips AS (
    SELECT to_code, 1 AS hops
    FROM rail_links
    WHERE from_code = 'ASH'
    UNION ALL
    SELECT l.to_code, t.hops + 1
    FROM trips t
    JOIN rail_links l
        ON l.from_code = t.to_code
    WHERE t.hops < 2
) SEARCH BREADTH FIRST BY to_code SET ord
SELECT to_code, hops
FROM trips
ORDER BY ord;

-- Result:
--  to_code | hops
-- ---------+------
--  BEX     |    1
--  CAR     |    1
--  CAR     |    2
--  DUN     |    2
--  DUN     |    2
--  ELM     |    2
-- (6 rows)

-- ------------------------------------------------------------
-- Example 9: Shortest and cheapest paths
-- ------------------------------------------------------------
WITH RECURSIVE trips AS (
    SELECT to_code AS station,
           ARRAY[from_code, to_code]::TEXT[]
               AS path,
           minutes AS total_minutes
    FROM rail_links
    WHERE from_code = 'ASH'
    UNION ALL
    SELECT l.to_code,
           t.path || l.to_code,
           t.total_minutes + l.minutes
    FROM trips t
    JOIN rail_links l
        ON l.from_code = t.station
    WHERE l.to_code <> ALL (t.path)
        AND cardinality(t.path) < 6
)
SELECT array_to_string(path, '>') AS route,
       cardinality(path) - 1 AS hops,
       total_minutes
FROM trips
WHERE station = 'ELM'
ORDER BY total_minutes, hops, route;

-- Result:
--         route        | hops | total_minutes
-- ---------------------+------+---------------
--  ASH>BEX>CAR>DUN>ELM |    4 |            55
--  ASH>BEX>CAR>ELM     |    3 |            60
--  ASH>CAR>DUN>ELM     |    3 |            60
--  ASH>CAR>ELM         |    2 |            65
--  ASH>BEX>DUN>ELM     |    3 |            70
-- (5 rows)

-- ------------------------------------------------------------
-- Example 10: Graph Questions as Plain SQL
-- ------------------------------------------------------------
CREATE TABLE customer_follows (
    follower_id INT NOT NULL
        REFERENCES customers,
    followed_id INT NOT NULL
        REFERENCES customers,
    PRIMARY KEY (follower_id, followed_id),
    CHECK (follower_id <> followed_id)
);

CREATE INDEX customer_follows_followed_idx
    ON customer_follows (followed_id);

INSERT INTO customer_follows
VALUES (1, 2), (1, 3), (2, 1), (2, 4),
       (3, 4), (4, 5), (5, 3);

-- Result: INSERT 0 7

-- ------------------------------------------------------------
-- Example 11: Degree: the most connected nodes
-- ------------------------------------------------------------
SELECT c.first_name,
       (SELECT COUNT(*)
        FROM customer_follows f
        WHERE f.followed_id = c.customer_id)
           AS followers,
       (SELECT COUNT(*)
        FROM customer_follows f
        WHERE f.follower_id = c.customer_id)
           AS following
FROM customers c
ORDER BY followers DESC, c.first_name;

-- Result:
--  first_name | followers | following
-- ------------+-----------+-----------
--  Charlie    |         2 |         1
--  Dana       |         2 |         1
--  Alice      |         1 |         2
--  Bob        |         1 |         2
--  Ethan      |         1 |         1
-- (5 rows)

-- ------------------------------------------------------------
-- Example 12: Mutual follows and friends of friends
-- ------------------------------------------------------------
SELECT a.follower_id, a.followed_id
FROM customer_follows a
JOIN customer_follows b
    ON b.follower_id = a.followed_id
    AND b.followed_id = a.follower_id
WHERE a.follower_id < a.followed_id
ORDER BY a.follower_id;

-- Result:
--  follower_id | followed_id
-- -------------+-------------
--            1 |           2
-- (1 row)

-- ------------------------------------------------------------
-- Example 13: Mutual follows and friends of friends
-- ------------------------------------------------------------
SELECT c.first_name AS suggestion,
       COUNT(*) AS via_contacts
FROM customer_follows f1
JOIN customer_follows f2
    ON f2.follower_id = f1.followed_id
JOIN customers c
    ON c.customer_id = f2.followed_id
WHERE f1.follower_id = 1
    AND f2.followed_id <> 1
    AND NOT EXISTS (
        SELECT 1
        FROM customer_follows x
        WHERE x.follower_id = 1
            AND x.followed_id = f2.followed_id)
GROUP BY c.first_name
ORDER BY via_contacts DESC, suggestion;

-- Result:
--  suggestion | via_contacts
-- ------------+--------------
--  Dana       |            2
-- (1 row)

-- ------------------------------------------------------------
-- Example 14: Dependencies and impact analysis
-- ------------------------------------------------------------
CREATE TABLE service_deps (
    service_name VARCHAR(20) NOT NULL,
    depends_on   VARCHAR(20) NOT NULL,
    PRIMARY KEY (service_name, depends_on)
);

CREATE INDEX service_deps_on_idx
    ON service_deps (depends_on);

INSERT INTO service_deps
VALUES ('api', 'database'), ('api', 'auth'),
       ('auth', 'database'), ('web', 'api'),
       ('billing', 'api'),
       ('billing', 'payments'),
       ('reports', 'database');

-- Result: INSERT 0 7

-- ------------------------------------------------------------
-- Example 15: Dependencies and impact analysis
-- ------------------------------------------------------------
WITH RECURSIVE impacted AS (
    SELECT service_name
    FROM service_deps
    WHERE depends_on = 'database'
    UNION
    SELECT d.service_name
    FROM service_deps d
    JOIN impacted i
        ON d.depends_on = i.service_name
)
SELECT service_name
FROM impacted
ORDER BY service_name;

-- Result:
--  service_name
-- --------------
--  api
--  auth
--  billing
--  reports
--  web
-- (5 rows)

-- ------------------------------------------------------------
-- Example 16: Dependencies and impact analysis
-- ------------------------------------------------------------
WITH RECURSIVE levels AS (
    SELECT depends_on AS service_name,
           0 AS level
    FROM service_deps
    WHERE depends_on NOT IN (
        SELECT service_name FROM service_deps)
    UNION ALL
    SELECT d.service_name, l.level + 1
    FROM service_deps d
    JOIN levels l
        ON d.depends_on = l.service_name
)
SELECT service_name,
       MAX(level) AS start_order
FROM levels
GROUP BY service_name
ORDER BY start_order, service_name;

-- Result:
--  service_name | start_order
-- --------------+-------------
--  database     |           0
--  payments     |           0
--  auth         |           1
--  reports      |           1
--  api          |           2
--  billing      |           3
--  web          |           3
-- (7 rows)

-- ------------------------------------------------------------
-- Try It 1
-- List every station that can reach Elmhurst, by following the links
-- backwards from it.
-- ------------------------------------------------------------
-- 1. Stations that can reach Elmhurst
WITH RECURSIVE sources AS (
    SELECT 'ELM'::VARCHAR(3) AS station
    UNION
    SELECT l.from_code
    FROM sources s
    JOIN rail_links l
        ON l.to_code = s.station
)
SELECT station
FROM sources
WHERE station <> 'ELM'
ORDER BY station;

-- Result:
--  station
-- ---------
--  ASH
--  BEX
--  CAR
--  DUN
--  FEN
-- (5 rows)

-- ------------------------------------------------------------
-- Try It 2
-- Find the cheapest trip from Bexley to Ashford, with its route and
-- minutes.
-- ------------------------------------------------------------
-- 2. Cheapest trip from Bexley to Ashford
WITH RECURSIVE trips AS (
    SELECT to_code AS station,
           ARRAY[from_code, to_code]::TEXT[]
               AS path,
           minutes AS total_minutes
    FROM rail_links
    WHERE from_code = 'BEX'
    UNION ALL
    SELECT l.to_code,
           t.path || l.to_code,
           t.total_minutes + l.minutes
    FROM trips t
    JOIN rail_links l
        ON l.from_code = t.station
    WHERE l.to_code <> ALL (t.path)
        AND cardinality(t.path) < 6
)
SELECT array_to_string(path, '>') AS route,
       total_minutes
FROM trips
WHERE station = 'ASH'
ORDER BY total_minutes
LIMIT 1;

-- Result:
--         route        | total_minutes
-- ---------------------+---------------
--  BEX>CAR>DUN>ELM>ASH |            70
-- (1 row)

-- ------------------------------------------------------------
-- Try It 3
-- List the services that billing needs to work, directly or
-- indirectly.
-- ------------------------------------------------------------
-- 3. Everything billing depends on
WITH RECURSIVE needs AS (
    SELECT depends_on
    FROM service_deps
    WHERE service_name = 'billing'
    UNION
    SELECT d.depends_on
    FROM service_deps d
    JOIN needs n
        ON d.service_name = n.depends_on
)
SELECT depends_on
FROM needs
ORDER BY depends_on;

-- Result:
--  depends_on
-- ------------
--  api
--  auth
--  database
--  payments
-- (4 rows)

-- ------------------------------------------------------------
-- Example 17: Try It
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

DROP TABLE service_deps, customer_follows,
    rail_links, rail_stations;

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Undo everything this file changed.
-- ------------------------------------------------------------
ROLLBACK;
