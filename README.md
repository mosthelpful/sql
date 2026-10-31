# The Most Helpful SQL Guide: Scripts and Sample Database

These files accompany *The Most Helpful SQL Guide: Navigating Databases With Ease*, Second Edition (2026).

They contain the sample database the book uses, and every example the book runs on PostgreSQL, so you can follow along without retyping code.

## What's Here

| Path | Contents |
|---|---|
| `sample_db.sql` | Creates the sample database's seven tables and fills them (Appendix D). Run it again at any time to reset the data. |
| `chapters/` | One script per chapter, with the chapter's examples in book order and the answers to its Try It exercises. |
| `exercises/` | Answers to the Practical Exercises: `basic.sql`, `intermediate.sql` and `advanced.sql`. |
| `appendix_c/patterns.sql` | The common SQL patterns from Appendix C. |
| `appendix_e/interview.sql` | Answers to the interview questions in Appendix E. |
| `appendix_f/excel_to_sql.sql` | The SQL side of each Excel example in Appendix F. |
| `python/` | The Python examples from Chapter 43, one runnable script each. |
| `data/` | The CSV files the book loads: `suppliers.csv` (Chapter 9) and `books.csv` (Chapter 44's library project). If you start psql in this folder, write `'data/suppliers.csv'` or `'data/books.csv'` in the book's `\copy` command. |
| `ERRATA.md` | Corrections to the book. |

Chapters 1, 3, 39 and 45 have no runnable examples, so they have no script.

Under each example is the result the book prints, as a comment, so you can check your own result against it.

## Getting Started

1. **Get PostgreSQL 16 or later.** Install it from [postgresql.org/download](https://www.postgresql.org/download/), or use [db<>fiddle](https://dbfiddle.uk) to run SQL in your browser with nothing to install. Chapter 5 of the book walks through both. (Chapter 41 needs a server with the pgvector extension; see Versions.)
2. **Download these files.** On GitHub, click **Code**, then **Download ZIP**, and unzip it. If you use Git, you can clone the repository instead.
3. **Create a database and load the sample data.** In a terminal, from the unzipped folder:

   ```
   createdb sqlguide
   psql -d sqlguide -f sample_db.sql
   ```

   Or, inside psql, run `CREATE DATABASE sqlguide;`, then `\c sqlguide`, then `\i sample_db.sql`. In db<>fiddle or a graphical tool such as pgAdmin or DBeaver, paste the contents of `sample_db.sql` into a query window and run it.
4. **Check.** `SELECT COUNT(*) FROM employees;` should return 8.

## Running the Examples

**One at a time.** Copy an example into psql, pgAdmin, DBeaver or db<>fiddle and run it. Some examples build on an earlier one in the same chapter, such as a table or view it created, so work through a chapter in order. If an example changes data, wrap it in `BEGIN;` and `ROLLBACK;` to keep the data as the book expects, or reload `sample_db.sql` afterwards.

**A whole chapter at once.** In psql:

```
psql -d sqlguide -f chapters/ch10_basic_queries.sql
```

Each file runs as one transaction and ends with `ROLLBACK`, so it leaves your database exactly as it was. Examples that change data, or that fail on purpose to show an error message, are wrapped in a savepoint and undone. That's how the book's results were produced, so your output should match the book's row for row.

Some notes:

- Graphical tools usually stop a script at its first error, and several chapters have examples that fail on purpose. In those tools, run the examples one at a time, or run the whole file in psql.
- The book and these comments show `NULL`, `true` and `false`. psql shows NULL as an empty cell, and booleans as t and f. To match the NULLs, run `\pset null NULL` in psql, or add `-P null=NULL` when you run a whole file: `psql -d sqlguide -P null=NULL -f chapters/ch10_basic_queries.sql`.

## Versions

The examples were tested on PostgreSQL 16. A few use features added in PostgreSQL 15 or 16, such as MERGE and the IS JSON test, and the book points these out.

Chapter 41 needs the pgvector extension, version 0.8.2 or later; 0.8.2 fixed a security flaw in earlier versions. (The examples were tested with 0.8.1, and later 0.8 releases only fix bugs.) Install it from your operating system's packages or from [github.com/pgvector/pgvector](https://github.com/pgvector/pgvector), or use a cloud PostgreSQL service that includes it. Chapters 25 and 30 use the btree_gist and pgcrypto extensions, which ship with PostgreSQL.

The Python scripts need Python 3.11 or later, and Chapter 43's "Setting Up" section walks through the setup. In a virtual environment, run `pip install "psycopg[binary,pool]" sqlalchemy`, then point DATABASE_URL at your database: `export DATABASE_URL=postgresql://localhost/sqlguide` on macOS or Linux, or `$env:DATABASE_URL = "postgresql://localhost/sqlguide"` in Windows PowerShell. Run a script from this folder, for example `python python/01_round_trip.py`. Some scripts commit changes, so reload `sample_db.sql` afterwards.

Later versions should give the same results, with two exceptions. Query plans can differ slightly between versions and settings. PostgreSQL 18 and later also print extra detail in EXPLAIN ANALYZE output; Chapter 22 explains it.

## Other Databases

The scripts are written for PostgreSQL. Appendix D explains how to adapt `sample_db.sql` for MySQL, SQL Server and Oracle. Throughout the book, Dialect notes show where those databases' syntax differs.

## Found a Mistake?

Please email [waviest.unity_17@icloud.com](mailto:waviest.unity_17@icloud.com). Say which chapter and section it's in (or the paperback page), what you expected and what you got. Corrections are listed in [ERRATA.md](ERRATA.md).

## License

The SQL scripts are released under the MIT License (see [LICENSE](LICENSE)), so you're free to use them in your own work. The text of the book is copyrighted, all rights reserved, and isn't included here.
