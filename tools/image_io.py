# Small image I/O helpers for generated grayscale test data.

from __future__ import annotations

import struct
import zlib
from pathlib import Path


def _chunk(tag: bytes, payload: bytes) -> bytes:
    return (
        struct.pack(">I", len(payload))
        + tag
        + payload
        + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF)
    )


def validate_pixels(pixels: list[int], expected_count: int | None = None) -> None:
    if expected_count is not None and len(pixels) != expected_count:
        raise ValueError(f"expected {expected_count} pixels, got {len(pixels)}")

    for value in pixels:
        if not 0 <= value <= 255:
            raise ValueError(f"pixel out of range: {value}")


def write_png(path: Path, width: int, height: int, pixels: list[int]) -> None:
    validate_pixels(pixels, width * height)

    header = b"\x89PNG\r\n\x1a\n"
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 0, 0, 0, 0)

    rows = bytearray()
    for y in range(height):
        rows.append(0)
        start = y * width
        rows.extend(pixels[start : start + width])

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(
        header
        + _chunk(b"IHDR", ihdr)
        + _chunk(b"IDAT", zlib.compress(bytes(rows), level=9))
        + _chunk(b"IEND", b"")
    )


def write_raw(path: Path, pixels: list[int]) -> None:
    validate_pixels(pixels)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(bytes(pixels))


def write_hex(path: Path, pixels: list[int]) -> None:
    validate_pixels(pixels)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("".join(f"{value:02x}\n" for value in pixels), encoding="ascii")
