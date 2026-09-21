"""Shared config/credentials loading for the Sesión 03 storage lab scripts."""

from __future__ import annotations

import os
from pathlib import Path

import boto3
import yaml
from dotenv import load_dotenv

REPO_ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = REPO_ROOT / "data"

load_dotenv(REPO_ROOT / ".env.credentials", override=True)


def load_config(config_path: str = "src/config/lab_storage_config.yaml") -> dict:
    return yaml.safe_load((REPO_ROOT / config_path).read_text(encoding="utf-8"))


def latest_version(service_dir: Path) -> str:
    """Return the most recent run timestamp under data/<service>/, e.g. "20260920-143000".

    Each generate_data.py run writes files named "<name>_<timestamp>.<ext>"
    (or a "<name>_<timestamp>/" directory for the partitioned Parquet
    dataset) into data/<service>/. Timestamps sort lexicographically, so the
    max of the "<timestamp>" suffixes is the latest run.
    """
    timestamps = {
        entry.stem.rsplit("_", 1)[-1]
        for entry in service_dir.iterdir()
        if "_" in entry.stem
    }
    if not timestamps:
        raise SystemExit(
            f"No versioned files found under {service_dir}. Run scripts/generate_data.py first."
        )
    return max(timestamps)


def _credentials() -> dict:
    return {
        "aws_access_key_id": os.environ["AWS_ACCESS_KEY_ID"],
        "aws_secret_access_key": os.environ["AWS_SECRET_ACCESS_KEY"],
        "aws_session_token": os.environ.get("AWS_SESSION_TOKEN") or None,
        "region_name": os.environ.get("AWS_DEFAULT_REGION", "us-east-1"),
    }


def get_boto3_client(service: str):
    return boto3.client(service, **_credentials())


def get_boto3_resource(service: str):
    return boto3.resource(service, **_credentials())


def get_rds_connection_params() -> dict:
    endpoint = os.environ["RDS_ENDPOINT"]
    host, _, port = endpoint.partition(":")
    return {
        "host": host,
        "port": int(port) if port else 5432,
        "dbname": os.environ["RDS_DB_NAME"],
        "user": os.environ["RDS_USERNAME"],
        "password": os.environ["RDS_PASSWORD"],
    }
