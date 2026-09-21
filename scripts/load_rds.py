"""Create the customers/orders tables in RDS and load the generated CSVs
(Sesión 03 storage lab).
"""

from __future__ import annotations

import argparse
import csv

import psycopg2

from lab_storage_common import (
    DATA_DIR,
    REPO_ROOT,
    get_rds_connection_params,
    latest_version,
    load_config,
)


def create_schema(conn, schema_path) -> None:
    schema_sql = (REPO_ROOT / schema_path).read_text(encoding="utf-8")
    with conn.cursor() as cur:
        cur.execute(schema_sql)
    conn.commit()


def load_csv(conn, table: str, csv_path, columns: list[str]) -> int:
    placeholders = ", ".join(["%s"] * len(columns))
    column_list = ", ".join(columns)
    insert_sql = (
        f"INSERT INTO {table} ({column_list}) VALUES ({placeholders}) "
        f"ON CONFLICT DO NOTHING"
    )

    with csv_path.open(newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        rows = [tuple(row[col] for col in columns) for row in reader]

    with conn.cursor() as cur:
        cur.executemany(insert_sql, rows)
    conn.commit()
    return len(rows)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", default="src/config/lab_storage_config.yaml")
    parser.add_argument(
        "--version",
        default=None,
        help="Timestamp of the generate_data.py run to load, e.g. 20260920-143000. "
        "Defaults to the most recent run under data/rds/.",
    )
    args = parser.parse_args()

    config = load_config(args.config)
    rds_dir = DATA_DIR / "rds"
    version = args.version or latest_version(rds_dir)
    customers_path = rds_dir / f"customers_{version}.csv"
    orders_path = rds_dir / f"orders_{version}.csv"

    conn = psycopg2.connect(**get_rds_connection_params())

    try:
        create_schema(conn, config["schema_path"])
        customers_loaded = load_csv(
            conn, "customers", customers_path,
            ["customer_id", "name", "city", "segment"],
        )
        orders_loaded = load_csv(
            conn, "orders", orders_path,
            ["order_id", "customer_id", "order_date", "status", "total_amount"],
        )
        print(f"version loaded: {version}")
        print(f"customers loaded: {customers_loaded}")
        print(f"orders loaded: {orders_loaded}")
    finally:
        conn.close()


if __name__ == "__main__":
    main()
