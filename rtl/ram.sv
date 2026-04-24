`timescale 1ns/1ps

// Simple RAM module used for both input and output RAM in the filter.
module ram #(
  parameter string INIT_FILE = ""
) (
  input  logic                  clk,
  input  logic                  req_i,
  input  logic                  we_i,
  input  filter_pkg::ram_addr_t addr_i,
  input  filter_pkg::pixel_t    wdata_i,
  output logic                  ready_o,
  output filter_pkg::pixel_t    rdata_o
);

  filter_pkg::pixel_t mem [filter_pkg::RAM_SIZE];
  logic ready_q;
  filter_pkg::pixel_t rdata_q;

  assign ready_o = ready_q;
  assign rdata_o = rdata_q;

  initial begin
    ready_q = 1'b0;
    rdata_q = '0;
    if (INIT_FILE != "") begin
      $readmemh(INIT_FILE, mem);
    end
  end

  always_ff @(posedge clk) begin
    ready_q <= req_i;

    if (req_i && !we_i) begin
      rdata_q <= mem[addr_i];
    end

    if (req_i && we_i) begin
      mem[addr_i] <= wdata_i;
    end
  end

endmodule
