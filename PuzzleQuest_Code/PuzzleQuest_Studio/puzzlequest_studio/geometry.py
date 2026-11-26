"""Deterministic, complementary Bezier jigsaw geometry.

All segments defining a shared cell boundary are generated ONCE and consumed
in opposite directions by the adjacent pieces. This is essential for snap
geometry consistency and coverage.
"""
from __future__ import annotations

from dataclasses import dataclass
import random
from typing import List, Tuple

Point = tuple[float, float]


def _cubic(a: Point, b: Point, c: Point, d: Point, t: float) -> Point:
    s = 1.0 - t
    return (s ** 3 * a[0] + 3 * s * s * t * b[0] + 3 * s * t * t * c[0] + t ** 3 * d[0],
            s ** 3 * a[1] + 3 * s * s * t * b[1] + 3 * s * t * t * c[1] + t ** 3 * d[1])


def _tab_profile(steps: int = 14) -> list[Point]:
    """One continuous neck + rounded knob in (along-edge, offset) units."""
    chunks = [
        ((.29, 0), (.37, -.01), (.40, .10), (.36, .28)),
        ((.36, .28), (.24, .57), (.34, 1.07), (.49, 1.10)),
        ((.49, 1.10), (.66, 1.13), (.75, .60), (.64, .27)),
        ((.64, .27), (.60, .12), (.65, .00), (.71, .00)),
    ]
    pts = [(0.0, 0.0), (.29, 0.0)]
    for segment in chunks:
        pts.extend(_cubic(*segment, i / steps) for i in range(1, steps + 1))
    pts.append((1.0, 0.0))
    return pts


_PROFILE = _tab_profile()


def _edge(start: Point, end: Point, *, signed_amplitude: float, horizontal: bool) -> list[Point]:
    length = (end[0] - start[0]) if horizontal else (end[1] - start[1])
    if signed_amplitude == 0:
        return [start, end]
    if horizontal:
        return [(start[0] + t * length, start[1] + signed_amplitude * v) for t, v in _PROFILE]
    return [(start[0] + signed_amplitude * v, start[1] + t * length) for t, v in _PROFILE]


@dataclass
class BoardGeometry:
    width: int
    height: int
    rows: int
    cols: int
    horizontal: list[list[list[Point]]]
    vertical: list[list[list[Point]]]
    polygons: list[list[Point]]


def create_board(width: int, height: int, rows: int, cols: int, seed: int) -> BoardGeometry:
    if rows < 2 or cols < 2 or min(width / cols, height / rows) < 30:
        raise ValueError("Board too small for reliable jigsaw geometry")
    rng = random.Random(seed)
    cw, ch = width / cols, height / rows
    horizontal: list[list[list[Point]]] = []
    for r in range(rows + 1):
        line = []
        for c in range(cols):
            start, end = (c*cw, r*ch), ((c+1)*cw, r*ch)
            amplitude = 0.0 if r in (0, rows) else ch * rng.uniform(.20, .235) * rng.choice((-1, 1))
            line.append(_edge(start, end, signed_amplitude=amplitude, horizontal=True))
        horizontal.append(line)
    vertical: list[list[list[Point]]] = []
    for r in range(rows):
        line = []
        for c in range(cols + 1):
            start, end = (c*cw, r*ch), (c*cw, (r+1)*ch)
            amplitude = 0.0 if c in (0, cols) else cw * rng.uniform(.20, .235) * rng.choice((-1, 1))
            line.append(_edge(start, end, signed_amplitude=amplitude, horizontal=False))
        vertical.append(line)
    polygons = []
    for r in range(rows):
        for c in range(cols):
            edges = [horizontal[r][c], vertical[r][c+1],
                     list(reversed(horizontal[r+1][c])), list(reversed(vertical[r][c]))]
            polygon: list[Point] = []
            for points in edges:
                polygon.extend(points if not polygon else points[1:])
            polygons.append(polygon)
    return BoardGeometry(width, height, rows, cols, horizontal, vertical, polygons)


def normalized_polygon(points: list[Point], width: int, height: int) -> list[list[float]]:
    return [[round(x / width, 7), round(y / height, 7)] for x, y in points]
