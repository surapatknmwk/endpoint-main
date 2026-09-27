#!/usr/bin/env python3
"""
district_distance_batch.py
===========================

Batch pipeline that builds a district-to-district (อำเภอ) straight-line
(Haversine) distance table for the endpoint DB.

Four stages, runnable separately or together:

  1. sync-districts     Fetch official Thai district boundaries (GeoJSON),
                         compute each district's centroid (lat/lng), and
                         upsert province + district master data.
  2. compute-distances  Compute the Haversine distance (km) between every
                         pair of districts in scope and upsert into the
                         dedicated `district_distances` table.
  3. sync-subdistricts        Same idea as (1) but for ตำบล (subdistrict)
                               boundaries -> upserts subdistrict + lat/lng.
  4. compute-subdistrict-distances   Same idea as (2) but for subdistricts.
                               Scope is intentionally narrower: only pairs
                               within the SAME PROVINCE are computed (a full
                               cross-province matrix for ~1,000 subdistricts
                               would be ~1M rows for little practical value).

Design goals (per request):
  - Easy to run: single file, stdlib + 2 small deps (requests, psycopg2).
  - Resumable / crash-safe: every DB write is an UPSERT (ON CONFLICT), so
    re-running after a crash never duplicates data. A checkpoint file also
    lets a long run skip work that's already done, instead of recomputing
    everything from scratch.
  - Targeted updates: --provinces / --districts / --subdistricts let you
    (re)run the pipeline for just what you need, instead of the whole set.

Usage
-----
    pip install -r requirements.txt
    export DB_HOST=localhost DB_PORT=5433 DB_NAME=endpoint_db \
           DB_USER=admin DB_PASSWORD=admin123      # matches db/docker-compose.yml

    # full pipeline at district level, default province list (see DEFAULT_PROVINCES below)
    python3 district_distance_batch.py run-all

    # full pipeline including subdistrict level
    python3 district_distance_batch.py run-all --with-subdistricts

    # only sync master data (province/district + lat/lng)
    python3 district_distance_batch.py sync-districts

    # only (re)compute distances for specific districts (by code, e.g. after
    # fixing a coordinate) -- leaves everything else untouched
    python3 district_distance_batch.py compute-distances --districts 4701,4702

    # subdistrict level: sync + compute (within-province pairs only)
    python3 district_distance_batch.py sync-subdistricts
    python3 district_distance_batch.py compute-subdistrict-distances

    # subdistrict level, targeted re-sync for specific subdistricts
    python3 district_distance_batch.py sync-subdistricts --subdistricts 470101,470102

    # scope everything to a subset of provinces
    python3 district_distance_batch.py run-all --provinces "สกลนคร,ร้อยเอ็ด"

    # force full recompute, ignoring the checkpoint file
    python3 district_distance_batch.py compute-distances --force

    # start over cleanly
    python3 district_distance_batch.py compute-distances --reset-checkpoint
"""

from __future__ import annotations

import argparse
import json
import math
import os
import sys
import time
import unicodedata
from pathlib import Path

try:
    import requests
except ImportError:
    print("Missing dependency 'requests'. Run: pip install -r requirements.txt", file=sys.stderr)
    sys.exit(1)

try:
    import psycopg2
    import psycopg2.extras
except ImportError:
    print("Missing dependency 'psycopg2-binary'. Run: pip install -r requirements.txt", file=sys.stderr)
    sys.exit(1)


# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

SCRIPT_DIR = Path(__file__).resolve().parent
CACHE_DIR = SCRIPT_DIR / ".cache"
CACHE_DIR.mkdir(exist_ok=True)

GEOJSON_URL = "https://raw.githubusercontent.com/chingchai/OpenGISData-Thailand/master/districts.geojson"
GEOJSON_CACHE_PATH = CACHE_DIR / "districts.geojson"

SUBDISTRICT_GEOJSON_URL = "https://raw.githubusercontent.com/chingchai/OpenGISData-Thailand/master/subdistricts.geojson"
SUBDISTRICT_GEOJSON_CACHE_PATH = CACHE_DIR / "subdistricts.geojson"

SYNC_CHECKPOINT_PATH = CACHE_DIR / "sync_districts.checkpoint.json"
DISTANCE_CHECKPOINT_PATH = CACHE_DIR / "compute_distances.checkpoint.json"

