-- The Most Helpful SQL Guide, Second Edition
-- Chapter 41: Vector Search for AI Applications
--
-- Every example in this chapter that runs on PostgreSQL,
-- in book order, with the result the book prints. Load
-- sample_db.sql first. To run the whole file in psql:
--   psql -d sqlguide -f chapters/ch41_vector_search.sql
-- It runs as one transaction and rolls back at the end, so your
-- database is left unchanged. Examples that change data or fail on
-- purpose are wrapped in a savepoint and undone, as in the book.
-- You can also copy any single example into a query window.

BEGIN;

-- ------------------------------------------------------------
-- Example 1: Storing Vectors
-- ------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS vector;

-- Result: CREATE EXTENSION

-- ------------------------------------------------------------
-- Example 2: Storing Vectors
-- ------------------------------------------------------------
CREATE TABLE product_embeddings (
    product_id      INT PRIMARY KEY
        REFERENCES products (product_id),
    embedding_model VARCHAR(50) NOT NULL,
    embedding       VECTOR(3) NOT NULL
);

INSERT INTO product_embeddings
    (product_id, embedding_model, embedding)
VALUES
    (1, 'handmade-v1', '[0.9, 0.7, 0.6]'),
    (2, 'handmade-v1', '[0.9, 1.0, 0.1]'),
    (3, 'handmade-v1', '[0.8, 0.8, 0.3]'),
    (4, 'handmade-v1', '[0.9, 0.1, 0.9]'),
    (5, 'handmade-v1', '[0.0, 0.4, 0.6]'),
    (6, 'handmade-v1', '[0.0, 0.0, 1.0]');

-- Result: INSERT 0 6

-- ------------------------------------------------------------
-- Example 3: Storing Vectors
-- Fails on purpose, to show the error.
-- ------------------------------------------------------------
SAVEPOINT example;

INSERT INTO product_embeddings
    (product_id, embedding_model, embedding)
VALUES (1, 'handmade-v1', '[0.9, 0.7]');

ROLLBACK TO SAVEPOINT example;

-- Expected error:
--   ERROR:  expected 3 dimensions, not 2

-- ------------------------------------------------------------
-- Example 4: Storing Vectors
-- ------------------------------------------------------------
SELECT
    '[0.123456789,1000.5]'::vector AS full_vec,
    '[0.123456789,1000.5]'::halfvec AS half_vec;

-- Result:
--       full_vec       |      half_vec
-- ---------------------+---------------------
--  [0.12345679,1000.5] | [0.12347412,1000.5]
-- (1 row)

-- ------------------------------------------------------------
-- Example 5: Finding the Nearest Rows
-- ------------------------------------------------------------
SELECT p.product_name,
       ROUND((pe.embedding <=> '[0.1, 0.0, 0.9]')
             ::numeric, 3) AS distance
FROM product_embeddings pe
JOIN products p
    ON p.product_id = pe.product_id
ORDER BY pe.embedding <=> '[0.1, 0.0, 0.9]'
LIMIT 3;

-- Result:
--  product_name | distance
-- --------------+----------
--  Desk Chair   |    0.006
--  Coffee Mug   |    0.173
--  Monitor      |    0.222
-- (3 rows)

