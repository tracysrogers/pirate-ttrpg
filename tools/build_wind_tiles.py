#!/usr/bin/env python3
"""
Download monthly average wind per map tile for the Caribbean region.

Source: NASA POWER climatology API (WS10M, WD10M)
Output: data/wind_tiles_monthly.json
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import pathlib
import time
import urllib.parse
import urllib.request
from typing import Dict, List, Tuple

API_BASE = "https://power.larc.nasa.gov/api/temporal/climatology/point"

# Keep in sync with world map bbox/projection.
LON_MIN = -102.0
LON_MAX = -56.0
LAT_MIN = 4.0
LAT_MAX = 36.0
WORLD_W = 2800.0
WORLD_H = 1700.0


def world_project(lon: float, lat: float) -> Tuple[float, float]:
    x = (lon - LON_MIN) / (LON_MAX - LON_MIN) * WORLD_W
    y = (LAT_MAX - lat) / (LAT_MAX - LAT_MIN) * WORLD_H
    return (x, y)


def tile_center_lonlat(col: int, row: int, cols: int, rows: int) -> Tuple[float, float]:
    lon_step = (LON_MAX - LON_MIN) / cols
    lat_step = (LAT_MAX - LAT_MIN) / rows
    lon = LON_MIN + (col + 0.5) * lon_step
    lat = LAT_MIN + (row + 0.5) * lat_step
    return (lon, lat)


def fetch_climatology(lon: float, lat: float, retries: int = 3) -> Dict[str, Dict[str, float]]:
    query = urllib.parse.urlencode(
        {
            "parameters": "WS10M,WD10M",
            "community": "RE",
            "longitude": f"{lon:.5f}",
            "latitude": f"{lat:.5f}",
            "format": "JSON",
        }
    )
    url = f"{API_BASE}?{query}"

    last_err: Exception | None = None
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(url, timeout=30) as resp:
                payload = json.loads(resp.read().decode("utf-8"))
            params = payload["properties"]["parameter"]
            ws = params["WS10M"]
            wd = params["WD10M"]
            month_keys = [
                ("01", "JAN"),
                ("02", "FEB"),
                ("03", "MAR"),
                ("04", "APR"),
                ("05", "MAY"),
                ("06", "JUN"),
                ("07", "JUL"),
                ("08", "AUG"),
                ("09", "SEP"),
                ("10", "OCT"),
                ("11", "NOV"),
                ("12", "DEC"),
            ]
            out: Dict[str, Dict[str, float]] = {}
            for numeric_key, api_key in month_keys:
                out[numeric_key] = {
                    "speed_m_s": float(ws[api_key]),
                    "direction_deg": float(wd[api_key]),
                }
            return out
        except Exception as exc:  # noqa: BLE001
            last_err = exc
            if attempt < retries - 1:
                time.sleep(1.2 * (attempt + 1))
            else:
                raise RuntimeError(f"Failed NASA POWER request for ({lon}, {lat}): {exc}") from exc
    if last_err:
        raise RuntimeError(str(last_err))
    raise RuntimeError("Unexpected fetch error")


def main() -> None:
    parser = argparse.ArgumentParser(description="Build monthly wind tiles JSON")
    parser.add_argument("--cols", type=int, default=12, help="Tile columns")
    parser.add_argument("--rows", type=int, default=8, help="Tile rows")
    parser.add_argument(
        "--output",
        type=pathlib.Path,
        default=pathlib.Path("data/wind_tiles_monthly.json"),
        help="Output JSON path",
    )
    parser.add_argument(
        "--sleep-seconds",
        type=float,
        default=0.1,
        help="Delay between API calls",
    )
    args = parser.parse_args()

    root = pathlib.Path(__file__).resolve().parents[1]
    output_path = root / args.output
    output_path.parent.mkdir(parents=True, exist_ok=True)

    tiles: List[dict] = []
    total = args.cols * args.rows
    idx = 0
    for row in range(args.rows):
        for col in range(args.cols):
            idx += 1
            lon, lat = tile_center_lonlat(col, row, args.cols, args.rows)
            monthly = fetch_climatology(lon, lat)
            wx, wy = world_project(lon, lat)
            tiles.append(
                {
                    "col": col,
                    "row": row,
                    "lon": round(lon, 5),
                    "lat": round(lat, 5),
                    "world_x": round(wx, 2),
                    "world_y": round(wy, 2),
                    "monthly": monthly,
                }
            )
            print(f"[{idx}/{total}] fetched tile row={row} col={col}")
            if args.sleep_seconds > 0:
                time.sleep(args.sleep_seconds)

    payload = {
        "source": "NASA POWER climatology WS10M/WD10M",
        "generated_utc": dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        "bbox": {
            "lon_min": LON_MIN,
            "lon_max": LON_MAX,
            "lat_min": LAT_MIN,
            "lat_max": LAT_MAX,
        },
        "world_size": [WORLD_W, WORLD_H],
        "grid": {"cols": args.cols, "rows": args.rows},
        "tiles": tiles,
    }
    output_path.write_text(json.dumps(payload, separators=(",", ":")), encoding="utf-8")
    print(f"Wrote {len(tiles)} wind tiles to {output_path}")


if __name__ == "__main__":
    main()