SUBDISTRICT_SYNC_CHECKPOINT_PATH = CACHE_DIR / "sync_subdistricts.checkpoint.json"
SUBDISTRICT_DISTANCE_CHECKPOINT_PATH = CACHE_DIR / "compute_subdistrict_distances.checkpoint.json"

# 8 จังหวัดตามที่ระบุ
DEFAULT_PROVINCES = [
    "สกลนคร",
    "ร้อยเอ็ด",
    "อุบลราชธานี",
    "กาฬสินธุ์",
    "มหาสารคาม",
    "นครพนม",
    "อุดรธานี",
    "บึงกาฬ",
]

DB_CONFIG = {
    "host": os.environ.get("DB_HOST", "localhost"),
    "port": os.environ.get("DB_PORT", "5433"),
    "dbname": os.environ.get("DB_NAME", "endpoint_db"),
    "user": os.environ.get("DB_USER", "admin"),
    "password": os.environ.get("DB_PASSWORD", "admin123"),
}


def get_connection():
    return psycopg2.connect(**DB_CONFIG)


# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------

def log(msg: str) -> None:
    ts = time.strftime("%H:%M:%S")
    print(f"[{ts}] {msg}", flush=True)


def load_checkpoint(path: Path) -> dict:
    if path.exists():
        try:
            return json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            log(f"WARNING: checkpoint file {path} is corrupt, ignoring it")
    return {"done": []}


def save_checkpoint(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


def normalize_thai(name: str) -> str:
    """Loose-match key: NFC-normalize then sort codepoints, so names that
    differ only by combining-mark order (a common Thai typo, e.g. กาฬสินธ์ุ
    vs กาฬสินธุ์) still match."""
    nfc = unicodedata.normalize("NFC", name.strip())
    return "".join(sorted(nfc))


# ---------------------------------------------------------------------------
# Geometry: polygon centroid
# ---------------------------------------------------------------------------

def _ring_centroid(ring):
    """Shoelace centroid + signed area for a single closed ring of [lng, lat]."""
    area = cx = cy = 0.0
    n = len(ring)
    for i in range(n - 1):
        x0, y0 = ring[i][0], ring[i][1]
        x1, y1 = ring[i + 1][0], ring[i + 1][1]
        cross = x0 * y1 - x1 * y0
        area += cross
        cx += (x0 + x1) * cross
        cy += (y0 + y1) * cross
    area *= 0.5
    if abs(area) < 1e-12:
        xs = [p[0] for p in ring]
        ys = [p[1] for p in ring]
        return sum(xs) / len(xs), sum(ys) / len(ys), 0.0
    return cx / (6 * area), cy / (6 * area), abs(area)


def geometry_centroid(geometry: dict) -> tuple[float, float]:
    """Area-weighted centroid across all parts of a Polygon/MultiPolygon.
    Returns (lat, lng). Holes are ignored (exterior ring only) -- fine for
    a straight-line distance approximation."""
    gtype = geometry["type"]
    if gtype == "Polygon":
        parts = [geometry["coordinates"]]
    elif gtype == "MultiPolygon":
        parts = geometry["coordinates"]
    else:
        raise ValueError(f"Unsupported geometry type: {gtype}")

    total_area = 0.0
    wx = wy = 0.0
    for poly in parts:
        exterior = poly[0]
        cx, cy, area = _ring_centroid(exterior)
        if area == 0.0:
            continue
        wx += cx * area
        wy += cy * area
        total_area += area

    if total_area == 0.0:
        # degenerate geometry: fall back to a flat average of all points
        pts = [pt for poly in parts for pt in poly[0]]
        lng = sum(p[0] for p in pts) / len(pts)
        lat = sum(p[1] for p in pts) / len(pts)
        return lat, lng

    lng, lat = wx / total_area, wy / total_area
    return lat, lng


# ---------------------------------------------------------------------------
# Haversine
# ---------------------------------------------------------------------------

EARTH_RADIUS_KM = 6371.0088


def haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dlambda / 2) ** 2
    return 2 * EARTH_RADIUS_KM * math.atan2(math.sqrt(a), math.sqrt(1 - a))


# ---------------------------------------------------------------------------
# GeoJSON fetch + filter
# ---------------------------------------------------------------------------

