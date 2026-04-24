VERILATOR := verilator
SV2V := sv2v
YOSYS := yosys
VENV_PYTHON := .venv/bin/python
SIM_BIN := obj_dir/Vfilter_top_tb
GENERATED_IMAGE_DIR := tb/data/generated
GENERATED_EXPECTED_DIR := tb/data/expected
WAVE_FILES := waves.fst

RTL_SRCS := \
	rtl/filter_pkg.sv \
	rtl/configuration.sv \
	rtl/rom.sv \
	rtl/ram.sv \
	rtl/input_buffer.sv \
	rtl/convolution_core.sv \
	rtl/output_buffer.sv \
	rtl/filter_top.sv

TB_SRCS := tb/filter_top_tb.sv

SV2V_OUT_FILE := build/verilog/filter_top.v
SYNTH_OUT_FILE := build/verilog/filter_top_synth.il
SYNTH_LOG_FILE := build/verilog/synth.log

.PHONY: build sim synth clean check-venv

build: $(SIM_BIN)

sim: build check-venv
	$(VENV_PYTHON) tools/gen_test_images.py
	$(VENV_PYTHON) tools/gen_functional_expected.py
	./$(SIM_BIN)

clean:
	rm -rf obj_dir tools/__pycache__
	rm -rf build
	rm -rf $(GENERATED_IMAGE_DIR) $(GENERATED_EXPECTED_DIR)
	rm -f $(WAVE_FILES)

check-venv:
	test -x $(VENV_PYTHON)

$(SIM_BIN): $(RTL_SRCS) $(TB_SRCS)
	$(VERILATOR) --binary --timing --trace-fst -Wall \
		--top-module filter_top_tb \
		$(RTL_SRCS) $(TB_SRCS)

synth:
	mkdir -p build/verilog
	$(SV2V) $(RTL_SRCS) > $(SV2V_OUT_FILE)
	$(YOSYS) -q -l $(SYNTH_LOG_FILE) -p 'read_verilog -sv $(SV2V_OUT_FILE); hierarchy -check -top filter_top; synth -top filter_top -run coarse; check; stat; write_rtlil $(SYNTH_OUT_FILE)'
