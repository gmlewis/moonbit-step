#!/usr/bin/env python3
"""Fetch a curated corpus of standardized STEP references for local comparison.

The script selects parts from the step.parts catalog by standard designation,
family, nominal size, and representative lengths. It never treats a record as a
golden reference merely because it appears in the catalog: the standard must
match exactly, the selected size/length must be present, and every downloaded
file is checked against the catalog's SHA-256 and byte size.

The STEP files are downloaded from the open-source step.parts corpus and are
used as golden references. There are no licensing restrictions on using them.
The script writes to the output directory given by ``--out``.

Usage:
    # Default: M2, M2.5, M3, M4, M5; representative lengths.
    python3 scripts/fetch_golden_references.py \
        --out components/testdata/golden/external

    # Include M6 and M8.
    python3 scripts/fetch_golden_references.py \
        --out components/testdata/golden/external --scope extended

    # List the planned selection without downloading.
    python3 scripts/fetch_golden_references.py --scope core --list

    # Fetch every catalog length for the selected standards (large).
    python3 scripts/fetch_golden_references.py \
        --out components/testdata/golden/external --scope all --allow-large

Use --selection to limit the run (for example --selection iso4762
--selection iso4032). Use --list-selections to see all keys.

The script writes `fetch-report.json` in the output directory with the
provenance record and pass/fail/cached status for every selected item.

This is a development-time utility. The component library has no network or
Python runtime dependency.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import sys
import time
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path

API = "https://api.step.parts/v1"
CATALOG_COMMIT = "c6113328a5695b976a010a203a90fe86191769bf"
LFS_ENDPOINT = "https://github.com/earthtojake/step.parts.git"
USER_AGENT = "moonbit-step-golden-fetch/1.0"

SCOPE_SIZES = {
    "core": ["M2", "M2.5", "M3", "M4", "M5"],
    "extended": ["M2", "M2.5", "M3", "M4", "M5", "M6", "M8"],
    "all": None,
}
SCOPE_DIAMETERS = {
    "core": [1.0, 1.5, 1.6, 2.0, 2.5, 3.0, 3.2, 4.0, 5.0],
    "extended": [1.0, 1.5, 1.6, 2.0, 2.5, 3.0, 3.2, 4.0, 5.0, 6.0, 8.0],
    "all": None,
}

# Preferred lengths in millimetres. The script picks the closest available
# length for each anchor, then fills with evenly spaced lengths if needed.
PREFERRED_LENGTHS = {
    "M2": [3.0, 5.0, 8.0, 12.0],
    "M2.5": [4.0, 6.0, 10.0, 16.0],
    "M3": [5.0, 8.0, 12.0, 20.0],
    "M4": [6.0, 10.0, 16.0, 25.0],
    "M5": [8.0, 12.0, 20.0, 30.0],
    "M6": [10.0, 16.0, 25.0, 40.0],
    "M8": [12.0, 20.0, 30.0, 50.0],
}

BEARING_IDS = [
    "bearing_623_open_simple",
    "bearing_624_open_simple",
    "bearing_625_open_simple",
    "bearing_626_open_simple",
    "bearing_688_open_simple",
    "bearing_608_open_simple",
    "bearing_608zz",
    "bearing_6000_open_simple",
    "bearing_6001_open_simple",
    "bearing_6002_open_simple",
    "bearing_6003_open_simple",
    "bearing_6200_open_simple",
    "bearing_6201_open_simple",
    "bearing_6202_open_simple",
]

# Non-standardized but useful secondary oracles. They are clearly labeled in
# the report; never treat them as normative standard references.
NONSTANDARD_IDS = [
    "profile_2020_b_slot6_a_l50",
    "spur_gear_m2_0_20t_bore8",
    "spur_gear_m2_0_40t_bore10",
]


@dataclass(frozen=True)
class Selection:
    key: str
    label: str
    standard: str | None
    family: str | None
    size_field: str | None  # "thread" or "diameter"
    kind: str  # screw, nut, washer, ring, pin, rod, bearing
    length_mode: str  # anchors, spread, none, all
    default_lengths: int = 3
    id_prefix: str | None = None
    note: str = ""
    include_in_core: bool = True
    include_in_extended: bool = True


SELECTIONS: list[Selection] = [
    # Screws / bolts
    Selection(
        "iso4762", "ISO 4762 socket head cap screws", "ISO 4762",
        "socket-head-cap-screw", "thread", "screw", "anchors", 4,
        id_prefix="iso4762_",
    ),
    Selection(
        "iso7380", "ISO 7380 button head screws", "ISO 7380",
        "button-head-screw", "thread", "screw", "anchors", 3,
    ),
    Selection(
        "iso10642", "ISO 10642 countersunk screws", "ISO 10642",
        "countersunk-screw", "thread", "screw", "anchors", 3,
        id_prefix="iso10642_",
    ),
    Selection(
        "iso4017", "ISO 4017 hex head screws", "ISO 4017",
        "hex-head-cap-screw", "thread", "screw", "anchors", 3,
    ),
    Selection(
        "din913", "DIN 913 socket set screws", "DIN 913",
        "set-screw", "thread", "screw", "anchors", 3,
        id_prefix="din913_",
    ),
    # Nuts
    Selection(
        "iso4032", "ISO 4032 hexagon regular nuts", "ISO 4032",
        "hex-nut", "thread", "nut", "none",
    ),
    Selection(
        "iso4035", "ISO 4035 thin hexagon nuts", "ISO 4035",
        "thin-jam-nut", "thread", "nut", "none",
    ),
    Selection(
        "din1587", "DIN 1587 cap nuts", "DIN 1587",
        "cap-nut", "thread", "nut", "none",
    ),
    Selection(
        "din557", "DIN 557 square nuts", "DIN 557",
        "square-nut", "thread", "nut", "none",
    ),
    # Washers
    Selection(
        "iso7089", "ISO 7089 plain washers", "ISO 7089",
        "flat-washer", "thread", "washer", "none",
    ),
    Selection(
        "iso7091", "ISO 7091 plain washers (C)", "ISO 7091",
        "flat-washer", "thread", "washer", "none",
    ),
    Selection(
        "iso7092", "ISO 7092 small plain washers", "ISO 7092",
        "flat-washer", "thread", "washer", "none",
    ),
    Selection(
        "iso7093", "ISO 7093 large plain washers", "ISO 7093",
        "large-washer", "thread", "washer", "none",
    ),
    Selection(
        "iso7090", "ISO 7090 chamfered washers", "ISO 7090",
        "flat-washer", "thread", "washer", "none",
    ),
    Selection(
        "din125", "DIN 125 plain washers", "DIN 125",
        "flat-washer", "thread", "washer", "none",
    ),
    Selection(
        "din127", "DIN 127 spring washers", "DIN 127",
        "spring-washer", "thread", "washer", "none",
    ),
    Selection(
        "din7349", "DIN 7349 thick washers", "DIN 7349",
        "flat-washer", "thread", "washer", "none",
    ),
    Selection(
        "din93", "DIN 93 tab washers", "DIN 93",
        "tab-washer", "thread", "washer", "none",
    ),
    Selection(
        "din440", "DIN 440 large washers", "DIN 440",
        "large-washer", "thread", "washer", "none",
    ),
    # Retaining rings
    Selection(
        "din471", "DIN 471 external retaining rings", "DIN 471",
        "retaining-ring", "thread", "ring", "none",
        note="catalog sizes start at M10; included in --scope all",
        include_in_core=False, include_in_extended=False,
    ),
    # Pins
    Selection(
        "iso2338", "ISO 2338 dowel pins", "ISO 2338",
        "dowel-pin", "diameter", "pin", "spread", 3,
    ),
    Selection(
        "iso8752", "ISO 8752 slotted spring pins", "ISO 8752",
        "slotted-spring-pin", "diameter", "pin", "spread", 3,
    ),
    Selection(
        "iso1234", "ISO 1234 cotter pins", "ISO 1234",
        "cotter-pin", "diameter", "pin", "none",
    ),
    # Threaded rods: no catalog standard designation, but standard metric
    # coarse-thread geometry. Labeled separately in the report.
    Selection(
        "rods", "Metric threaded rods (DIN 976-compatible)", None,
        "metric-threaded-rod", "thread", "rod", "anchors", 2,
        note="catalog record has no standard designation; verify as a secondary oracle",
    ),
]


def fetch_json(url: str, retries: int = 3) -> dict:
    # Prefer curl: some system Python builds ship an OpenSSL that cannot
    # negotiate the catalog's TLS endpoint.
    last_error: Exception | None = None
    for attempt in range(retries):
        try:
            if shutil.which("curl"):
                proc = subprocess.run(
                    ["curl", "-sSL", "--fail", "-A", USER_AGENT, url],
                    capture_output=True,
                    text=True,
                    timeout=120,
                    check=True,
                )
                return json.loads(proc.stdout)
            request = urllib.request.Request(
                url, headers={"User-Agent": USER_AGENT}
            )
            with urllib.request.urlopen(request, timeout=60) as response:
                return json.load(response)
        except Exception as exc:  # noqa: BLE001 - retry transient failures
            last_error = exc
            if attempt + 1 < retries:
                time.sleep(1.0 + attempt)
    raise RuntimeError(f"catalog request failed: {last_error}")


def fetch_items(params: dict) -> list[dict]:
    items: list[dict] = []
    page = 1
    while True:
        query = dict(params)
        query["pageSize"] = 500
        query["page"] = page
        url = f"{API}/parts?{urllib.parse.urlencode(query)}"
        data = fetch_json(url)
        items.extend(data.get("items", []))
        if not data.get("hasNextPage"):
            break
        page += 1
    return items


def fetch_record(part_id: str) -> dict:
    return fetch_json(f"{API}/parts/{part_id}")


def normalize_size(text: str) -> str:
    return text.strip().replace("p", ".").replace("P", ".")


def parse_size(record: dict, field: str) -> str | None:
    attributes = record.get("attributes", {})
    if field == "thread":
        raw = attributes.get("thread") or attributes.get("nominalSize") or ""
        match = re.match(r"\s*M\s*([0-9]+(?:\.[0-9]+)?)", str(raw), re.I)
        return f"M{normalize_size(match.group(1))}" if match else None
    if field == "diameter":
        raw = attributes.get("diameterMm")
        if raw is None:
            match = re.match(
                r"\s*D\s*([0-9]+(?:\.[0-9]+)?)", str(attributes.get("nominalSize", "")), re.I
            )
            raw = match.group(1) if match else None
        if raw is None:
            return None
        return f"D{normalize_size(str(raw))}"
    return None


def numeric_size(size: str) -> float | None:
    match = re.match(r"[MD]\s*([0-9]+(?:\.[0-9]+)?)", size)
    return float(match.group(1)) if match else None


def size_in_scope(size: str, field: str, scope: str) -> bool:
    if scope == "all":
        return True
    if field == "thread":
        return size in SCOPE_SIZES[scope]
    value = numeric_size(size)
    if value is None:
        return False
    return value in SCOPE_DIAMETERS[scope]


def standard_status(record: dict, selection: Selection) -> str:
    if selection.key == "bearings":
        return (
            "no catalog standard designation; ISO 15 boundary dimensions "
            "verified against the library table"
        )
    if selection.key == "nonstandard":
        return "nonstandardized catalog oracle; not a normative reference"
    if selection.key == "explicit":
        return "explicit catalog record; verify standard/provenance before use"
    if selection.standard is None:
        return (
            "no catalog standard designation; metric coarse thread per "
            "ISO 261/ISO 68-1 (DIN 976-compatible)"
        )
    attributes = record.get("attributes", {})
    representation = attributes.get("threadRepresentation") or attributes.get(
        "geometryRepresentation"
    )
    if representation:
        return f"catalog standard exact; geometry note: {representation}"
    return "catalog standard exact"


def representative_lengths(records: list[dict], selection: Selection,
                           lengths_per_size: int, scope: str) -> list[dict]:
    """Pick deterministic representative records from one size group."""
    by_length: dict[float, dict] = {}
    for record in records:
        attributes = record.get("attributes", {})
        length = attributes.get("lengthMm")
        if length is None:
            continue
        by_length.setdefault(float(length), record)

    # Nuts, washers, rings, and cotter pins are selected one per size. Some
    # have no length attribute at all; keep the first record for that size.
    if selection.length_mode == "none":
        if not by_length:
            return records[:1]
        return [by_length[min(by_length)]]
    if not by_length:
        return []

    lengths = sorted(by_length)
    if scope == "all" or selection.length_mode == "all":
        return [by_length[length] for length in lengths]

    if selection.length_mode == "spread":
        count = max(1, lengths_per_size)
        if len(lengths) <= count:
            selected = lengths
        elif count == 1:
            selected = [lengths[len(lengths) // 2]]
        else:
            indices = {
                round(i * (len(lengths) - 1) / (count - 1))
                for i in range(count)
            }
            selected = [lengths[i] for i in sorted(indices)]
        return [by_length[length] for length in selected]

    # anchor mode
    size = parse_size(records[0], selection.size_field or "thread") or ""
    anchors = PREFERRED_LENGTHS.get(size, [])
    count = max(1, lengths_per_size)
    chosen: list[float] = []
    for anchor in anchors[:count]:
        best = min(lengths, key=lambda length: (abs(length - anchor), length))
        if best not in chosen:
            chosen.append(best)
    if len(chosen) < count:
        remaining = [length for length in lengths if length not in chosen]
        need = count - len(chosen)
        if remaining:
            if len(remaining) <= need:
                chosen.extend(remaining)
            elif need == 1:
                chosen.append(remaining[len(remaining) // 2])
            else:
                indices = {
                    round(i * (len(remaining) - 1) / (need - 1))
                    for i in range(need)
                }
                chosen.extend(remaining[i] for i in sorted(indices))
    return [by_length[length] for length in sorted(set(chosen))]


def build_standard_plan(selection: Selection, scope: str,
                        lengths_per_size: int) -> tuple[list[dict], list[str]]:
    params: dict[str, str] = {}
    if selection.standard is not None:
        params["standard"] = selection.standard
    if selection.family is not None:
        params["family"] = selection.family
    records = fetch_items(params)

    wanted_standard = (selection.standard or "").strip().lower()
    filtered: list[dict] = []
    for record in records:
        if selection.standard is not None:
            actual = ((record.get("standard") or {}).get("designation") or "").strip().lower()
            if actual != wanted_standard:
                continue
        if selection.family is not None and record.get("family") != selection.family:
            continue
        size = parse_size(record, selection.size_field or "thread")
        if size is None or not size_in_scope(size, selection.size_field or "thread", scope):
            continue
        filtered.append(record)

    # Prefer canonical catalog IDs where a family also contains generic
    # simplified variants (for example ISO 4762 and generic socket head
    # screws). The generic record is still used when it is the only one for a
    # requested size/length.
    if selection.id_prefix is not None:
        filtered.sort(
            key=lambda record: (
                0 if record["id"].startswith(selection.id_prefix) else 1,
                record["id"],
            )
        )

    by_size: dict[str, list[dict]] = {}
    for record in filtered:
        size = parse_size(record, selection.size_field or "thread")
        if size is not None:
            by_size.setdefault(size, []).append(record)

    planned: list[dict] = []
    missing: list[str] = []
    target_sizes: list[str] | None
    if scope == "all":
        target_sizes = None
    elif selection.size_field == "diameter":
        target_sizes = [f"D{value:g}" for value in SCOPE_DIAMETERS[scope]]
    else:
        target_sizes = list(SCOPE_SIZES[scope])

    for size, group in sorted(by_size.items(), key=lambda item: numeric_size(item[0]) or 0.0):
        chosen = representative_lengths(group, selection, lengths_per_size, scope)
        if not chosen:
            missing.append(f"{selection.key}: {size} has no usable length")
            continue
        for record in chosen:
            planned.append(
                {
                    "selection": selection.key,
                    "selection_label": selection.label,
                    "record": record,
                    "size": size,
                    "length_mm": (record.get("attributes") or {}).get("lengthMm"),
                }
            )

    if target_sizes is not None:
        for size in target_sizes:
            if size not in by_size:
                missing.append(f"{selection.key}: no catalog record for {size}")
    return planned, missing


def build_bearing_plan() -> tuple[list[dict], list[str]]:
    planned: list[dict] = []
    missing: list[str] = []
    for part_id in BEARING_IDS:
        try:
            record = fetch_record(part_id)
        except Exception as exc:  # noqa: BLE001 - report missing fixture
            missing.append(f"bearings: {part_id} ({exc})")
            continue
        attributes = record.get("attributes", {})
        planned.append(
            {
                "selection": "bearings",
                "selection_label": "Standard radial ball bearings (ISO 15 boundary)",
                "record": record,
                "size": attributes.get("bearingCode") or part_id,
                "length_mm": attributes.get("widthMm"),
            }
        )
    return planned, missing


def build_nonstandard_plan() -> tuple[list[dict], list[str]]:
    planned: list[dict] = []
    missing: list[str] = []
    for part_id in NONSTANDARD_IDS:
        try:
            record = fetch_record(part_id)
        except Exception as exc:  # noqa: BLE001 - optional fixture
            missing.append(f"nonstandard: {part_id} ({exc})")
            continue
        planned.append(
            {
                "selection": "nonstandard",
                "selection_label": "Non-standardized gear/profile oracles",
                "record": record,
                "size": part_id,
                "length_mm": None,
            }
        )
    return planned, missing


def selection_matches(selection: Selection, wanted: list[str]) -> bool:
    if not wanted:
        return True
    needles = {value.strip().lower() for value in wanted}
    return (
        selection.key.lower() in needles
        or selection.label.lower() in needles
        or (selection.standard or "").strip().lower() in needles
    )


def plan_for_args(args: argparse.Namespace) -> tuple[list[dict], list[str]]:
    if args.part:
        planned: list[dict] = []
        missing: list[str] = []
        for part_id in args.part:
            try:
                record = fetch_record(part_id)
            except Exception as exc:  # noqa: BLE001 - explicit request
                missing.append(f"explicit: {part_id} ({exc})")
                continue
            planned.append(
                {
                    "selection": "explicit",
                    "selection_label": "Explicit --part requests",
                    "record": record,
                    "size": (record.get("attributes") or {}).get("nominalSize", part_id),
                    "length_mm": (record.get("attributes") or {}).get("lengthMm"),
                }
            )
        return planned, missing

    planned = []
    missing: list[str] = []
    for selection in SELECTIONS:
        if not selection_matches(selection, args.selection):
            continue
        explicitly_wanted = bool(args.selection)
        if not explicitly_wanted:
            if args.scope == "core" and not selection.include_in_core:
                continue
            if args.scope == "extended" and not selection.include_in_extended:
                continue
        if selection.key == "rods" and not args.include_rods:
            continue
        lengths = (
            args.lengths_per_size
            if args.lengths_per_size is not None
            else selection.default_lengths
        )
        selection_plan, selection_missing = build_standard_plan(
            selection, args.scope, lengths
        )
        planned.extend(selection_plan)
        missing.extend(selection_missing)

    if args.include_bearings and selection_matches(
        Selection("bearings", "Standard radial ball bearings", None, None, None,
                  "bearing", "none"), args.selection
    ):
        bearing_plan, bearing_missing = build_bearing_plan()
        planned.extend(bearing_plan)
        missing.extend(bearing_missing)

    nonstandard_selector = Selection(
        "nonstandard", "Non-standardized gear/profile oracles", None, None,
        None, "mixed", "none",
    )
    if args.include_nonstandard and selection_matches(
        nonstandard_selector, args.selection
    ):
        nonstandard_plan, nonstandard_missing = build_nonstandard_plan()
        planned.extend(nonstandard_plan)
        missing.extend(nonstandard_missing)

    # Deduplicate by catalog ID, keeping the first selection that found it.
    deduped: list[dict] = []
    seen: set[str] = set()
    for item in planned:
        part_id = item["record"]["id"]
        if part_id in seen:
            continue
        seen.add(part_id)
        deduped.append(item)
    return deduped, missing


def _lfs_download_once(oid: str, size: int, destination: Path) -> None:
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


def lfs_download(oid: str, size: int, destination: Path, retries: int = 3) -> None:
    """Fetch a Git LFS object through the signed batch API, with retries."""
    last_error: Exception | None = None
    for attempt in range(retries):
        try:
            _lfs_download_once(oid, size, destination)
            return
        except Exception as exc:  # noqa: BLE001 - retry transient failures
            last_error = exc
            if destination.exists():
                destination.unlink()
            if attempt + 1 < retries:
                time.sleep(1.0 + attempt)
    raise RuntimeError(f"LFS download failed after {retries} attempts: {last_error}")


def download(url: str, destination: Path, oid: str, size: int,
             retries: int = 3) -> None:
    lfs_error: Exception | None = None
    try:
        lfs_download(oid, size, destination, retries)
        return
    except Exception as exc:  # noqa: BLE001 - try the direct media URL
        lfs_error = exc
    last_error: Exception | None = None
    for attempt in range(retries):
        try:
            if shutil.which("curl"):
                subprocess.run(
                    [
                        "curl",
                        "-sSL",
                        "--fail",
                        "-A",
                        USER_AGENT,
                        url,
                        "-o",
                        str(destination),
                    ],
                    timeout=600,
                    check=True,
                )
                return
            request = urllib.request.Request(
                url, headers={"User-Agent": USER_AGENT}
            )
            with urllib.request.urlopen(request, timeout=300) as response, destination.open(
                "wb"
            ) as out:
                out.write(response.read())
            return
        except Exception as exc:  # noqa: BLE001 - retry transient failures
            last_error = exc
            if destination.exists():
                destination.unlink()
            if attempt + 1 < retries:
                time.sleep(1.0 + attempt)
    raise RuntimeError(
        f"download failed; LFS: {lfs_error}; direct URL: {last_error}"
    )


def file_sha256(path: Path) -> tuple[str, int]:
    digest = hashlib.sha256()
    size = 0
    with path.open("rb") as data:
        while True:
            chunk = data.read(1 << 16)
            if not chunk:
                break
            digest.update(chunk)
            size += len(chunk)
    return digest.hexdigest(), size


def write_sidecars(destination: Path, sha256: str, size: int) -> None:
    destination.with_suffix(destination.suffix + ".sha256").write_text(sha256 + "\n")
    destination.with_suffix(destination.suffix + ".bytes").write_text(f"{size}\n")


def print_selection_table() -> None:
    print(f"{'key':14s} {'sizes':8s} {'kind':8s} selection")
    print("-" * 100)
    for selection in SELECTIONS:
        sizes = (
            "M2-M5"
            if selection.size_field == "thread"
            else "D1-D5"
            if selection.size_field == "diameter"
            else "n/a"
        )
        print(
            f"{selection.key:14s} {sizes:8s} {selection.kind:8s} "
            f"{selection.label}"
        )
    print(f"{'bearings':14s} {'n/a':8s} {'bearing':8s} Common radial ball bearings")
    print(f"{'nonstandard':14s} {'n/a':8s} {'mixed':8s} Optional gear/profile oracles")


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--out", help="output directory for downloaded STEP files")
    parser.add_argument(
        "--scope",
        choices=sorted(SCOPE_SIZES),
        default="core",
        help="core = M2-M5; extended = M2-M8; all = every catalog size/length",
    )
    parser.add_argument(
        "--lengths-per-size",
        type=int,
        default=None,
        help="override representative lengths per screw size (default from selection)",
    )
    parser.add_argument(
        "--selection",
        action="append",
        help="limit to a selection key, standard designation, or label",
    )
    parser.add_argument(
        "--part", action="append", help="fetch only these explicit catalog IDs"
    )
    parser.add_argument(
        "--include-rods",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="include metric threaded rods (default: yes)",
    )
    parser.add_argument(
        "--include-bearings",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="include common radial ball bearings (default: yes)",
    )
    parser.add_argument(
        "--include-nonstandard",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="include the clearly labeled gear/profile oracles (default: yes)",
    )
    parser.add_argument(
        "--retries", type=int, default=3, help="attempts per file (default: 3)"
    )
    parser.add_argument(
        "--delay",
        type=float,
        default=0.2,
        help="seconds between files to avoid rate limiting (default: 0.2)",
    )
    parser.add_argument("--force", action="store_true", help="re-download existing files")
    parser.add_argument(
        "--max-files",
        type=int,
        default=600,
        help="safety cap on the planned file count (0 = no cap)",
    )
    parser.add_argument(
        "--allow-large",
        action="store_true",
        help="allow a plan above --max-files (use with --scope all)",
    )
    parser.add_argument("--strict", action="store_true", help="fail on missing sizes")
    parser.add_argument(
        "--list", action="store_true", help="print the planned files and exit"
    )
    parser.add_argument(
        "--list-selections", action="store_true", help="print selection keys and exit"
    )
    args = parser.parse_args()

    if args.list_selections:
        print_selection_table()
        return 0

    planned, missing = plan_for_args(args)
    if not planned and not missing:
        print("No items selected.", file=sys.stderr)
        return 2

    count_by_selection: dict[str, int] = {}
    for item in planned:
        count_by_selection[item["selection"]] = (
            count_by_selection.get(item["selection"], 0) + 1
        )

    print(f"Scope: {args.scope}")
    for key in sorted(count_by_selection):
        print(f"  {key:14s} {count_by_selection[key]:4d}")
    print(f"  {'TOTAL':14s} {len(planned):4d}")
    if missing:
        print(f"  missing/warnings: {len(missing)}")
        for message in missing[:12]:
            print(f"    - {message}")
        if len(missing) > 12:
            print(f"    - ... {len(missing) - 12} more (see fetch-report.json)")
    if args.list:
        for item in planned:
            record = item["record"]
            print(f"{record['id']}  [{item['selection']}]")
        return 0

    if args.max_files and len(planned) > args.max_files and not args.allow_large:
        print(
            f"Refusing to download {len(planned)} files (cap {args.max_files}). "
            "Use --allow-large or raise --max-files.",
            file=sys.stderr,
        )
        return 3

    if not args.out:
        print("--out is required unless --list is used.", file=sys.stderr)
        return 2

    out_dir = Path(args.out).expanduser().resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    report = {
        "catalog": "step.parts",
        "catalog_commit": CATALOG_COMMIT,
        "api": API,
        "scope": args.scope,
        "source": "open-source step.parts corpus",
        "counts": {
            "planned": len(planned),
            "downloaded": 0,
            "cached": 0,
            "failed": 0,
            "missing": len(missing),
        },
        "missing": missing,
        "items": [],
        "failures": [],
    }

    for index, item in enumerate(planned, start=1):
        record = item["record"]
        part_id = record["id"]
        step_url = record["stepUrl"]
        expected_sha = record["sha256"]
        expected_size = record["byteSize"]
        filename = f"{part_id}.step"
        destination = out_dir / filename
        attributes = record.get("attributes", {})
        entry = {
            "group": item["selection"],
            "selection": item["selection_label"],
            "id": part_id,
            "name": record.get("name"),
            "standard": record.get("standard"),
            "standard_status": standard_status(record, next(
                (s for s in SELECTIONS if s.key == item["selection"]),
                Selection(item["selection"], item["selection_label"], None, None,
                          None, "mixed", "none"),
            )),
            "family": record.get("family"),
            "size": item["size"],
            "length_mm": item["length_mm"],
            "attributes": attributes,
            "source_page": record.get("pageUrl"),
            "download_url": step_url,
            "filename": filename,
            "sha256": expected_sha,
            "byte_size": expected_size,
            "source": "open-source step.parts corpus",
        }
        temp: Path | None = None
        try:
            if destination.exists() and not args.force:
                actual_sha, actual_size = file_sha256(destination)
                if actual_sha == expected_sha and actual_size == expected_size:
                    write_sidecars(destination, actual_sha, actual_size)
                    entry.update(
                        {
                            "status": "cached",
                            "checksum_verified": True,
                        }
                    )
                    report["counts"]["cached"] += 1
                    report["items"].append(entry)
                    print(f"[{index}/{len(planned)}] cached  {filename}")
                    continue
            temp = destination.with_suffix(destination.suffix + ".part")
            if temp.exists():
                temp.unlink()
            download(
                step_url, temp, expected_sha, expected_size, retries=args.retries
            )
            actual_sha, actual_size = file_sha256(temp)
            if actual_sha != expected_sha:
                raise RuntimeError(
                    f"sha256 mismatch: {actual_sha} != {expected_sha}"
                )
            if actual_size != expected_size:
                raise RuntimeError(
                    f"byte size mismatch: {actual_size} != {expected_size}"
                )
            if destination.exists():
                destination.unlink()
            temp.replace(destination)
            write_sidecars(destination, actual_sha, actual_size)
            if args.delay > 0:
                time.sleep(args.delay)
            entry.update(
                {
                    "status": "downloaded",
                    "checksum_verified": True,
                }
            )
            report["counts"]["downloaded"] += 1
            report["items"].append(entry)
            print(
                f"[{index}/{len(planned)}] OK      {filename} "
                f"{actual_size} bytes sha256={actual_sha}"
            )
        except Exception as exc:  # noqa: BLE001 - development helper
            if temp is not None and temp.exists():
                temp.unlink()
            entry.update({"status": "failed", "checksum_verified": False,
                          "error": str(exc)})
            report["counts"]["failed"] += 1
            report["failures"].append({"id": part_id, "error": str(exc)})
            report["items"].append(entry)
            print(f"[{index}/{len(planned)}] FAIL    {part_id}: {exc}", file=sys.stderr)

    (out_dir / "fetch-report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(
        f"Summary: planned={report['counts']['planned']} "
        f"downloaded={report['counts']['downloaded']} "
        f"cached={report['counts']['cached']} "
        f"failed={report['counts']['failed']} "
        f"missing={report['counts']['missing']}"
    )
    print(f"wrote {out_dir / 'fetch-report.json'}")
    if report["counts"]["failed"]:
        return 1
    if args.strict and missing:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