def fetch_districts_geojson(force_refresh: bool = False) -> dict:
    if GEOJSON_CACHE_PATH.exists() and not force_refresh:
        log(f"Using cached {GEOJSON_CACHE_PATH.name} (use --refresh-source to re-download)")
        return json.loads(GEOJSON_CACHE_PATH.read_text(encoding="utf-8"))

    log(f"Downloading district boundaries from {GEOJSON_URL} ...")
    resp = requests.get(GEOJSON_URL, timeout=120)
    resp.raise_for_status()
    data = resp.json()
    GEOJSON_CACHE_PATH.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
    log(f"Downloaded {len(data['features'])} district features, cached to {GEOJSON_CACHE_PATH}")
    return data


def fetch_subdistricts_geojson(force_refresh: bool = False) -> dict:
    if SUBDISTRICT_GEOJSON_CACHE_PATH.exists() and not force_refresh:
        log(f"Using cached {SUBDISTRICT_GEOJSON_CACHE_PATH.name} (use --refresh-source to re-download)")
        return json.loads(SUBDISTRICT_GEOJSON_CACHE_PATH.read_text(encoding="utf-8"))

    log(f"Downloading subdistrict boundaries from {SUBDISTRICT_GEOJSON_URL} ... (this file is ~7,300 features, may take a while)")
    resp = requests.get(SUBDISTRICT_GEOJSON_URL, timeout=300)
    resp.raise_for_status()
    data = resp.json()
    SUBDISTRICT_GEOJSON_CACHE_PATH.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
    log(f"Downloaded {len(data['features'])} subdistrict features, cached to {SUBDISTRICT_GEOJSON_CACHE_PATH}")
    return data


def filter_features_by_province(geojson: dict, province_names: list[str]) -> list[dict]:
    wanted = {normalize_thai(p): p for p in province_names}
    matched_keys = set()
    features = []
    for feature in geojson["features"]:
        props = feature["properties"]
        key = normalize_thai(props["pro_th"])
        if key in wanted:
            matched_keys.add(key)
            features.append(feature)

    missing = [orig for key, orig in wanted.items() if key not in matched_keys]
    if missing:
        raise SystemExit(
            "ไม่พบจังหวัดต่อไปนี้ในข้อมูลต้นทาง (ตรวจสอบการสะกดชื่อ): "
            + ", ".join(missing)
        )
    return features


# ---------------------------------------------------------------------------
# DB upserts
# ---------------------------------------------------------------------------

def upsert_province(cur, code: str, name: str) -> int:
    cur.execute(
        """
        INSERT INTO provinces (code, name, created_at, updated_at)
        VALUES (%s, %s, now(), now())
        ON CONFLICT (code) DO UPDATE SET
            name = EXCLUDED.name,
            updated_at = now()
        RETURNING province_id
        """,
        (code, name),
    )
    return cur.fetchone()[0]


def upsert_district(cur, province_id: int, code: str, name: str, lat: float, lng: float) -> int:
    cur.execute(
        """
        INSERT INTO districts (province_id, code, name, lat, lng, created_at, updated_at)
        VALUES (%s, %s, %s, %s, %s, now(), now())
        ON CONFLICT (code) DO UPDATE SET
            province_id = EXCLUDED.province_id,
            name = EXCLUDED.name,
            lat = EXCLUDED.lat,
            lng = EXCLUDED.lng,
            updated_at = now()
        RETURNING district_id
        """,
        (province_id, code, name, lat, lng),
    )
    return cur.fetchone()[0]


def upsert_distance(cur, origin_id: int, dest_id: int, distance_km: float) -> None:
    cur.execute(
        """
        INSERT INTO district_distances
            (origin_district_id, destination_district_id, distance_km, calc_method, created_at, updated_at)
        VALUES (%s, %s, %s, 'haversine', now(), now())
        ON CONFLICT (origin_district_id, destination_district_id) DO UPDATE SET
            distance_km = EXCLUDED.distance_km,
            calc_method = EXCLUDED.calc_method,
            updated_at = now()
        """,
        (origin_id, dest_id, round(distance_km, 2)),
    )


def upsert_subdistrict(cur, district_id: int, code: str, name: str, lat: float, lng: float) -> int:
    # NOTE: zip_code is intentionally left out of the column list so any
    # existing value (e.g. filled by db/subdistrict-zip-codes.sql) is never clobbered.
    cur.execute(
        """
        INSERT INTO subdistricts (district_id, code, name, lat, lng, created_at, updated_at)
        VALUES (%s, %s, %s, %s, %s, now(), now())
        ON CONFLICT (code) DO UPDATE SET
            district_id = EXCLUDED.district_id,
            name = EXCLUDED.name,
            lat = EXCLUDED.lat,
            lng = EXCLUDED.lng,
            updated_at = now()
        RETURNING subdistrict_id
        """,
        (district_id, code, name, lat, lng),
    )
    return cur.fetchone()[0]