-- ------------------------------------------------------------
-- Example 6: Measuring Distance
-- ------------------------------------------------------------
SELECT p.product_name,
       ROUND((pe.embedding <=> v.q)::numeric, 3)
           AS cosine,
       ROUND((pe.embedding <-> v.q)::numeric, 3)
           AS euclidean,
       ROUND((pe.embedding <#> v.q)::numeric, 3)
           AS neg_inner
FROM product_embeddings pe
JOIN products p
    ON p.product_id = pe.product_id
CROSS JOIN (SELECT '[0.4, 0.5, 0.0]'::vector
                AS q) v
ORDER BY cosine, p.product_name;

-- Result:
--  product_name | cosine | euclidean | neg_inner
-- --------------+--------+-----------+-----------
--  Smartphone   |  0.004 |     0.714 |    -0.860
--  Tablet       |  0.039 |     0.583 |    -0.720
--  Laptop       |  0.139 |     0.806 |    -0.710
--  Monitor      |  0.498 |     1.105 |    -0.410
--  Coffee Mug   |  0.567 |     0.728 |    -0.200
--  Desk Chair   |  1.000 |     1.187 |     0.000
-- (6 rows)

-- ------------------------------------------------------------
-- Example 7: A larger table
-- ------------------------------------------------------------
CREATE TABLE vec_items (
    item_id   INT PRIMARY KEY,
    category  VARCHAR(10) NOT NULL,
    embedding VECTOR(3) NOT NULL
);

INSERT INTO vec_items
    (item_id, category, embedding)
SELECT n,
       (ARRAY['books', 'games', 'garden',
              'kitchen', 'music', 'office',
              'outdoor', 'pets', 'tools',
              'toys'])[n % 10 + 1],
       ARRAY[SIN(n), COS(n * 1.3),
             SIN(n * 0.7)]::vector(3)
FROM generate_series(1, 5000) n;

ANALYZE vec_items;

EXPLAIN (COSTS OFF)
SELECT item_id
FROM vec_items
ORDER BY embedding <=> '[0.5, 0.5, 0.5]'
LIMIT 5;

-- Plan:
--   Limit
--     ->  Sort
--           Sort Key: ((embedding <=> '[0.5,0.5,0.5]'::vector))
--           ->  Seq Scan on vec_items

-- ------------------------------------------------------------
-- Example 8: HNSW
-- ------------------------------------------------------------
CREATE INDEX idx_vec_items_hnsw
    ON vec_items
    USING hnsw (embedding vector_cosine_ops);

EXPLAIN (COSTS OFF)
SELECT item_id
FROM vec_items
ORDER BY embedding <=> '[0.5, 0.5, 0.5]'
LIMIT 5;

-- Plan:
--   Limit
--     ->  Index Scan using idx_vec_items_hnsw on vec_items
--           Order By: (embedding <=> '[0.5,0.5,0.5]'::vector)

-- ------------------------------------------------------------
-- Example 9: HNSW
-- ------------------------------------------------------------
EXPLAIN (COSTS OFF)
SELECT item_id
FROM vec_items
ORDER BY embedding <-> '[0.5, 0.5, 0.5]'
LIMIT 5;

-- Plan:
--   Limit
--     ->  Sort
--           Sort Key: ((embedding <-> '[0.5,0.5,0.5]'::vector))
--           ->  Seq Scan on vec_items

-- ------------------------------------------------------------
-- Example 10: IVFFlat
-- ------------------------------------------------------------
CREATE INDEX idx_vec_items_ivf
    ON vec_items
    USING ivfflat (embedding vector_l2_ops)
    WITH (lists = 5);

EXPLAIN (COSTS OFF)
SELECT item_id
FROM vec_items
ORDER BY embedding <-> '[0.5, 0.5, 0.5]'
LIMIT 5;

-- Plan:
--   Limit
--     ->  Index Scan using idx_vec_items_ivf on vec_items
--           Order By: (embedding <-> '[0.5,0.5,0.5]'::vector)

-- ------------------------------------------------------------
-- Example 11: Choosing and tuning
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

SET hnsw.ef_search = 100;
SET ivfflat.probes = 3;

RESET hnsw.ef_search;
RESET ivfflat.probes;

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Example 12: Filtering Vector Searches
-- ------------------------------------------------------------
SELECT COUNT(*) AS rows_returned
FROM (
    SELECT item_id
    FROM vec_items
    WHERE category = 'kitchen'
    ORDER BY embedding <=> '[0.5, 0.5, 0.5]'
    LIMIT 10
) nearest;

-- Result:
--  rows_returned
-- ---------------
--              5
-- (1 row)

-- ------------------------------------------------------------
-- Example 13: Iterative index scans
-- ------------------------------------------------------------
SET hnsw.iterative_scan = relaxed_order;

SELECT COUNT(*) AS rows_returned
FROM (
    SELECT item_id
    FROM vec_items
    WHERE category = 'kitchen'
    ORDER BY embedding <=> '[0.5, 0.5, 0.5]'
    LIMIT 10
) nearest;

RESET hnsw.iterative_scan;

-- Result:
--  rows_returned
-- ---------------
--             10
-- (1 row)

-- ------------------------------------------------------------
-- Example 14: Other ways to filter
-- ------------------------------------------------------------
CREATE INDEX idx_vec_items_kitchen
    ON vec_items
    USING hnsw (embedding vector_cosine_ops)
    WHERE category = 'kitchen';

EXPLAIN (COSTS OFF)
SELECT item_id
FROM vec_items
WHERE category = 'kitchen'
ORDER BY embedding <=> '[0.5, 0.5, 0.5]'
LIMIT 10;

-- Plan:
--   Limit
--     ->  Index Scan using idx_vec_items_kitchen on vec_items
--           Order By: (embedding <=> '[0.5,0.5,0.5]'::vector)

-- ------------------------------------------------------------
-- Example 15: Hybrid Search
-- ------------------------------------------------------------
CREATE TABLE help_chunks (
    chunk_id        INT PRIMARY KEY,
    title           VARCHAR(30) NOT NULL,
    audience        VARCHAR(10) NOT NULL,
    body            TEXT NOT NULL,
    embedding       VECTOR(4),
    embedding_model VARCHAR(50)
);

INSERT INTO help_chunks
    (chunk_id, title, audience, body,
     embedding, embedding_model)
VALUES
    (1, 'Returns', 'public',
     'Send most items back within 30 days.',
     '[0.9, 0.3, 0.1, 0.0]', 'handmade-v1'),
    (2, 'Returns', 'public',
     'We refund your card; refunds take 5 days.',
     '[0.8, 0.1, 0.0, 0.6]', 'handmade-v1'),
    (3, 'Delivery', 'public',
     'Standard delivery takes 3 to 5 days.',
     '[0.0, 1.0, 0.0, 0.1]', 'handmade-v1'),
    (4, 'Damaged deliveries', 'public',
     'Item arrived damaged? Tell us in 48 hours.',
     '[0.5, 0.8, 0.0, 0.0]', 'handmade-v1'),
    (5, 'Your account', 'public',
     'Reset your password from the sign-in page.',
     '[0.0, 0.0, 1.0, 0.0]', 'handmade-v1'),
    (6, 'Your account', 'public',
     'Turn on two-step sign-in in Settings.',
     '[0.0, 0.0, 0.9, 0.1]', 'handmade-v1'),
    (7, 'Payments', 'public',
     'Gift cards can''t be refunded.',
     '[0.1, 0.0, 0.0, 1.0]', 'handmade-v1'),
    (8, 'Refund approvals', 'staff',
     'Refunds over $500 need manager approval.',
     '[0.6, 0.0, 0.1, 0.7]', 'handmade-v1');

-- Result: INSERT 0 8

-- ------------------------------------------------------------
-- Example 16: Hybrid Search
-- ------------------------------------------------------------
WITH keyword AS (
    SELECT c.chunk_id,
           ROW_NUMBER() OVER (
               ORDER BY ts_rank(
                   to_tsvector('english', c.body),
                   q) DESC,
               c.chunk_id) AS kw_rank
    FROM help_chunks c
    CROSS JOIN websearch_to_tsquery('english',
        'refund OR damaged OR item') q
    WHERE to_tsvector('english', c.body) @@ q
    ORDER BY kw_rank
    LIMIT 5
),
semantic AS (
    SELECT chunk_id,
           ROW_NUMBER() OVER (
               ORDER BY embedding
                   <=> '[0.7, 0.5, 0.0, 0.4]',
               chunk_id) AS vec_rank
    FROM help_chunks
    ORDER BY vec_rank
    LIMIT 5
)
SELECT c.chunk_id, c.title, k.kw_rank,
       s.vec_rank,
       ROUND(COALESCE(1.0 / (60 + k.kw_rank), 0)
           + COALESCE(1.0 / (60 + s.vec_rank), 0),
             4) AS rrf_score
FROM keyword k
FULL JOIN semantic s
    ON s.chunk_id = k.chunk_id
JOIN help_chunks c
    ON c.chunk_id = COALESCE(k.chunk_id,
                             s.chunk_id)
ORDER BY rrf_score DESC, c.chunk_id;

-- Result:
--  chunk_id |       title        | kw_rank | vec_rank | rrf_score
-- ----------+--------------------+---------+----------+-----------
--         2 | Returns            |       2 |        1 |    0.0325
--         4 | Damaged deliveries |       1 |        3 |    0.0323
--         1 | Returns            |       3 |        2 |    0.0320
--         8 | Refund approvals   |       5 |        4 |    0.0310
--         7 | Payments           |       4 |     NULL |    0.0156
--         3 | Delivery           |    NULL |        5 |    0.0154
-- (6 rows)

-- ------------------------------------------------------------
-- Example 17: Retrieval-Augmented Generation
-- ------------------------------------------------------------
WITH top_chunks AS (
    SELECT chunk_id, title, body,
           embedding <=> '[0.7, 0.0, 0.0, 0.7]'
               AS distance
    FROM help_chunks
    WHERE audience = 'public'
        AND embedding IS NOT NULL
    ORDER BY distance
    LIMIT 3
)
SELECT STRING_AGG(
           '[' || chunk_id || ' ' || title || '] '
               || body,
           ' ' ORDER BY distance) AS context
FROM top_chunks;

-- Result:
--                                                                       context
-- ---------------------------------------------------------------------------------------------------------------------------------------------------
--  [2 Returns] We refund your card; refunds take 5 days. [7 Payments] Gift cards can't be refunded. [1 Returns] Send most items back within 30 days.
-- (1 row)

-- ------------------------------------------------------------
-- Example 18: Keeping Embeddings Up to Date
-- ------------------------------------------------------------
CREATE TABLE embedding_queue (
    chunk_id  INT PRIMARY KEY
        REFERENCES help_chunks (chunk_id)
        ON DELETE CASCADE,
    queued_at TIMESTAMP WITH TIME ZONE NOT NULL
        DEFAULT CURRENT_TIMESTAMP
);

CREATE FUNCTION queue_chunk_embedding()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO embedding_queue (chunk_id)
    VALUES (NEW.chunk_id)
    ON CONFLICT (chunk_id) DO NOTHING;
    RETURN NULL;
END;
$$;

CREATE TRIGGER help_chunks_queue_embedding
AFTER INSERT OR UPDATE OF body ON help_chunks
FOR EACH ROW
EXECUTE FUNCTION queue_chunk_embedding();

-- Result: CREATE TRIGGER

-- ------------------------------------------------------------
-- Example 19: Keeping Embeddings Up to Date
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

UPDATE help_chunks
SET body = 'Standard delivery takes 2 to 4 days.'
WHERE chunk_id = 3;

UPDATE help_chunks
SET title = 'Signing in'
WHERE chunk_id = 5;

INSERT INTO help_chunks
    (chunk_id, title, audience, body)
VALUES (9, 'Delivery', 'public',
        'We deliver to most countries.');

SELECT chunk_id
FROM embedding_queue
ORDER BY chunk_id;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  chunk_id
-- ----------
--         3
--         9
-- (2 rows)

-- ------------------------------------------------------------
-- Try It 1
-- Find the two products most like the Smartphone, by cosine distance
-- between their embeddings and the Smartphone's. Leave out the
-- Smartphone itself.
-- ------------------------------------------------------------
-- 1. Products nearest the Smartphone
SELECT p.product_name,
       ROUND((pe.embedding <=> s.embedding)
             ::numeric, 3) AS distance
FROM product_embeddings pe
JOIN products p
    ON p.product_id = pe.product_id
CROSS JOIN product_embeddings s
WHERE s.product_id = 2
    AND pe.product_id <> 2
ORDER BY pe.embedding <=> s.embedding
LIMIT 2;

-- Result:
--  product_name | distance
-- --------------+----------
--  Tablet       |    0.018
--  Laptop       |    0.097
-- (2 rows)

-- ------------------------------------------------------------
-- Try It 2
-- A customer asks "I forgot my password", which the model turns into
-- [0.1, 0.0, 0.9, 0.0]. Return the title and body of the single
-- nearest public chunk.
-- ------------------------------------------------------------
-- 2. Nearest public chunk to a password question
SELECT title, body
FROM help_chunks
WHERE audience = 'public'
    AND embedding IS NOT NULL
ORDER BY embedding <=> '[0.1, 0.0, 0.9, 0.0]'
LIMIT 1;

-- Result:
--     title     |                    body
-- --------------+--------------------------------------------
--  Your account | Reset your password from the sign-in page.
-- (1 row)

-- ------------------------------------------------------------
-- Try It 3
-- The help center switches to a model called handmade-v2. Queue
-- every chunk whose embedding came from another model, or has none,
-- then count the queue.
-- Changes data; the savepoint undoes the change, as in the book.
-- ------------------------------------------------------------
SAVEPOINT example;

-- 3. Queue every chunk not made by handmade-v2
INSERT INTO embedding_queue (chunk_id)
SELECT chunk_id
FROM help_chunks
WHERE embedding_model IS DISTINCT FROM
      'handmade-v2'
ON CONFLICT (chunk_id) DO NOTHING;

SELECT COUNT(*) AS queued
FROM embedding_queue;

ROLLBACK TO SAVEPOINT example;

-- Result:
--  queued
-- --------
--       8
-- (1 row)

-- ------------------------------------------------------------
-- Example 20: Try It
-- The book runs this without printing its result.
-- ------------------------------------------------------------
SAVEPOINT example;

DROP TABLE embedding_queue, help_chunks,
    vec_items, product_embeddings;
DROP FUNCTION queue_chunk_embedding();
-- Skip this if you used pgvector before
DROP EXTENSION IF EXISTS vector;

ROLLBACK TO SAVEPOINT example;

-- ------------------------------------------------------------
-- Undo everything this file changed.
-- ------------------------------------------------------------
ROLLBACK;
