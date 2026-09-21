"""Generate synthetic customers, orders, and package tracking events for the
Sesión 03 storage lab (docs/laboratorio_sesion_03_storage.md).

Each run is stamped with the same timestamp and writes one version per
destination service, so repeated runs simulate incremental data loads:
  data/rds/customers_<timestamp>.csv
  data/rds/orders_<timestamp>.csv
  data/dynamodb/tracking_events_<timestamp>.json
  data/s3/tracking_events_<timestamp>.parquet/ (partitioned by year/month/day)
"""

from __future__ import annotations

import argparse
import json
import random
from datetime import datetime, timedelta
from pathlib import Path

import pyarrow as pa
import pyarrow.parquet as pq
from faker import Faker

REPO_ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = REPO_ROOT / "data"

CITIES = ["Lima", "Ica", "Arequipa", "Trujillo", "Cusco", "Piura"]
SEGMENTS = ["Enterprise", "SMB", "Startup"]
ORDER_STATUSES = ["DELIVERED", "IN_TRANSIT", "PENDING", "CANCELLED"]
TRACKING_STATUSES = ["RECEIVED", "IN_TRANSIT", "OUT_FOR_DELIVERY", "DELIVERED"]

DEFAULT_CUSTOMER_COUNT = 100
DEFAULT_ORDER_COUNT = 500
DEFAULT_PACKAGE_COUNT = 150


def generate_customers(fake: Faker, count: int) -> list[dict]:
    return [
        {
            "customer_id": f"C{i:03d}",
            "name": f"Customer {i:03d}",
            "city": random.choice(CITIES),
            "segment": random.choice(SEGMENTS),
        }
        for i in range(1, count + 1)
    ]


def generate_orders(customers: list[dict], count: int) -> list[dict]:
    orders = []
    for i in range(1, count + 1):
        customer = random.choice(customers)
        order_date = fake_date_within_days(90)
        orders.append(
            {
                "order_id": f"O{i:03d}",
                "customer_id": customer["customer_id"],
                "order_date": order_date.date().isoformat(),
                "status": random.choice(ORDER_STATUSES),
                "total_amount": round(random.uniform(20, 2000), 2),
            }
        )
    return orders


def fake_date_within_days(days: int) -> datetime:
    return datetime.now() - timedelta(days=random.randint(0, days))


def generate_tracking_events(package_count: int) -> list[dict]:
    events = []
    for i in range(1, package_count + 1):
        package_id = f"PKG-{i:06d}"
        city = random.choice(CITIES)
        start = fake_date_within_days(30)
        cursor = start
        for status in TRACKING_STATUSES:
            cursor = cursor + timedelta(hours=random.randint(1, 12))
            events.append(
                {
                    "package_id": package_id,
                    "timestamp": cursor.isoformat(),
                    "status": status,
                    "city": city,
                }
            )
    return events


def write_csv(rows: list[dict], path: Path) -> None:
    import csv

    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)


def write_json(rows: list[dict], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(rows, indent=2), encoding="utf-8")


def write_parquet_partitioned(rows: list[dict], path: Path) -> None:
    for row in rows:
        ts = datetime.fromisoformat(row["timestamp"])
        row["year"] = f"{ts.year:04d}"
        row["month"] = f"{ts.month:02d}"
        row["day"] = f"{ts.day:02d}"

    table = pa.Table.from_pylist(rows)
    path.parent.mkdir(parents=True, exist_ok=True)
    pq.write_to_dataset(
        table, root_path=str(path), partition_cols=["year", "month", "day"]
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--customers", type=int, default=DEFAULT_CUSTOMER_COUNT)
    parser.add_argument("--orders", type=int, default=DEFAULT_ORDER_COUNT)
    parser.add_argument("--packages", type=int, default=DEFAULT_PACKAGE_COUNT)
    parser.add_argument("--seed", type=int, default=None)
    args = parser.parse_args()

    if args.seed is not None:
        random.seed(args.seed)
        Faker.seed(args.seed)

    fake = Faker()
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")

    customers = generate_customers(fake, args.customers)
    orders = generate_orders(customers, args.orders)
    tracking_events = generate_tracking_events(args.packages)

    customers_path = DATA_DIR / "rds" / f"customers_{timestamp}.csv"
    orders_path = DATA_DIR / "rds" / f"orders_{timestamp}.csv"
    tracking_json_path = DATA_DIR / "dynamodb" / f"tracking_events_{timestamp}.json"
    tracking_parquet_path = DATA_DIR / "s3" / f"tracking_events_{timestamp}.parquet"

    write_csv(customers, customers_path)
    write_csv(orders, orders_path)
    write_json(tracking_events, tracking_json_path)
    write_parquet_partitioned(tracking_events, tracking_parquet_path)

    print(f"version: {timestamp}")
    print(f"customers: {len(customers)} -> {customers_path}")
    print(f"orders: {len(orders)} -> {orders_path}")
    print(f"tracking_events: {len(tracking_events)} -> {tracking_json_path}")
    print(f"tracking_events (parquet, partitioned) -> {tracking_parquet_path}")


if __name__ == "__main__":
    main()