def bulk_upsert_subdistrict_distances(cur, origin_id: int, pairs: list[tuple[int, float]]) -> None:
    """pairs: list of (destination_subdistrict_id, distance_km). One round-trip
    for all of an origin's destinations -- matters here because a within-province
    scope can still be a few hundred destinations per origin."""
    if not pairs:
        return
    values = [(origin_id, dest_id, round(km, 2)) for dest_id, km in pairs]
    psycopg2.extras.execute_values(
        cur,
        """
        INSERT INTO subdistrict_distances
            (origin_subdistrict_id, destination_subdistrict_id, distance_km, calc_method, created_at, updated_at)
        VALUES %s
        ON CONFLICT (origin_subdistrict_id, destination_subdistrict_id) DO UPDATE SET
            distance_km = EXCLUDED.distance_km,
            calc_method = EXCLUDED.calc_method,
            updated_at = now()
        WHERE subdistrict_distances.google_fetched = false  -- อย่าทับระยะถนนที่เคยเรียกจาก Google แล้ว
        """,
        values,
        template="(%s, %s, %s, 'haversine', now(), now())",
    )


# ---------------------------------------------------------------------------
# Subcommand: sync-districts
# ---------------------------------------------------------------------------

def cmd_sync_districts(args) -> int:
    geojson = fetch_districts_geojson(force_refresh=args.refresh_source)
    features = filter_features_by_province(geojson, args.provinces)

    if args.districts:
        wanted_codes = set(args.districts)
        features = [f for f in features if f["properties"]["amp_code"] in wanted_codes]
        found_codes = {f["properties"]["amp_code"] for f in features}
        missing = wanted_codes - found_codes
        if missing:
            log(f"WARNING: district code(s) not found in source data: {', '.join(sorted(missing))}")

    log(f"{len(features)} district(s) in scope")

    checkpoint = load_checkpoint(SYNC_CHECKPOINT_PATH)
    done = set(checkpoint.get("done", []))
    if args.force or args.districts:
        # explicit target or --force: always (re)process, ignore checkpoint
        pending = features
    else:
        pending = [f for f in features if f["properties"]["amp_code"] not in done]
        skipped = len(features) - len(pending)
        if skipped:
            log(f"Skipping {skipped} already-synced district(s) (use --force to redo)")

    conn = get_connection()
    conn.autocommit = False
    province_id_cache: dict[str, int] = {}
    ok = 0
    failed = []
    try:
        with conn.cursor() as cur:
            for feature in pending:
                props = feature["properties"]
                amp_code, amp_th = props["amp_code"], props["amp_th"]
                pro_code, pro_th = props["pro_code"], props["pro_th"]
                try:
                    if pro_code not in province_id_cache:
                        province_id_cache[pro_code] = upsert_province(cur, pro_code, pro_th)
                    lat, lng = geometry_centroid(feature["geometry"])
                    upsert_district(cur, province_id_cache[pro_code], amp_code, amp_th, lat, lng)
                    conn.commit()
                    done.add(amp_code)
                    ok += 1
                    log(f"  OK  {pro_th} / {amp_th} ({amp_code})  lat={lat:.5f} lng={lng:.5f}")
                except Exception as exc:  # noqa: BLE001 - want to keep going and report at the end
                    conn.rollback()
                    failed.append((amp_code, amp_th, str(exc)))
                    log(f"  FAIL {pro_th} / {amp_th} ({amp_code}): {exc}")
                finally:
                    save_checkpoint(SYNC_CHECKPOINT_PATH, {"done": sorted(done)})
    finally:
        conn.close()

    log(f"sync-districts done: {ok} upserted, {len(failed)} failed")
    if failed:
        log("Failed districts (rerun the same command to retry just these):")
        for code, name, err in failed:
            log(f"  - {code} {name}: {err}")
        return 1
    return 0


# ---------------------------------------------------------------------------
# Subcommand: sync-subdistricts
# ---------------------------------------------------------------------------

