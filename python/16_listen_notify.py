# Chapter 43: LISTEN and NOTIFY
# A listener waits on a channel while a
# second connection sends two notifications.
import os
import threading
import time

import psycopg

DSN = os.environ["DATABASE_URL"]


def send():
    time.sleep(0.5)
    with psycopg.connect(DSN) as conn:
        conn.execute(
            "SELECT pg_notify(%s, %s)",
            ("email_jobs_ready", "7"))
        print("Sent, not yet committed")
        time.sleep(0.5)
        conn.execute(
            "NOTIFY email_jobs_ready, '8'")
    # the with block committed: both are sent


with psycopg.connect(DSN,
                     autocommit=True) as conn:
    conn.execute("LISTEN email_jobs_ready")
    threading.Thread(target=send).start()
    for n in conn.notifies(timeout=5,
                           stop_after=2):
        print("Got", n.channel, n.payload)
