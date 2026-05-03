import json
import sqlite3
from pathlib import Path

DATA_DIR=Path("data")
DB_PATH=Path("golf.db")

EVENT_PATH=DATA_DIR / "events.jsonl"
MAPS_PATH=DATA_DIR / "maps.jsonl"

def create_tables(conn):

    cursor=conn.cursor()

    cursor.execute("""DROP TABLE IF EXISTS raw_events;""")

    cursor.execute("""DROP TABLE IF EXISTS raw_maps;""")

    cursor.execute("""
        CREATE TABLE raw_events(
        id INTEGER,
        timestamp INTEGER,
        event_type TEXT,
        user_id TEXT,
        event_data TEXT
        );
        """)
    cursor.execute("""
        CREATE TABLE raw_maps (
        map_id TEXT,
        map_name TEXT);
    """)

    conn.commit()

def load_events(conn):
    cursor=conn.cursor()

    with open(EVENT_PATH, "r",encoding="utf-8") as file:
        for line in file:
            if not line.strip():
                continue
            event = json.loads(line)

            cursor.execute("""
            INSERT INTO raw_events (
                id,timestamp,event_type,user_id,event_data
            )
            VALUES(?,?,?,?,?);
            """,(
                event.get("id"),
                event.get("timestamp"),
                event.get("event_type"),
                event.get("user_id"),
                json.dumps(event.get("event_data")),
            ))
        conn.commit()

def load_maps(conn):
    cursor = conn.cursor()
    total = 0

    with open(MAPS_PATH, "r", encoding="utf-8") as file:
        for line in file:
            if not line.strip():
                continue

            row = json.loads(line)

            cursor.execute("""
            INSERT INTO raw_maps(
            map_id, map_name
            )
            VALUES(?,?);
            """, (
                row.get("id"),
                row.get("name"),
            ))
            total += 1

    conn.commit()
    print(f"Total maps: {total}")

def main():
    conn=sqlite3.connect(DB_PATH)
    create_tables(conn)
    print("done")
    load_events(conn)
    load_maps(conn)
    conn.close()
    print("done")

if __name__ == "__main__":
    main()