def cmd_sync_subdistricts(args) -> int:
    geojson = fetch_subdistricts_geojson(force_refresh=args.refresh_source)
    features = filter_features_by_province(geojson, args.provinces)

    if args.districts:
        wanted_districts = set(args.districts)
        features = [f for f in features if f["properties"]["amp_code"] in wanted_districts]

    if args.subdistricts:
        wanted_codes = set(args.subdistricts)
        features = [f for f in features if f["properties"]["tam_code"] in wanted_codes]
        found_codes = {f["properties"]["tam_code"] for f in features}
        missing = wanted_codes - found_codes
        if missing:
            log(f"WARNING: subdistrict code(s) not found in source data: {', '.join(sorted(missing))}")

    log(f"{len(features)} subdistrict(s) in scope")

    checkpoint = load_checkpoint(SUBDISTRICT_SYNC_CHECKPOINT_PATH)
    done = set(checkpoint.get("done", []))
    explicit = args.force or args.districts or args.subdistricts
    if explicit:
        pending = features
    else:
        pending = [f for f in features if f["properties"]["tam_code"] not in done]
        skipped = len(features) - len(pending)
        if skipped:
            log(f"Skipping {skipped} already-synced subdistrict(s) (use --force to redo)")

    conn = get_connection()
    conn.autocommit = False
    district_id_cache: dict[str, int | None] = {}
    ok = 0
    failed = []
    try:
        with conn.cursor() as cur:
            for feature in pending:
                props = feature["properties"]
                tam_code, tam_th = props["tam_code"], props["tam_th"]
                amp_code, amp_th = props["amp_code"], props["amp_th"]
                try:
                    if amp_code not in district_id_cache:
                        cur.execute("SELECT district_id FROM districts WHERE code = %s", (amp_code,))
                        row = cur.fetchone()
                        district_id_cache[amp_code] = row[0] if row else None
                    district_id = district_id_cache[amp_code]
                    if district_id is None:
                        raise RuntimeError(
                            f"parent district {amp_code} ({amp_th}) not found -- run sync-districts first"
                        )
                    lat, lng = geometry_centroid(feature["geometry"])
                    upsert_subdistrict(cur, district_id, tam_code, tam_th, lat, lng)
                    conn.commit()
                    done.add(tam_code)
                    ok += 1
                    log(f"  OK  {amp_th} / {tam_th} ({tam_code})  lat={lat:.5f} lng={lng:.5f}")
                except Exception as exc:  # noqa: BLE001
                    conn.rollback()
                    failed.append((tam_code, tam_th, str(exc)))
                    log(f"  FAIL {amp_th} / {tam_th} ({tam_code}): {exc}")
                finally:
                    save_checkpoint(SUBDISTRICT_SYNC_CHECKPOINT_PATH, {"done": sorted(done)})
    finally:
        conn.close()

    log(f"sync-subdistricts done: {ok} upserted, {len(failed)} failed")
    if failed:
        log("Failed subdistricts (rerun the same command to retry just these):")
        for code, name, err in failed:
            log(f"  - {code} {name}: {err}")
        return 1
    return 0


# ---------------------------------------------------------------------------
# Subcommand: compute-distances
# ---------------------------------------------------------------------------

def resolve_province_names(cur, province_names: list[str]) -> list[str]:
    """Match requested province names against what's actually in the DB,
    tolerating the same combining-mark typos as sync-districts (see
    normalize_thai). Raises if any requested province isn't found."""
    cur.execute("SELECT name FROM provinces")
    db_names = [row[0] for row in cur.fetchall()]
    db_by_key = {normalize_thai(n): n for n in db_names}

    resolved, missing = [], []
    for wanted in province_names:
        actual = db_by_key.get(normalize_thai(wanted))
        if actual is None:
            missing.append(wanted)
        else:
            resolved.append(actual)

    if missing:
        raise SystemExit(
            "ไม่พบจังหวัดต่อไปนี้ในตาราง provinces (รัน sync-districts ก่อน หรือตรวจสอบการสะกด): "
            + ", ".join(missing)
        )
    return resolved


