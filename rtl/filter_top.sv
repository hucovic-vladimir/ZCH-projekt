`timescale 1ns/1ps

module filter_top #(
  parameter string INPUT_RAM_INIT_FILE = "",
  parameter string OUTPUT_RAM_INIT_FILE = ""
) (
  input  logic                     clk,
  input  logic                     rst,
  input  logic                     cfg_write_en_i,
  input  filter_pkg::filter_type_e filter_selection_i,
  input  filter_pkg::ram_addr_t    in_addr_i,
  input  filter_pkg::ram_addr_t    out_addr_i,
  input  logic                     enable_i,
  output logic                     busy_o,
  output logic                     output_ready_o,
  output logic                     error_o
);

  // Latches assigned to output
  logic enable_q;
  logic busy_q;
  logic output_ready_q;
  logic error_q;

  // Start signals
  logic start_req_w;
  logic start_accept_w;
  logic start_error_w;
  // if 0, addr is invalid and module won't run
  logic addr_valid_w;


  // config module i/o
  filter_pkg::filter_type_e filter_sel_w;
  filter_pkg::ram_addr_t    cfg_in_addr_w;
  filter_pkg::ram_addr_t    cfg_out_addr_w;
  filter_pkg::kernel_t      kernel_w;
  filter_pkg::scale_shift_t scale_shift_w;

  // input ram signals i/o
  logic                     in_ram_req_w;
  filter_pkg::ram_addr_t    in_ram_addr_w;
  logic                     in_ram_ready_w;
  filter_pkg::pixel_t       in_ram_rdata_w;

  // input buffer i/o
  logic                     window_ready_w;
  filter_pkg::window_t      window_w;

  // convolution module i/o
  filter_pkg::pixel_t       conv_pixel_w;
  logic                     conv_pixel_valid_w;

  // output ram i/o
  logic                     out_ram_req_w;
  logic                     out_ram_we_w;
  filter_pkg::ram_addr_t    out_ram_addr_w;
  filter_pkg::pixel_t       out_ram_wdata_w;
  logic                     out_ram_ready_w;
  filter_pkg::pixel_t       out_ram_rdata_unused_w;
  logic                     out_buf_busy_unused_w;
  logic                     output_done_w;
  logic                     _unused_ok;

  assign start_req_w = enable_i && !enable_q;
  assign addr_valid_w = (cfg_in_addr_w <= filter_pkg::MAX_IN_ADDR) &&
    (cfg_out_addr_w <= filter_pkg::MAX_OUT_ADDR);
  assign start_accept_w = start_req_w && !busy_q && addr_valid_w;
  assign start_error_w = start_req_w && (busy_q || !addr_valid_w);

  assign busy_o = busy_q;
  assign output_ready_o = output_ready_q;
  assign error_o = error_q;
  assign _unused_ok = &{1'b0, out_buf_busy_unused_w, out_ram_rdata_unused_w};

  always_ff @(posedge clk or negedge rst) begin
    if (!rst) begin
      enable_q <= 1'b0;
      busy_q <= 1'b0;
      output_ready_q <= 1'b0;
      error_q <= 1'b0;
    end else begin
      enable_q <= enable_i;
      output_ready_q <= 1'b0;
      error_q <= 1'b0;

      if (start_error_w) begin
        error_q <= 1'b1;
      end

      if (start_accept_w) begin
        busy_q <= 1'b1;
      end else if (busy_q && output_done_w) begin
        busy_q <= 1'b0;
        output_ready_q <= 1'b1;
      end
    end
  end

  configuration configuration_u (
    .clk(clk),
    .rst(rst),
    .cfg_write_en_i(cfg_write_en_i && !busy_q),
    .filter_sel_i(filter_selection_i),
    .in_addr_i(in_addr_i),
    .out_addr_i(out_addr_i),
    .filter_sel_o(filter_sel_w),
    .in_addr_o(cfg_in_addr_w),
    .out_addr_o(cfg_out_addr_w)
  );

  rom rom_u (
    .filter_sel_i(filter_sel_w),
    .kernel_o(kernel_w),
    .scale_shift_o(scale_shift_w)
  );

  input_buffer input_buffer_u (
    .clk(clk),
    .rst(rst),
    .in_addr_i(cfg_in_addr_w),
    .enable_i(start_accept_w),
    .ram_data_ready_i(in_ram_ready_w),
    .ram_data_i(in_ram_rdata_w),
    .ram_req_o(in_ram_req_w),
    .ram_addr_o(in_ram_addr_w),
    .window_ready_o(window_ready_w),
    .window_o(window_w)
  );

  convolution_core convolution_core_u (
    .clk(clk),
    .rst(rst),
    .window_valid_i(window_ready_w),
    .kernel_i(kernel_w),
    .window_i(window_w),
    .scale_shift_i(scale_shift_w),
    .pixel_o(conv_pixel_w),
    .pixel_valid_o(conv_pixel_valid_w)
  );

  output_buffer output_buffer_u (
    .clk(clk),
    .rst(rst),
    .enable_i(start_accept_w),
    .out_addr_i(cfg_out_addr_w),
    .pixel_valid_i(conv_pixel_valid_w),
    .pixel_i(conv_pixel_w),
    .ram_ready_i(out_ram_ready_w),
    .ram_req_o(out_ram_req_w),
    .ram_we_o(out_ram_we_w),
    .ram_addr_o(out_ram_addr_w),
    .ram_wdata_o(out_ram_wdata_w),
    .busy_o(out_buf_busy_unused_w),
    .done_o(output_done_w)
  );

  ram #(
    .INIT_FILE(INPUT_RAM_INIT_FILE)
  ) input_ram_u (
    .clk(clk),
    .req_i(in_ram_req_w),
    .we_i(1'b0),
    .addr_i(in_ram_addr_w),
    .wdata_i('0),
    .ready_o(in_ram_ready_w),
    .rdata_o(in_ram_rdata_w)
  );

  ram #(
    .INIT_FILE(OUTPUT_RAM_INIT_FILE)
  ) output_ram_u (
    .clk(clk),
    .req_i(out_ram_req_w),
    .we_i(out_ram_we_w),
    .addr_i(out_ram_addr_w),
    .wdata_i(out_ram_wdata_w),
    .ready_o(out_ram_ready_w),
    .rdata_o(out_ram_rdata_unused_w)
  );

endmodule
