"""Upload the partitioned tracking_events Parquet dataset to the lab data lake
bucket's raw/ prefix (Sesión 03 storage lab).
"""

from __future__ import annotations

import argparse
from pathlib import Path

from lab_storage_common import DATA_DIR, get_boto3_client, latest_version, load_config


def upload_parquet_dataset(client, bucket: str, raw_prefix: str, local_root: Path) -> int:
    uploaded = 0
    for file_path in local_root.rglob("*.parquet"):
        relative_key = file_path.relative_to(local_root).as_posix()
        key = f"{raw_prefix}{relative_key}"
        client.upload_file(str(file_path), bucket, key)
        print(f"uploaded s3://{bucket}/{key}")
        uploaded += 1
    return uploaded


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", default="src/config/lab_storage_config.yaml")
    parser.add_argument(
        "--version",
        default=None,
        help="Timestamp of the generate_data.py run to upload, e.g. 20260920-143000. "
        "Defaults to the most recent run under data/s3/.",
    )
    args = parser.parse_args()

    config = load_config(args.config)
    s3_dir = DATA_DIR / "s3"
    version = args.version or latest_version(s3_dir)
    local_root: Path = s3_dir / f"tracking_events_{version}.parquet"

    s3_client = get_boto3_client("s3")
    count = upload_parquet_dataset(
        s3_client, config["datalake_bucket_name"], config["datalake_raw_prefix"], local_root
    )
    print(f"version uploaded: {version}")
    print(f"Uploaded {count} Parquet file(s).")


if __name__ == "__main__":
    main()