def fetch_target_districts(cur, province_names: list[str], district_codes: list[str] | None):
    if district_codes:
        cur.execute(
            """
            SELECT d.district_id, d.code, d.name, d.lat, d.lng
            FROM districts d
            WHERE d.code = ANY(%s)
            ORDER BY d.code
            """,
            (district_codes,),
        )
    else:
        resolved_names = resolve_province_names(cur, province_names)
        cur.execute(
            """
            SELECT d.district_id, d.code, d.name, d.lat, d.lng
            FROM districts d
            JOIN provinces p ON p.province_id = d.province_id
            WHERE p.name = ANY(%s)
            ORDER BY d.code
            """,
            (resolved_names,),
        )
    rows = cur.fetchall()
    missing_coords = [r for r in rows if r[3] is None or r[4] is None]
    if missing_coords:
        # Don't hard-fail: a district with no lat/lng is usually a stale/mistyped
        # row left over from manual seed data (its code doesn't match the
        # authoritative source, so sync-districts can never "fix" it in place).
        # Skip it instead of blocking every other district in scope.
        names = ", ".join(f"{r[2]} ({r[1]})" for r in missing_coords)
        log(f"WARNING: skipping {len(missing_coords)} district(s) with no lat/lng "
            f"(stale code not in the source data, or sync-districts hasn't run for it): {names}")
        missing_ids = {r[0] for r in missing_coords}
        rows = [r for r in rows if r[0] not in missing_ids]
    return rows  # list of (district_id, code, name, lat, lng)


def cmd_compute_distances(args) -> int:
    if args.reset_checkpoint and DISTANCE_CHECKPOINT_PATH.exists():
        DISTANCE_CHECKPOINT_PATH.unlink()
        log("Checkpoint reset")

    conn = get_connection()
    try:
        with conn.cursor() as cur:
            districts = fetch_target_districts(cur, args.provinces, args.districts)
    finally:
        conn.close()

    if len(districts) < 2:
        log("Need at least 2 districts in scope to compute distances. Nothing to do.")
        return 0

    log(f"{len(districts)} district(s) in scope -> {len(districts) * (len(districts) - 1)} directed pairs")

    checkpoint = load_checkpoint(DISTANCE_CHECKPOINT_PATH)
    done_origins = set(checkpoint.get("done", []))

    # explicit --districts always reprocesses those origins even if checkpointed;
    # --force reprocesses everything
    explicit_codes = set(args.districts) if args.districts else set()
    if args.force:
        done_origins = set()

    conn = get_connection()
    conn.autocommit = False
    total_pairs = 0
    failed_origins = []
    start = time.time()
    try:
        with conn.cursor() as cur:
            for i, origin in enumerate(districts):
                origin_id, origin_code, origin_name, origin_lat, origin_lng = origin
                if origin_code in done_origins and origin_code not in explicit_codes:
                    continue
                try:
                    for dest in districts:
                        dest_id, dest_code = dest[0], dest[1]
                        if dest_id == origin_id:
                            continue
                        dist_km = haversine_km(float(origin_lat), float(origin_lng), float(dest[3]), float(dest[4]))
                        upsert_distance(cur, origin_id, dest_id, dist_km)
                        total_pairs += 1
                    conn.commit()
                    done_origins.add(origin_code)
                    log(f"  [{i + 1}/{len(districts)}] {origin_name} ({origin_code}): "
                        f"{len(districts) - 1} distance(s) upserted")
                except Exception as exc:  # noqa: BLE001
                    conn.rollback()
                    failed_origins.append((origin_code, origin_name, str(exc)))
                    log(f"  FAIL {origin_name} ({origin_code}): {exc}")
                finally:
                    save_checkpoint(DISTANCE_CHECKPOINT_PATH, {"done": sorted(done_origins)})
    finally:
        conn.close()

    elapsed = time.time() - start
    log(f"compute-distances done: {total_pairs} pair(s) upserted in {elapsed:.1f}s, "
        f"{len(failed_origins)} origin(s) failed")
    if failed_origins:
        log("Failed origins (rerun the same command to retry just these):")
        for code, name, err in failed_origins:
            log(f"  - {code} {name}: {err}")
        return 1
    return 0


# ---------------------------------------------------------------------------
# Subcommand: compute-subdistrict-distances
# ---------------------------------------------------------------------------
#
# Scope is narrower than the district level on purpose: only pairs within the
# SAME PROVINCE are computed (cross-district within a province is fine, e.g.
# a subdistrict in อำเภอ A and one in อำเภอ B of the same จังหวัด still get a
# distance). A full cross-province matrix for ~1,000 subdistricts across 8
# provinces would be roughly ~1M rows for little practical benefit.

