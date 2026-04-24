#!/usr/bin/env python3
# Generate 64x64 grayscale images for RTL testing.

from __future__ import annotations

import argparse
import math
import random
import struct
import datetime
import zlib
from pathlib import Path


WIDTH = 64
HEIGHT = 64
SEED = datetime.datetime.now().timestamp()


def chunk(tag: bytes, payload: bytes) -> bytes:
    return (
        struct.pack(">I", len(payload))
        + tag
        + payload
        + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF)
    )


def write_png(path: Path, pixels: list[int]) -> None:
    header = b"\x89PNG\r\n\x1a\n"
    ihdr = struct.pack(">IIBBBBB", WIDTH, HEIGHT, 8, 0, 0, 0, 0)

    rows = bytearray()
    for y in range(HEIGHT):
        rows.append(0)
        start = y * WIDTH
        rows.extend(pixels[start : start + WIDTH])

    path.write_bytes(
        header
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", zlib.compress(bytes(rows), level=9))
        + chunk(b"IEND", b"")
    )


def write_raw(path: Path, pixels: list[int]) -> None:
    path.write_bytes(bytes(pixels))


def write_hex(path: Path, pixels: list[int]) -> None:
    path.write_text("".join(f"{value:02x}\n" for value in pixels), encoding="ascii")


def save_pattern(base_dir: Path, name: str, pixels: list[int]) -> None:
    if len(pixels) != WIDTH * HEIGHT:
        raise ValueError(f"{name}: expected {WIDTH * HEIGHT} pixels, got {len(pixels)}")

    for value in pixels:
        if not 0 <= value <= 255:
            raise ValueError(f"{name}: pixel out of range: {value}")

    write_png(base_dir / f"{name}.png", pixels)
    write_raw(base_dir / f"{name}.raw", pixels)
    write_hex(base_dir / f"{name}.hex", pixels)


def horizontal_gradient() -> list[int]:
    return [(x * 255) // (WIDTH - 1) for _ in range(HEIGHT) for x in range(WIDTH)]


def vertical_gradient() -> list[int]:
    return [(y * 255) // (HEIGHT - 1) for y in range(HEIGHT) for _ in range(WIDTH)]


def checkerboard(tile: int = 4) -> list[int]:
    pixels: list[int] = []
    for y in range(HEIGHT):
        for x in range(WIDTH):
            pixels.append(255 if ((x // tile) + (y // tile)) % 2 else 0)
    return pixels


def center_impulse() -> list[int]:
    pixels = [0] * (WIDTH * HEIGHT)
    center = (HEIGHT // 2) * WIDTH + (WIDTH // 2)
    pixels[center] = 255
    return pixels


def diagonal_step() -> list[int]:
    pixels: list[int] = []
    for y in range(HEIGHT):
        for x in range(WIDTH):
            pixels.append(255 if x >= y else 0)
    return pixels


def vertical_bars(period: int = 8) -> list[int]:
    pixels: list[int] = []
    for _ in range(HEIGHT):
        for x in range(WIDTH):
            pixels.append(255 if (x // period) % 2 else 32)
    return pixels


def concentric_rings() -> list[int]:
    pixels: list[int] = []
    cx = (WIDTH - 1) / 2.0
    cy = (HEIGHT - 1) / 2.0
    for y in range(HEIGHT):
        for x in range(WIDTH):
            dist = math.hypot(x - cx, y - cy)
            band = int(dist * 12) % 64
            pixels.append(min(255, band * 4))
    return pixels


def seeded_noise() -> list[int]:
    rng = random.Random(SEED)
    return [rng.randrange(256) for _ in range(WIDTH * HEIGHT)]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("tb/data/generated"),
        help="Directory where generated image files will be written.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)

    patterns = {
        "horizontal_gradient": horizontal_gradient(),
        "vertical_gradient": vertical_gradient(),
        "checkerboard_4px": checkerboard(tile=4),
        "center_impulse": center_impulse(),
        "diagonal_step": diagonal_step(),
        "vertical_bars": vertical_bars(period=8),
        "concentric_rings": concentric_rings(),
        "seeded_noise": seeded_noise(),
    }

    for name, pixels in patterns.items():
        save_pattern(args.output_dir, name, pixels)

    print(f"Generated {len(patterns)} patterns in {args.output_dir}")


if __name__ == "__main__":
    main()
