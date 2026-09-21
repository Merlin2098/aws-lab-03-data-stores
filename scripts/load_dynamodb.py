"""Load tracking_events.json into the package_tracking DynamoDB table
(Sesión 03 storage lab).
"""

from __future__ import annotations

import argparse
import json

from lab_storage_common import DATA_DIR, get_boto3_resource, latest_version, load_config


def load_events(table, events: list[dict]) -> int:
    loaded = 0
    with table.batch_writer() as batch:
        for event in events:
            batch.put_item(Item=event)
            loaded += 1
    return loaded


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", default="src/config/lab_storage_config.yaml")
    parser.add_argument(
        "--version",
        default=None,
        help="Timestamp of the generate_data.py run to load, e.g. 20260920-143000. "
        "Defaults to the most recent run under data/dynamodb/.",
    )
    args = parser.parse_args()

    config = load_config(args.config)
    dynamodb_dir = DATA_DIR / "dynamodb"
    version = args.version or latest_version(dynamodb_dir)
    events_path = dynamodb_dir / f"tracking_events_{version}.json"

    events = json.loads(events_path.read_text(encoding="utf-8"))

    dynamodb = get_boto3_resource("dynamodb")
    table = dynamodb.Table(config["dynamodb_table_name"])

    loaded = load_events(table, events)
    print(f"version loaded: {version}")
    print(f"tracking_events loaded into {config['dynamodb_table_name']}: {loaded}")


if __name__ == "__main__":
    main()