def fetch_target_subdistricts(cur, province_names: list[str], district_codes: list[str] | None,
                               subdistrict_codes: list[str] | None):
    if subdistrict_codes:
        cur.execute(
            """
            SELECT s.subdistrict_id, s.code, s.name, s.lat, s.lng, d.province_id
            FROM subdistricts s
            JOIN districts d ON d.district_id = s.district_id
            WHERE s.code = ANY(%s)
            ORDER BY s.code
            """,
            (subdistrict_codes,),
        )
    elif district_codes:
        cur.execute(
            """
            SELECT s.subdistrict_id, s.code, s.name, s.lat, s.lng, d.province_id
            FROM subdistricts s
            JOIN districts d ON d.district_id = s.district_id
            WHERE d.code = ANY(%s)
            ORDER BY s.code
            """,
            (district_codes,),
        )
    else:
        resolved_names = resolve_province_names(cur, province_names)
        cur.execute(
            """
            SELECT s.subdistrict_id, s.code, s.name, s.lat, s.lng, d.province_id
            FROM subdistricts s
            JOIN districts d ON d.district_id = s.district_id
            JOIN provinces p ON p.province_id = d.province_id
            WHERE p.name = ANY(%s)
            ORDER BY s.code
            """,
            (resolved_names,),
        )
    rows = cur.fetchall()
    missing_coords = [r for r in rows if r[3] is None or r[4] is None]
    if missing_coords:
        # Same reasoning as fetch_target_districts: skip rather than hard-fail.
        # In practice this happens for hand-typed rows
        # whose code doesn't match the official DOPA code in the source geojson --
        # sync-subdistricts can never update them since ON CONFLICT (code) never
        # matches. They're effectively orphaned duplicates of a real subdistrict
        # that *did* sync correctly under its real code.
        names = ", ".join(f"{r[2]} ({r[1]})" for r in missing_coords)
        log(f"WARNING: skipping {len(missing_coords)} subdistrict(s) with no lat/lng "
            f"(stale code not in the source data, or sync-subdistricts hasn't run for it): {names}")
        missing_ids = {r[0] for r in missing_coords}
        rows = [r for r in rows if r[0] not in missing_ids]
    return rows  # list of (subdistrict_id, code, name, lat, lng, province_id)


