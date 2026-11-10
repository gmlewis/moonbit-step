#!/usr/bin/env python3
"""Fetch curated external STEP references for local comparison.

Redistribution status of step.parts models is NOT verified per file. The
step.parts THIRD_PARTY_NOTICES file says third-party-derived STEP files retain
their source license (KiCad, FreeCAD-library, Adafruit, or SparkFun), but the
public API does not expose which source a given file came from. Therefore this
script never writes into the repository's committed fixture tree by default:
it requires an explicit output directory outside the repository and an explicit
acknowledgement flag.

Usage:
    python3 scripts/fetch_golden_references.py --out /tmp/step-golden \
        --accept-unverified-license

For each part ID the script fetches the catalog record, downloads `stepUrl`,
and verifies the declared SHA-256 and byte size before writing the file. It
writes `fetch-report.json` in the output directory with the provenance record
used by components/testdata/golden/manifest.json.

This is a development-time utility. The component library has no network or
Python runtime dependency.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
import sys
import urllib.request
from pathlib import Path

API = "https://api.step.parts/v1"
CATALOG_COMMIT = "c6113328a5695b976a010a203a90fe86191769bf"
LFS_ENDPOINT = "https://github.com/earthtojake/step.parts.git"
USER_AGENT = "moonbit-step-golden-fetch/1.0"

# Curated candidates, one per component family this project models.
PART_IDS = [
    "iso4762_socket_head_cap_screw_m3x10",
    "iso4762_socket_head_cap_screw_m4x20",
    "iso4762_socket_head_cap_screw_m5x10",
    "iso4032_hex_nut_m4",
    "flat_washer_normal_m4_simple",
    "bearing_608zz",
    "profile_2020_b_slot6_a_l50",
    "spur_gear_m2_0_20t_bore8",
]


def fetch_json(url: str) -> dict:
    # Prefer curl: some system Python builds ship an OpenSSL that cannot
    # negotiate the catalog's TLS endpoint.
    if shutil.which("curl"):
        proc = subprocess.run(
            ["curl", "-sSL", "--fail", "-A", USER_AGENT, url],
            capture_output=True,
            text=True,
            timeout=120,
            check=True,
        )
        return json.loads(proc.stdout)
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.load(response)


def lfs_download(oid: str, size: int, destination: Path) -> None:
    """Fetch a Git LFS object through the signed batch API.

    The public media host is not reachable from every network (some TLS
    middleboxes reject it), so use the LFS batch endpoint and follow the
    short-lived signed URL. The signed URL is never written to the report.
    """
    payload = json.dumps(
        {
            "operation": "download",
            "transfers": ["basic"],
            "objects": [{"oid": oid, "size": size}],
        }
    ).encode()
    headers = [
        "-H",
        "Accept: application/vnd.git-lfs+json",
        "-H",
        "Content-Type: application/vnd.git-lfs+json",
    ]
    if shutil.which("curl"):
        proc = subprocess.run(
            [
                "curl",
                "-sSL",
                "--fail",
                *headers,
                "-X",
                "POST",
                "--data-binary",
                "@-",
                f"{LFS_ENDPOINT}/info/lfs/objects/batch",
            ],
            input=payload,
            capture_output=True,
            timeout=120,
            check=True,
        )
        batch = json.loads(proc.stdout)
    else:
        request = urllib.request.Request(
            f"{LFS_ENDPOINT}/info/lfs/objects/batch",
            data=payload,
            headers={
                "Accept": "application/vnd.git-lfs+json",
                "Content-Type": "application/vnd.git-lfs+json",
                "User-Agent": USER_AGENT,
            },
            method="POST",
        )
        with urllib.request.urlopen(request, timeout=60) as response:
            batch = json.load(response)
    objects = batch.get("objects") or []
    if not objects or not objects[0].get("actions"):
        raise RuntimeError("LFS batch response has no download action")
    href = objects[0]["actions"]["download"]["href"]
    if shutil.which("curl"):
        subprocess.run(
            ["curl", "-sSL", "--fail", "-A", USER_AGENT, href, "-o", str(destination)],
            timeout=600,
            check=True,
        )
    else:
        with urllib.request.urlopen(href, timeout=300) as response, destination.open(
            "wb"
        ) as out:
            out.write(response.read())


def download(url: str, destination: Path, oid: str, size: int) -> None:
    # LFS first; the signed URL avoids the media.githubusercontent.com host.
    try:
        lfs_download(oid, size, destination)
        return
    except Exception:
        pass
    if shutil.which("curl"):
        subprocess.run(
            ["curl", "-sSL", "--fail", "-A", USER_AGENT, url, "-o", str(destination)],
            timeout=600,
            check=True,
        )
        return
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=300) as response, destination.open(
        "wb"
    ) as out:
        out.write(response.read())


def record_digest(destination: Path) -> tuple[str, int]:
    data = destination.read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    size = len(data)
    destination.with_suffix(destination.suffix + ".sha256").write_text(digest + "\n")
    destination.with_suffix(destination.suffix + ".bytes").write_text(f"{size}\n")
    return digest, size


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", required=True, help="fresh output directory")
    parser.add_argument(
        "--accept-unverified-license",
        action="store_true",
        help="acknowledge that per-file redistribution rights are unverified",
    )
    parser.add_argument("--part", action="append", help="limit to these part IDs")
    args = parser.parse_args()

    if not args.accept_unverified_license:
        print(
            "Refusing to download: per-file license/provenance is not verified. "
            "Re-run with --accept-unverified-license for local comparison only.",
            file=sys.stderr,
        )
        return 2

    out_dir = Path(args.out).expanduser().resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    ids = args.part or PART_IDS
    report = {
        "catalog": "step.parts",
        "catalog_commit": CATALOG_COMMIT,
        "api": API,
        "license_status": (
            "UNVERIFIED per file: step.parts THIRD_PARTY_NOTICES lists source "
            "licenses for derived models, but the API does not expose the "
            "per-file source. Do not redistribute these files."
        ),
        "items": [],
    }
    for part_id in ids:
        try:
            record = fetch_json(f"{API}/parts/{part_id}")
            step_url = record["stepUrl"]
            expected_sha = record["sha256"]
            expected_size = record["byteSize"]
            filename = f"{part_id}.step"
            destination = out_dir / filename
            download(step_url, destination, expected_sha, expected_size)
            actual_sha, actual_size = record_digest(destination)
            if actual_sha != expected_sha:
                raise RuntimeError(
                    f"sha256 mismatch: {actual_sha} != {expected_sha}"
                )
            if actual_size != expected_size:
                raise RuntimeError(
                    f"byte size mismatch: {actual_size} != {expected_size}"
                )
            item = {
                "id": part_id,
                "name": record["name"],
                "standard": record.get("standard"),
                "attributes": record.get("attributes"),
                "source_page": record.get("pageUrl"),
                "download_url": step_url,
                "filename": filename,
                "sha256": actual_sha,
                "byte_size": actual_size,
                "license_status": "UNVERIFIED",
                "redistribution": "not committed; local comparison only",
            }
            report["items"].append(item)
            print(f"OK {filename} {actual_size} bytes sha256={actual_sha}")
        except Exception as exc:  # noqa: BLE001 - development helper
            print(f"FAIL {part_id}: {exc}", file=sys.stderr)
            report["items"].append({"id": part_id, "error": str(exc)})
            return 1

    (out_dir / "fetch-report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(f"wrote {out_dir / 'fetch-report.json'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
