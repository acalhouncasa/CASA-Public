"""Load synthetic monthly_encounters into data/local.sqlite. Not PHI."""

from __future__ import annotations

import csv
import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CSV_PATH = ROOT / "examples" / "monthly_encounters.csv"
DB_PATH = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "data" / "local.sqlite"


def main() -> int:
    if not CSV_PATH.is_file():
        print(f"missing {CSV_PATH}")
        return 2
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    rows = list(csv.DictReader(CSV_PATH.open(encoding="utf-8")))
    con = sqlite3.connect(str(DB_PATH))
    try:
        con.execute(
            """
            CREATE TABLE IF NOT EXISTS monthly_encounters (
                site_code TEXT NOT NULL,
                month TEXT NOT NULL,
                encounters INTEGER NOT NULL,
                no_shows INTEGER NOT NULL,
                walk_ins INTEGER NOT NULL,
                PRIMARY KEY (site_code, month)
            )
            """
        )
        con.executemany(
            """
            INSERT OR REPLACE INTO monthly_encounters
            (site_code, month, encounters, no_shows, walk_ins)
            VALUES (:site_code, :month, :encounters, :no_shows, :walk_ins)
            """,
            rows,
        )
        con.commit()
        n = con.execute("SELECT COUNT(*) FROM monthly_encounters").fetchone()[0]
    finally:
        con.close()
    print(f"loaded {n} rows into {DB_PATH}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
