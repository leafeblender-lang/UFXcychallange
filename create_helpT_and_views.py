import sqlite3
from pathlib import Path

DB_PATH = Path("golf.db")
SQL_FILES = [
    Path("help_tables.sql"),
    Path("views.sql"),
]

def run_sql_file(conn: sqlite3.Connection, path: Path) -> None:
    with path.open("r", encoding="utf-8") as f:
        sql = f.read()
    conn.executescript(sql)

def main() -> None:
    with sqlite3.connect(DB_PATH) as conn:
        for sql_file in SQL_FILES:
            run_sql_file(conn, sql_file)
        conn.commit()

    print("done")

if __name__ == "__main__":
    main()