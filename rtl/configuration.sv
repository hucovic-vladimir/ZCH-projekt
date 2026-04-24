`timescale 1ns/1ps

// Configuration module that stores convolution parameters
// (in/out addresses, selected filter)
module configuration (
  input  logic                     clk,
  input  logic                     rst,
  input  logic                     cfg_write_en_i,
  input  filter_pkg::filter_type_e filter_sel_i,
  input  filter_pkg::ram_addr_t    in_addr_i,
  input  filter_pkg::ram_addr_t    out_addr_i,
  output filter_pkg::filter_type_e filter_sel_o,
  output filter_pkg::ram_addr_t    in_addr_o,
  output filter_pkg::ram_addr_t    out_addr_o
);

  filter_pkg::filter_type_e filter_sel_q;
  filter_pkg::ram_addr_t    in_addr_q;
  filter_pkg::ram_addr_t    out_addr_q;

  // Latch input values on rising clk 
  always_ff @(posedge clk or negedge rst) begin
    if (!rst) begin
      filter_sel_q <= filter_pkg::SHARPENING;
      in_addr_q    <= '0;
      out_addr_q   <= '0;
    end else if (cfg_write_en_i) begin
      filter_sel_q <= filter_sel_i;
      in_addr_q    <= in_addr_i;
      out_addr_q   <= out_addr_i;
    end
  end

  assign filter_sel_o = filter_sel_q;
  assign in_addr_o    = in_addr_q;
  assign out_addr_o   = out_addr_q;

endmodule
