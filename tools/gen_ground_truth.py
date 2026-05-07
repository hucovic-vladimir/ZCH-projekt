#!/usr/bin/env python3
# Ground-truth generator for the testbench.

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from scipy import signal


FILTERS = {
    "sharpen": np.array(
        [[0, -1, 0], [-1, 5, -1], [0, -1, 0]],
        dtype=np.int16,
    ),
    "gaussian": np.array(
        [[1, 2, 1], [2, 4, 2], [1, 2, 1]],
        dtype=np.int16,
    ),
    "vertical_edge": np.array(
        [[-1, 0, 1], [-2, 0, 2], [-1, 0, 1]],
        dtype=np.int16,
    ),
    "horizontal_edge": np.array(
        [[-1, -2, -1], [0, 0, 0], [1, 2, 1]],
        dtype=np.int16,
    ),
}

SCALE_DIVISORS = {
    "sharpen": 1,
    "gaussian": 16,
    "vertical_edge": 1,
    "horizontal_edge": 1,
}

ABS_RESULT_FILTERS = {
    "vertical_edge",
    "horizontal_edge",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--input",
        type=Path,
        required=True,
        help="Path to a 64x64 grayscale image as raw bytes.",
    )
    parser.add_argument(
        "--filter",
        choices=FILTERS.keys(),
        required=True,
        help="Filter to apply.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        help="Optional .hex output path.",
    )
    return parser.parse_args()


def load_image(path: Path) -> np.ndarray:
    data = np.fromfile(path, dtype=np.uint8)
    if data.size != 64 * 64:
        raise ValueError(f"raw input must contain exactly 4096 bytes, got {data.size}")
    return data.reshape(64, 64)


def apply_filter(image: np.ndarray, filter_name: str) -> np.ndarray:
    kernel = FILTERS[filter_name]
    divisor = SCALE_DIVISORS[filter_name]
    image_i16 = image.astype(np.int16, copy=False)
    filtered = signal.correlate2d(image_i16, kernel, mode="valid")

    filtered = filtered // divisor
    if filter_name in ABS_RESULT_FILTERS:
        filtered = np.abs(filtered)

    filtered = np.clip(filtered, 0, 255)
    return filtered.astype(np.uint8)


def save_output(path: Path, result: np.ndarray) -> None:
    if path.suffix != ".hex":
        raise ValueError(f"unsupported output suffix: {path.suffix}")

    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="ascii") as handle:
        for value in result.reshape(-1):
            handle.write(f"{int(value):02x}\n")


def main() -> None:
    args = parse_args()
    image = load_image(args.input)
    result = apply_filter(image, args.filter)

    if args.output:
        save_output(args.output, result)
    else:
        for row in result:
            print(",".join(str(int(value)) for value in row))


if __name__ == "__main__":
    main()
