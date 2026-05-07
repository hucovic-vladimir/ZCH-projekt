#!/usr/bin/env python3
# Convert a one-byte-per-line grayscale .hex file to a PNG image.

from __future__ import annotations

import argparse
from pathlib import Path

from image_io import write_png


INPUT_WIDTH = 64
INPUT_HEIGHT = 64
OUTPUT_WIDTH = 62
OUTPUT_HEIGHT = 62


def load_hex(path: Path) -> list[int]:
    pixels: list[int] = []

    with path.open("r", encoding="ascii") as handle:
        for line_num, line in enumerate(handle, start=1):
            value_text = line.strip()
            if not value_text:
                continue

            try:
                value = int(value_text, 16)
            except ValueError as exc:
                raise ValueError(f"{path}:{line_num}: invalid hex byte: {value_text}") from exc

            if not 0 <= value <= 255:
                raise ValueError(f"{path}:{line_num}: value out of byte range: {value_text}")

            pixels.append(value)

    return pixels


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path, help="Input .hex file.")
    parser.add_argument(
        "output",
        type=Path,
        nargs="?",
        help="Output .png file. Defaults to input path with .png suffix.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    pixels = load_hex(args.input)

    if len(pixels) == INPUT_WIDTH * INPUT_HEIGHT:
        width = INPUT_WIDTH
        height = INPUT_HEIGHT
    elif len(pixels) == OUTPUT_WIDTH * OUTPUT_HEIGHT:
        width = OUTPUT_WIDTH
        height = OUTPUT_HEIGHT
    else:
        raise ValueError(
            f"unsupported pixel count {len(pixels)}; expected 4096 for 64x64 input "
            "or 3844 for 62x62 output"
        )

    output = args.output if args.output is not None else args.input.with_suffix(".png")
    write_png(output, width, height, pixels)
    print(f"Wrote {width}x{height} PNG to {output}")


if __name__ == "__main__":
    main()
