`timescale 1ns/1ps

// Output buffer that accepts results from convolution pipeline and 
// writes them to output ram.
module output_buffer (
  input  logic                  clk,
  input  logic                  rst,
  input  logic                  enable_i,
  input  filter_pkg::ram_addr_t out_addr_i,
  input  logic                  pixel_valid_i,
  input  filter_pkg::pixel_t    pixel_i,
  input  logic                  ram_ready_i,
  output logic                  ram_req_o,
  output logic                  ram_we_o,
  output filter_pkg::ram_addr_t ram_addr_o,
  output filter_pkg::pixel_t    ram_wdata_o,
  output logic                  busy_o,
  output logic                  done_o
);

  localparam int TOTAL_PIXELS = filter_pkg::OUT_IMAGE_W * filter_pkg::OUT_IMAGE_H;
  localparam int COUNT_W = (TOTAL_PIXELS <= 1) ? 1 : $clog2(TOTAL_PIXELS + 1);
  localparam int ADDR_W = $bits(filter_pkg::ram_addr_t);
  localparam logic [COUNT_W-1:0] TOTAL_PIXEL_COUNT = COUNT_W'(TOTAL_PIXELS);
  localparam logic [COUNT_W-1:0] LAST_PIXEL_IDX = COUNT_W'(TOTAL_PIXELS - 1);

  filter_pkg::ram_addr_t base_addr_q;
  logic [COUNT_W-1:0] issued_count_q;
  logic [COUNT_W-1:0] committed_count_q;
  logic busy_q;
  logic done_q;
  logic ram_req_q;
  logic ram_we_q;
  filter_pkg::ram_addr_t ram_addr_q;
  filter_pkg::pixel_t ram_wdata_q;

  assign ram_req_o = ram_req_q;
  assign ram_we_o = ram_we_q;
  assign ram_addr_o = ram_addr_q;
  assign ram_wdata_o = ram_wdata_q;
  assign busy_o = busy_q;
  assign done_o = done_q;

  always_ff @(posedge clk or negedge rst) begin
    if (!rst) begin
      base_addr_q <= '0;
      issued_count_q <= '0;
      committed_count_q <= '0;
      busy_q <= 1'b0;
      done_q <= 1'b0;
      ram_req_q <= 1'b0;
      ram_we_q <= 1'b0;
      ram_addr_q <= '0;
      ram_wdata_q <= '0;
    end else begin
      done_q <= 1'b0;
      ram_req_q <= 1'b0;
      ram_we_q <= 1'b0;

      if (enable_i && !busy_q) begin
        base_addr_q <= out_addr_i;
        issued_count_q <= '0;
        committed_count_q <= '0;
        busy_q <= 1'b1;
      end

      if (busy_q) begin
        if (pixel_valid_i && (issued_count_q < TOTAL_PIXEL_COUNT)) begin
          ram_req_q <= 1'b1;
          ram_we_q <= 1'b1;
          ram_addr_q <= base_addr_q + ADDR_W'(issued_count_q);
          ram_wdata_q <= pixel_i;
          issued_count_q <= issued_count_q + 1'b1;
        end

        if (ram_ready_i) begin
          if (committed_count_q == LAST_PIXEL_IDX) begin
            committed_count_q <= '0;
            busy_q <= 1'b0;
            done_q <= 1'b1;
          end else begin
            committed_count_q <= committed_count_q + 1'b1;
          end
        end
      end
    end
  end

endmodule