def cmd_compute_subdistrict_distances(args) -> int:
    if args.reset_checkpoint and SUBDISTRICT_DISTANCE_CHECKPOINT_PATH.exists():
        SUBDISTRICT_DISTANCE_CHECKPOINT_PATH.unlink()
        log("Checkpoint reset")

    conn = get_connection()
    try:
        with conn.cursor() as cur:
            subdistricts = fetch_target_subdistricts(cur, args.provinces, args.districts, args.subdistricts)
    finally:
        conn.close()

    by_province: dict[int, list] = {}
    for row in subdistricts:
        by_province.setdefault(row[5], []).append(row)

    total_scope_pairs = sum(len(g) * (len(g) - 1) for g in by_province.values())
    log(f"{len(subdistricts)} subdistrict(s) in scope across {len(by_province)} province(s) "
        f"-> {total_scope_pairs} directed pairs (within-province only)")

    checkpoint = load_checkpoint(SUBDISTRICT_DISTANCE_CHECKPOINT_PATH)
    done_origins = set(checkpoint.get("done", []))
    explicit_codes = set(args.subdistricts) if args.subdistricts else set()
    if args.force:
        done_origins = set()

    conn = get_connection()
    conn.autocommit = False
    total_pairs = 0
    processed = 0
    failed_origins = []
    start = time.time()
    try:
        with conn.cursor() as cur:
            for group in by_province.values():
                for origin in group:
                    origin_id, origin_code, origin_name, origin_lat, origin_lng, _ = origin
                    processed += 1
                    if origin_code in done_origins and origin_code not in explicit_codes:
                        continue
                    try:
                        pairs = []
                        for dest in group:
                            dest_id = dest[0]
                            if dest_id == origin_id:
                                continue
                            dist_km = haversine_km(
                                float(origin_lat), float(origin_lng), float(dest[3]), float(dest[4])
                            )
                            pairs.append((dest_id, dist_km))
                        bulk_upsert_subdistrict_distances(cur, origin_id, pairs)
                        conn.commit()
                        done_origins.add(origin_code)
                        total_pairs += len(pairs)
                        log(f"  [{processed}/{len(subdistricts)}] {origin_name} ({origin_code}): "
                            f"{len(pairs)} distance(s) upserted")
                    except Exception as exc:  # noqa: BLE001
                        conn.rollback()
                        failed_origins.append((origin_code, origin_name, str(exc)))
                        log(f"  FAIL {origin_name} ({origin_code}): {exc}")
                    finally:
                        save_checkpoint(SUBDISTRICT_DISTANCE_CHECKPOINT_PATH, {"done": sorted(done_origins)})
    finally:
        conn.close()

    elapsed = time.time() - start
    log(f"compute-subdistrict-distances done: {total_pairs} pair(s) upserted in {elapsed:.1f}s, "
        f"{len(failed_origins)} origin(s) failed")
    if failed_origins:
        log("Failed origins (rerun the same command to retry just these):")
        for code, name, err in failed_origins:
            log(f"  - {code} {name}: {err}")
        return 1
    return 0


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def csv_list(value: str) -> list[str]:
    return [v.strip() for v in value.split(",") if v.strip()]


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)

    common = argparse.ArgumentParser(add_help=False)
    common.add_argument(
        "--provinces", type=csv_list, default=DEFAULT_PROVINCES,
        help="Comma-separated province names (Thai). Default: the 8 configured provinces.",
    )
    common.add_argument(
        "--districts", type=csv_list, default=None,
        help="Comma-separated district codes (e.g. 4701,4702) to scope the run to. "
             "Overrides --provinces and always re-processes the given districts "
             "regardless of checkpoint state.",
    )
    common.add_argument("--force", action="store_true", help="Ignore checkpoint, reprocess everything in scope.")

    # subdistrict-level commands need everything in `common` plus --subdistricts
    common_sub = argparse.ArgumentParser(parents=[common], add_help=False)
    common_sub.add_argument(
        "--subdistricts", type=csv_list, default=None,
        help="Comma-separated subdistrict codes (e.g. 470101,470102) to scope the run to. "
             "Overrides --provinces/--districts and always re-processes the given "
             "subdistricts regardless of checkpoint state.",
    )

    p_sync = sub.add_parser("sync-districts", parents=[common], help="Fetch + upsert province/district + lat/lng")
    p_sync.add_argument("--refresh-source", action="store_true", help="Re-download the source GeoJSON instead of using the cache")
    p_sync.set_defaults(func=cmd_sync_districts)

    p_dist = sub.add_parser("compute-distances", parents=[common], help="Compute + upsert district_distances")
    p_dist.add_argument("--reset-checkpoint", action="store_true", help="Delete the checkpoint before starting")
    p_dist.set_defaults(func=cmd_compute_distances)

    p_sync_sub = sub.add_parser("sync-subdistricts", parents=[common_sub],
                                 help="Fetch + upsert subdistrict + lat/lng")
    p_sync_sub.add_argument("--refresh-source", action="store_true",
                             help="Re-download the source GeoJSON instead of using the cache")
    p_sync_sub.set_defaults(func=cmd_sync_subdistricts)

    p_dist_sub = sub.add_parser("compute-subdistrict-distances", parents=[common_sub],
                                 help="Compute + upsert subdistrict_distances (pairs within the same province only)")
    p_dist_sub.add_argument("--reset-checkpoint", action="store_true", help="Delete the checkpoint before starting")
    p_dist_sub.set_defaults(func=cmd_compute_subdistrict_distances)

    p_all = sub.add_parser("run-all", parents=[common_sub],
                            help="Run sync-districts + compute-distances (and optionally the subdistrict level)")
    p_all.add_argument("--refresh-source", action="store_true")
    p_all.add_argument("--reset-checkpoint", action="store_true")
    p_all.add_argument("--with-subdistricts", action="store_true",
                        help="Also run sync-subdistricts + compute-subdistrict-distances after the district level")
    p_all.set_defaults(func=None)

    return parser


def main(argv=None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    if args.command == "run-all":
        rc = cmd_sync_districts(args)
        if rc != 0:
            log("sync-districts had failures; stopping before compute-distances. Fix and rerun.")
            return rc
        rc = cmd_compute_distances(args)
        if rc != 0 or not args.with_subdistricts:
            return rc

        rc = cmd_sync_subdistricts(args)
        if rc != 0:
            log("sync-subdistricts had failures; stopping before compute-subdistrict-distances. Fix and rerun.")
            return rc
        return cmd_compute_subdistrict_distances(args)

    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
