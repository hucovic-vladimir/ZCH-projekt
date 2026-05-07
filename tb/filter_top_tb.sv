`timescale 1ns/1ps

module filter_top_tb;

  localparam time CLK_PERIOD = 10ns;
  localparam int INPUT_PIXELS = filter_pkg::IN_IMAGE_W * filter_pkg::IN_IMAGE_H;
  localparam int OUTPUT_PIXELS = filter_pkg::OUT_IMAGE_W * filter_pkg::OUT_IMAGE_H;
  localparam int MAX_WAIT_CYCLES = 12000;
  localparam bit DEBUG = 1'b0;
  localparam int NUM_IMAGES = 9;
  localparam int NUM_FILTERS = 4;
  localparam int unsigned ADDR_RANDOM_SEED = 32'h42424242;

  logic clk;
  logic rst;
  logic cfg_write_en_i;
  filter_pkg::filter_type_e filter_selection_i;
  filter_pkg::ram_addr_t in_addr_i;
  filter_pkg::ram_addr_t out_addr_i;
  logic enable_i;
  logic busy_o;
  logic output_ready_o;
  logic error_o;

  filter_pkg::pixel_t input_image [0:INPUT_PIXELS-1];
  filter_pkg::pixel_t expected_image [0:OUTPUT_PIXELS-1];

  filter_top dut (
    .clk(clk),
    .rst(rst),
    .cfg_write_en_i(cfg_write_en_i),
    .filter_selection_i(filter_selection_i),
    .in_addr_i(in_addr_i),
    .out_addr_i(out_addr_i),
    .enable_i(enable_i),
    .busy_o(busy_o),
    .output_ready_o(output_ready_o),
    .error_o(error_o)
  );

  always #(CLK_PERIOD/2) clk = ~clk;

  always @(posedge clk) begin
    static int conv_valid_count = 0;
    static int write_req_count = 0;

    if (DEBUG && dut.conv_pixel_valid_w && (conv_valid_count < 8)) begin
      $display(
          "conv[%0d] valid pixel=%02x time=%0t",
          conv_valid_count,
          dut.conv_pixel_w,
          $time
      );
      conv_valid_count++;
    end

    if (DEBUG && dut.out_ram_req_w && dut.out_ram_we_w && (write_req_count < 8)) begin
      $display(
          "write[%0d] addr=%0d data=%02x time=%0t",
          write_req_count,
          dut.out_ram_addr_w,
          dut.out_ram_wdata_w,
          $time
      );
      write_req_count++;
    end
  end

  function automatic string filter_name(
      input filter_pkg::filter_type_e filter_sel
  );
    case (filter_sel)
      filter_pkg::SHARPENING: filter_name = "SHARPENING";
      filter_pkg::SMOOTHING: filter_name = "SMOOTHING";
      filter_pkg::EDGE_VERTICAL: filter_name = "EDGE_VERTICAL";
      filter_pkg::EDGE_HORIZONTAL: filter_name = "EDGE_HORIZONTAL";
      default: filter_name = "UNKNOWN";
    endcase
  endfunction

  function automatic string filter_file_name(
      input filter_pkg::filter_type_e filter_sel
  );
    case (filter_sel)
      filter_pkg::SHARPENING: filter_file_name = "sharpen";
      filter_pkg::SMOOTHING: filter_file_name = "gaussian";
      filter_pkg::EDGE_VERTICAL: filter_file_name = "vertical_edge";
      filter_pkg::EDGE_HORIZONTAL: filter_file_name = "horizontal_edge";
      default: filter_file_name = "unknown";
    endcase
  endfunction

  function automatic filter_pkg::filter_type_e filter_from_index(
      input int unsigned filter_idx
  );
    case (filter_idx)
      0: filter_from_index = filter_pkg::SHARPENING;
      1: filter_from_index = filter_pkg::SMOOTHING;
      2: filter_from_index = filter_pkg::EDGE_VERTICAL;
      3: filter_from_index = filter_pkg::EDGE_HORIZONTAL;
      default: filter_from_index = filter_pkg::SHARPENING;
    endcase
  endfunction

  function automatic string image_name(
      input int unsigned image_idx
  );
    case (image_idx)
      0: image_name = "center_impulse";
      1: image_name = "checkerboard_4px";
      2: image_name = "concentric_rings";
      3: image_name = "diagonal_step";
      4: image_name = "horizontal_gradient";
      5: image_name = "seeded_noise";
      6: image_name = "vertical_bars";
      7: image_name = "vertical_gradient";
      8: image_name = "lenna_64x64_gray";
      default: image_name = "unknown";
    endcase
  endfunction

  function automatic string image_input_file(
      input int unsigned image_idx
  );
    if (image_idx == 8) begin
      image_input_file = "tb/data/lenna_64x64_gray.hex";
    end else begin
      image_input_file = $sformatf("tb/data/generated/%s.hex", image_name(image_idx));
    end
  endfunction

  function automatic filter_pkg::ram_addr_t select_test_addr(
      input int unsigned test_idx,
      input int unsigned max_addr
  );
    begin
      case (test_idx)
        // test boundary addresses for first 2 cases, then randomize
        0: select_test_addr = '0;
        1: select_test_addr = filter_pkg::ram_addr_t'(max_addr);
        default: select_test_addr = filter_pkg::ram_addr_t'($urandom_range(max_addr, 0));
      endcase
    end
  endfunction

  function automatic filter_pkg::ram_addr_t test_in_addr(
      input int unsigned test_idx
  );
    test_in_addr = select_test_addr(test_idx, int'(filter_pkg::MAX_IN_ADDR));
  endfunction

  function automatic filter_pkg::ram_addr_t test_out_addr(
      input int unsigned test_idx
  );
    test_out_addr = select_test_addr(test_idx, int'(filter_pkg::MAX_OUT_ADDR));
  endfunction

  task automatic load_memories(
      input string input_file,
      input string expected_file,
      input filter_pkg::ram_addr_t in_base_addr,
      input filter_pkg::ram_addr_t out_base_addr
  );
    int idx;
    int in_base_int;
    int out_base_int;
    begin
      in_base_int = int'(in_base_addr);
      out_base_int = int'(out_base_addr);

      $readmemh(input_file, input_image);
      $readmemh(expected_file, expected_image);

      for (idx = 0; idx < INPUT_PIXELS; idx++) begin
        dut.input_ram_u.mem[in_base_int + idx] = input_image[idx];
      end

      for (idx = 0; idx < OUTPUT_PIXELS; idx++) begin
        dut.output_ram_u.mem[out_base_int + idx] = '0;
      end
    end
  endtask

  task automatic dump_actual_image(
      input string actual_file,
      input filter_pkg::ram_addr_t out_base_addr
  );
    int idx;
    int out_base_int;
    int file;
    begin
      out_base_int = int'(out_base_addr);
      file = $fopen(actual_file, "w");

      if (file == 0) begin
        $fatal(1, "failed to open actual output file: %s", actual_file);
      end

      for (idx = 0; idx < OUTPUT_PIXELS; idx++) begin
        $fdisplay(file, "%02x", dut.output_ram_u.mem[out_base_int + idx]);
      end

      $fclose(file);
    end
  endtask

  task automatic run_filter_test(
      input int unsigned test_idx,
      input int unsigned image_idx,
      input int unsigned filter_idx
  );
    int cycles_waited;
    int mismatches;
    int idx;
    int out_base_int;
    bit saw_busy;
    bit saw_error;
    string filter_display_name;
    string image_display_name;
    string input_file;
    string expected_file;
    string actual_file;
    filter_pkg::filter_type_e filter_sel;
    filter_pkg::ram_addr_t in_base_addr;
    filter_pkg::ram_addr_t out_base_addr;
    begin
      filter_sel = filter_from_index(filter_idx);
      filter_display_name = filter_name(filter_sel);
      image_display_name = image_name(image_idx);
      input_file = image_input_file(image_idx);
      expected_file = $sformatf("tb/data/expected/%s_%s.hex", image_display_name,
                                filter_file_name(filter_sel));
      actual_file = $sformatf("tb/data/actual/%s_%s.hex", image_display_name,
                              filter_file_name(filter_sel));
      in_base_addr = test_in_addr(test_idx);
      out_base_addr = test_out_addr(test_idx);
      out_base_int = int'(out_base_addr);

      load_memories(input_file, expected_file, in_base_addr, out_base_addr);

      @(posedge clk);
      if (busy_o || output_ready_o || error_o) begin
        $fatal(1, "%s/%s: outputs not idle before starting", image_display_name,
               filter_display_name);
      end

      // Set up configuration module
      filter_selection_i = filter_sel;
      in_addr_i = in_base_addr;
      out_addr_i = out_base_addr;
      cfg_write_en_i = 1'b1;

      @(posedge clk);
      cfg_write_en_i = 1'b0;

      // Start the computation
      @(posedge clk);
      enable_i = 1'b1;

      @(posedge clk);
      enable_i = 1'b0;

      cycles_waited = 0;
      mismatches = 0;
      saw_busy = 1'b0;
      saw_error = 1'b0;

      // Wait for output ready signal or timeout
      while (!output_ready_o && (cycles_waited < MAX_WAIT_CYCLES)) begin
        @(posedge clk);
        cycles_waited++;

        if (busy_o) begin
          saw_busy = 1'b1;
        end

        if (error_o) begin
          saw_error = 1'b1;
        end
      end

      if (!output_ready_o) begin
        $fatal(1, "%s/%s: timed out waiting for output_ready_o after %0d cycles",
               image_display_name, filter_display_name, MAX_WAIT_CYCLES);
      end

      if (busy_o) begin
        $fatal(1, "%s/%s: busy_o should be low when output_ready_o is asserted",
               image_display_name, filter_display_name);
      end

      if (!saw_busy) begin
        $fatal(1, "%s/%s: busy_o never asserted during the run", image_display_name,
               filter_display_name);
      end

      if (saw_error || error_o) begin
        $fatal(1, "%s/%s: error_o asserted during functional test", image_display_name,
               filter_display_name);
      end

      @(posedge clk);
      if (output_ready_o) begin
        $fatal(1, "%s/%s: output_ready_o should pulse for one cycle", image_display_name,
               filter_display_name);
      end

      dump_actual_image(actual_file, out_base_addr);

      // Compare expected and actual RAM content
      for (idx = 0; idx < OUTPUT_PIXELS; idx++) begin
        if (dut.output_ram_u.mem[out_base_int + idx] !== expected_image[idx]) begin
          mismatches++;
          if (mismatches <= 8) begin
            $display(
                "%s/%s mismatch at output index %0d (addr %0d): got %02x expected %02x",
                image_display_name,
                filter_display_name,
                idx,
                out_base_int + idx,
                dut.output_ram_u.mem[out_base_int + idx],
                expected_image[idx]
            );
          end
        end
      end

      if (mismatches != 0) begin
        $fatal(1, "%s/%s: detected %0d output mismatches", image_display_name,
               filter_display_name, mismatches);
      end

      $display(
          "PASS: %s/%s functional test completed in %0d cycles.",
          image_display_name,
          filter_display_name,
          cycles_waited
      );
    end
  endtask
  
  initial begin
`ifdef SAIF_TRACE
    $dumpfile("activity.saif");
    $dumpvars(0, filter_top_tb.dut);
`else
    $dumpfile("waves.fst");
    $dumpvars(0, filter_top_tb);
`endif
  end

  initial begin
    int unsigned image_idx;
    int unsigned filter_idx;
    int unsigned test_idx;

    clk = 1'b0;
    rst = 1'b0;
    cfg_write_en_i = 1'b0;
    filter_selection_i = filter_pkg::SHARPENING;
    in_addr_i = '0;
    out_addr_i = '0;
    enable_i = 1'b0;

    void'($urandom(ADDR_RANDOM_SEED));
    void'($system("mkdir -p tb/data/actual"));

    repeat (4) @(posedge clk);
    rst = 1'b1;

    test_idx = 0;
    for (image_idx = 0; image_idx < NUM_IMAGES; image_idx++) begin
      for (filter_idx = 0; filter_idx < NUM_FILTERS; filter_idx++) begin
        run_filter_test(test_idx, image_idx, filter_idx);
        test_idx++;
      end
    end

    $display("PASS: all %0d functional tests completed successfully", test_idx);
    $finish;
  end

endmodule
