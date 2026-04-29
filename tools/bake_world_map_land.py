#!/usr/bin/env python3
"""
Rasters WorldMap land (no ports) from caribbean_land.json to a PNG.
Run from repo root: python3 tools/bake_world_map_land.py
Requires: pip install pillow
Output:  data/land_baked.png (1 world unit = 1 pixel, matches world_size)
"""
from __future__ import annotations

import json
import os
import sys

try:
    from PIL import Image, ImageDraw
except ImportError:
    print("Install Pillow: pip install pillow", file=sys.stderr)
    sys.exit(1)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JSON_PATH = os.path.join(ROOT, "data", "caribbean_land.json")
OUT_PATH = os.path.join(ROOT, "data", "land_baked.png")

# Match scripts/world_map.gd
OCEAN = (20, 51, 82)  # MAP_BG * 255
LAND_FILL = (212, 194, 148)  # LAND_COLOR
COAST = (184, 168, 128)  # LAND_SHADE (approximate)


def main() -> None:
    with open(JSON_PATH, "r", encoding="utf-8") as f:
        payload: dict = json.load(f)
    ws = payload.get("world_size")
    if not (isinstance(ws, list) and len(ws) >= 2):
        print("Invalid world_size in json", file=sys.stderr)
        sys.exit(1)
    w, h = int(float(ws[0])), int(float(ws[1]))
    polys: list = payload.get("polygons")
    if not polys:
        print("No polygons in json", file=sys.stderr)
        sys.exit(1)

    im = Image.new("RGBA", (w, h), OCEAN + (255,))
    dr = ImageDraw.Draw(im, "RGBA")

    for block in polys:
        if not isinstance(block, list) or len(block) < 2:
            continue
        points: list[tuple[float, float]] = []
        for pt in block:
            if isinstance(pt, list) and len(pt) >= 2:
                points.append((float(pt[0]), float(pt[1])))
        n = len(points)
        if n < 2:
            continue
        if n == 2:
            dr.line(points, fill=COAST + (255,), width=2, joint="curve")
            continue
        dr.polygon(points, fill=LAND_FILL + (255,), outline=COAST + (255,))

    os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)
    im.save(OUT_PATH, "PNG", compress_level=6, optimize=True)
    size_kb = os.path.getsize(OUT_PATH) // 1024
    print("Wrote", OUT_PATH, f"({w}x{h}, {size_kb} KB)")


if __name__ == "__main__":
    main()
