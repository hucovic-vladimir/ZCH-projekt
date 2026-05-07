# ZCH Project - Implementation and verification report

## Archive content

- `rtl/` contains SystemVerilog implementation of the design described in `spec.md`.
- `tools/` contains utilities to generate some test images, generate ground truth, and other utility scripts
- `tb/` contains a SystemVerilog testbench and data (input images, ground truth, actual outputs produced by testbench). Test plan and testbench simplified based on feedback (only functional tests).
- `activity.saif` contains the switching activity information.

## Running and building
- `make venv` to create `.venv` folder and install Python dependencies
- `make sim` or `make saif` to generate inputs and expected outputs, build and run the simulation (and get waves file or SAIF file respectively)
    - [Verilator](https://github.com/verilator/verilator) is used for simulation.
- `make synth` to perform synthesis with [`Yosys`](https://github.com/yosyshq/yosys)
    - [`sv2v`](https://github.com/zachjs/sv2v) also required for this target.
    - Log placed in `./build/verilog/synth.log`


## Simulation output
- Simulation runs and checks all 4 filters across 9 images.
- Raw output also converted to PNG and saved.

```

- V e r i l a t i o n   R e p o r t: Verilator 5.036 2025-04-27 rev UNKNOWN.REV
- Verilator: Built from 0.248 MB sources in 10 modules, into 0.451 MB in 12 C++ files needing 0.001 MB
- Verilator: Walltime 4.466 s (elab=0.004, cvt=0.021, bld=4.427); cpu 0.031 s on 1 threads
test -x .venv/bin/python
.venv/bin/python tools/gen_test_images.py
Generated 8 patterns in tb/data/generated
.venv/bin/python tools/gen_functional_expected.py --input tb/data/lenna_64x64_gray.raw
Generated 36 expected outputs in tb/data/expected
./obj_dir/Vfilter_top_tb
PASS: center_impulse/SHARPENING functional test completed in 4287 cycles.
PASS: center_impulse/SMOOTHING functional test completed in 4287 cycles.
PASS: center_impulse/EDGE_VERTICAL functional test completed in 4287 cycles.
PASS: center_impulse/EDGE_HORIZONTAL functional test completed in 4287 cycles.
PASS: checkerboard_4px/SHARPENING functional test completed in 4287 cycles.
PASS: checkerboard_4px/SMOOTHING functional test completed in 4287 cycles.
PASS: checkerboard_4px/EDGE_VERTICAL functional test completed in 4287 cycles.
PASS: checkerboard_4px/EDGE_HORIZONTAL functional test completed in 4287 cycles.
PASS: concentric_rings/SHARPENING functional test completed in 4287 cycles.
PASS: concentric_rings/SMOOTHING functional test completed in 4287 cycles.
PASS: concentric_rings/EDGE_VERTICAL functional test completed in 4287 cycles.
PASS: concentric_rings/EDGE_HORIZONTAL functional test completed in 4287 cycles.
PASS: diagonal_step/SHARPENING functional test completed in 4287 cycles.
PASS: diagonal_step/SMOOTHING functional test completed in 4287 cycles.
PASS: diagonal_step/EDGE_VERTICAL functional test completed in 4287 cycles.
PASS: diagonal_step/EDGE_HORIZONTAL functional test completed in 4287 cycles.
PASS: horizontal_gradient/SHARPENING functional test completed in 4287 cycles.
PASS: horizontal_gradient/SMOOTHING functional test completed in 4287 cycles.
PASS: horizontal_gradient/EDGE_VERTICAL functional test completed in 4287 cycles.
PASS: horizontal_gradient/EDGE_HORIZONTAL functional test completed in 4287 cycles.
PASS: seeded_noise/SHARPENING functional test completed in 4287 cycles.
PASS: seeded_noise/SMOOTHING functional test completed in 4287 cycles.
PASS: seeded_noise/EDGE_VERTICAL functional test completed in 4287 cycles.
PASS: seeded_noise/EDGE_HORIZONTAL functional test completed in 4287 cycles.
PASS: vertical_bars/SHARPENING functional test completed in 4287 cycles.
PASS: vertical_bars/SMOOTHING functional test completed in 4287 cycles.
PASS: vertical_bars/EDGE_VERTICAL functional test completed in 4287 cycles.
PASS: vertical_bars/EDGE_HORIZONTAL functional test completed in 4287 cycles.
PASS: vertical_gradient/SHARPENING functional test completed in 4287 cycles.
PASS: vertical_gradient/SMOOTHING functional test completed in 4287 cycles.
PASS: vertical_gradient/EDGE_VERTICAL functional test completed in 4287 cycles.
PASS: vertical_gradient/EDGE_HORIZONTAL functional test completed in 4287 cycles.
PASS: lenna_64x64_gray/SHARPENING functional test completed in 4287 cycles.
PASS: lenna_64x64_gray/SMOOTHING functional test completed in 4287 cycles.
PASS: lenna_64x64_gray/EDGE_VERTICAL functional test completed in 4287 cycles.
PASS: lenna_64x64_gray/EDGE_HORIZONTAL functional test completed in 4287 cycles.
PASS: all 36 functional tests completed successfully
- tb/filter_top_tb.sv:380: Verilog $finish
- S i m u l a t i o n   R e p o r t: Verilator 5.036 2025-04-27
- Verilator: $finish at 2ms; walltime 0.142 s; speed 11.736 ms/s
- Verilator: cpu 0.132 s on 1 threads; alloced 0 MB`

```

## Output example lenna_64x64_gray:

![Original image](./tb/data/lenna_64x64_gray.png)

![Smoothing output](./tb/data/actual/lenna_64x64_gray_gaussian.png)

![Sharpening output](./tb/data/actual/lenna_64x64_gray_sharpen.png)

![Vertial edge detection output](./tb/data/actual/lenna_64x64_gray_vertical_edge.png)

![Horizontal edge detection output](./tb/data/actual/lenna_64x64_gray_horizontal_edge.png)







