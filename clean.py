import sqlite3
from pathlib import Path

DB_PATH = Path("golf.db")
SQL_PATH = Path("clean_data.sql")

def main() -> None:
    if not DB_PATH.exists():
        raise FileNotFoundError(f"not found: {DB_PATH}")

    if not SQL_PATH.exists():
        raise FileNotFoundError(f"not found: {SQL_PATH}")

    with sqlite3.connect(DB_PATH) as conn:
        with SQL_PATH.open("r", encoding="utf-8") as f:
            conn.executescript(f.read())
        conn.commit()

    print("gotov")

if __name__ == "__main__":
    main()