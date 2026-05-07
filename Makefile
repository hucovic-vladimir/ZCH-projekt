VERILATOR := verilator
SV2V := sv2v
YOSYS := yosys
VENV_PYTHON := .venv/bin/python
SIM_BIN := obj_dir/Vfilter_top_tb
SAIF_OBJ_DIR := obj_dir_saif
SAIF_BIN := $(SAIF_OBJ_DIR)/Vfilter_top_tb
GENERATED_IMAGE_DIR := tb/data/generated
GENERATED_EXPECTED_DIR := tb/data/expected
GENERATED_ACTUAL_DIR := tb/data/actual
LENNA_INPUT := tb/data/lenna_64x64_gray.raw
SAIF_FILE := activity.saif
WAVE_FILES := waves.fst $(SAIF_FILE)

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

.PHONY: build sim actual-png saif synth clean check-venv venv

build: $(SIM_BIN)

sim: build check-venv
	$(VENV_PYTHON) tools/gen_test_images.py
	$(VENV_PYTHON) tools/gen_functional_expected.py --input $(LENNA_INPUT)
	./$(SIM_BIN)
	$(MAKE) actual-png

actual-png: check-venv
	for file in $(GENERATED_ACTUAL_DIR)/*.hex; do \
		$(VENV_PYTHON) tools/hex_to_png.py $$file; \
	done

saif: $(SAIF_BIN) check-venv
	$(VENV_PYTHON) tools/gen_test_images.py
	$(VENV_PYTHON) tools/gen_functional_expected.py --input $(LENNA_INPUT)
	./$(SAIF_BIN)

clean:
	rm -rf obj_dir $(SAIF_OBJ_DIR) tools/__pycache__
	rm -rf build
	rm -rf $(GENERATED_IMAGE_DIR) $(GENERATED_EXPECTED_DIR) $(GENERATED_ACTUAL_DIR)
	rm -f $(WAVE_FILES)

check-venv:
	test -x $(VENV_PYTHON)

venv:
	python3 -m venv .venv
	. .venv/bin/activate && python -m pip install -r requirements.txt

$(SIM_BIN): $(RTL_SRCS) $(TB_SRCS)
	$(VERILATOR) --binary --timing --trace-fst -Wall \
		--top-module filter_top_tb \
		$(RTL_SRCS) $(TB_SRCS)

$(SAIF_BIN): $(RTL_SRCS) $(TB_SRCS)
	$(VERILATOR) --binary --timing --trace-saif -Wall -DSAIF_TRACE \
		--Mdir $(SAIF_OBJ_DIR) \
		--top-module filter_top_tb \
		$(RTL_SRCS) $(TB_SRCS)

synth:
	mkdir -p build/verilog
	$(SV2V) $(RTL_SRCS) > $(SV2V_OUT_FILE)
	$(YOSYS) -q -l $(SYNTH_LOG_FILE) -p 'read_verilog -sv $(SV2V_OUT_FILE); hierarchy -check -top filter_top; synth -top filter_top -run coarse; check; stat; write_rtlil $(SYNTH_OUT_FILE)'
