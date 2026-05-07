#!/usr/bin/env python3
# Generate functional-test expected outputs for all images and filters.

from __future__ import annotations

import argparse
from pathlib import Path

from gen_ground_truth import FILTERS, apply_filter, load_image, save_output


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--input-dir",
        type=Path,
        default=Path("tb/data/generated"),
        help="Directory containing 64x64 .raw input images.",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("tb/data/expected"),
        help="Directory where 62x62 expected .hex files will be written.",
    )
    parser.add_argument(
        "--input",
        action="append",
        type=Path,
        default=[],
        help="Additional 64x64 .raw input image to include.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)

    input_paths = sorted(args.input_dir.glob("*.raw")) + args.input
    if not input_paths:
        raise FileNotFoundError(f"no .raw images found in {args.input_dir}")

    generated = 0
    for input_path in input_paths:
        image = load_image(input_path)
        for filter_name in FILTERS:
            result = apply_filter(image, filter_name)
            output_path = args.output_dir / f"{input_path.stem}_{filter_name}.hex"
            save_output(output_path, result)
            generated += 1

    print(f"Generated {generated} expected outputs in {args.output_dir}")


if __name__ == "__main__":
    main()
