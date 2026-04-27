#!/usr/bin/env python3
"""
Build a Caribbean land polygon dataset from Natural Earth GeoJSON.

Outputs: data/caribbean_land.json
"""

from __future__ import annotations

import json
import math
import pathlib
import urllib.request
from typing import Iterable, List, Sequence, Tuple


GEOJSON_URL = (
    "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_50m_land.geojson"
)

# Caribbean/Gulf-focused extent.
LON_MIN = -102.0
LON_MAX = -56.0
LAT_MIN = 4.0
LAT_MAX = 36.0

WORLD_W = 2800.0
WORLD_H = 1700.0

# Keep coast shape but reduce point count.
MIN_POINT_DISTANCE = 3.2
MAX_POINTS_PER_RING = 420


def project(lon: float, lat: float) -> Tuple[float, float]:
    x = (lon - LON_MIN) / (LON_MAX - LON_MIN) * WORLD_W
    y = (LAT_MAX - lat) / (LAT_MAX - LAT_MIN) * WORLD_H
    return (x, y)


def point_in_bbox(lon: float, lat: float) -> bool:
    return LON_MIN <= lon <= LON_MAX and LAT_MIN <= lat <= LAT_MAX


def clip_ring_to_bbox(points: Sequence[Tuple[float, float]]) -> List[Tuple[float, float]]:
    """
    Sutherland-Hodgman polygon clip against lon/lat rectangle.
    """

    def clip_edge(
        poly: List[Tuple[float, float]],
        inside_fn,
        intersect_fn,
    ) -> List[Tuple[float, float]]:
        if not poly:
            return []
        output: List[Tuple[float, float]] = []
        prev = poly[-1]
        prev_inside = inside_fn(prev)
        for curr in poly:
            curr_inside = inside_fn(curr)
            if curr_inside:
                if not prev_inside:
                    output.append(intersect_fn(prev, curr))
                output.append(curr)
            elif prev_inside:
                output.append(intersect_fn(prev, curr))
            prev = curr
            prev_inside = curr_inside
        return output

    def intersect_lon(p1: Tuple[float, float], p2: Tuple[float, float], x: float) -> Tuple[float, float]:
        x1, y1 = p1
        x2, y2 = p2
        if x2 == x1:
            return (x, y1)
        t = (x - x1) / (x2 - x1)
        return (x, y1 + t * (y2 - y1))

    def intersect_lat(p1: Tuple[float, float], p2: Tuple[float, float], y: float) -> Tuple[float, float]:
        x1, y1 = p1
        x2, y2 = p2
        if y2 == y1:
            return (x1, y)
        t = (y - y1) / (y2 - y1)
        return (x1 + t * (x2 - x1), y)

    poly = list(points)
    poly = clip_edge(poly, lambda p: p[0] >= LON_MIN, lambda a, b: intersect_lon(a, b, LON_MIN))
    poly = clip_edge(poly, lambda p: p[0] <= LON_MAX, lambda a, b: intersect_lon(a, b, LON_MAX))
    poly = clip_edge(poly, lambda p: p[1] >= LAT_MIN, lambda a, b: intersect_lat(a, b, LAT_MIN))
    poly = clip_edge(poly, lambda p: p[1] <= LAT_MAX, lambda a, b: intersect_lat(a, b, LAT_MAX))
    return poly


def simplify_ring(points: Sequence[Tuple[float, float]]) -> List[Tuple[float, float]]:
    if len(points) <= 4:
        return list(points)

    out: List[Tuple[float, float]] = [points[0]]
    last_x, last_y = points[0]
    for x, y in points[1:]:
        if math.hypot(x - last_x, y - last_y) >= MIN_POINT_DISTANCE:
            out.append((x, y))
            last_x, last_y = x, y

    if len(out) > MAX_POINTS_PER_RING:
        stride = max(1, len(out) // MAX_POINTS_PER_RING)
        out = out[::stride]
        if out[-1] != points[-1]:
            out.append(points[-1])

    if out and out[0] != out[-1]:
        out.append(out[0])
    return out


def iter_rings(geometry: dict) -> Iterable[Sequence[Sequence[float]]]:
    gtype = geometry.get("type")
    coords = geometry.get("coordinates", [])
    if gtype == "Polygon":
        for ring in coords:
            yield ring
    elif gtype == "MultiPolygon":
        for polygon in coords:
            for ring in polygon:
                yield ring


def main() -> None:
    root = pathlib.Path(__file__).resolve().parents[1]
    data_dir = root / "data"
    data_dir.mkdir(exist_ok=True)
    output_path = data_dir / "caribbean_land.json"

    with urllib.request.urlopen(GEOJSON_URL, timeout=30) as resp:
        raw = resp.read().decode("utf-8")
    gj = json.loads(raw)

    polygons: List[List[List[float]]] = []
    for feature in gj.get("features", []):
        geometry = feature.get("geometry") or {}
        for ring in iter_rings(geometry):
            if not ring:
                continue
            lonlat_ring = [(float(lon), float(lat)) for lon, lat in ring]
            clipped = clip_ring_to_bbox(lonlat_ring)
            if len(clipped) < 3:
                continue
            projected = [project(lon, lat) for lon, lat in clipped]
            simplified = simplify_ring(projected)
            if len(simplified) >= 4:
                polygons.append([[round(x, 2), round(y, 2)] for x, y in simplified])

    payload = {
        "source": GEOJSON_URL,
        "bbox": {
            "lon_min": LON_MIN,
            "lon_max": LON_MAX,
            "lat_min": LAT_MIN,
            "lat_max": LAT_MAX,
        },
        "world_size": [WORLD_W, WORLD_H],
        "polygons": polygons,
    }
    output_path.write_text(json.dumps(payload, separators=(",", ":")), encoding="utf-8")
    print(f"Wrote {len(polygons)} polygons to {output_path}")


if __name__ == "__main__":
    main()
