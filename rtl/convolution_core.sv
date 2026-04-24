`timescale 1ns/1ps

// Module that handles convolution
// 2 pipeline steps: Multiply and Accumulate + Shift + Clamp
module convolution_core (
  input  logic                     clk,
  input  logic                     rst,
  input  logic                     window_valid_i,
  input  filter_pkg::kernel_t      kernel_i,
  input  filter_pkg::window_t      window_i,
  input  filter_pkg::scale_shift_t scale_shift_i,
  output filter_pkg::pixel_t       pixel_o,
  output logic                     pixel_valid_o
);

  localparam int ACC_W = filter_pkg::PIXEL_W + 8;
  localparam int PROD_COUNT = filter_pkg::KERNEL_SIZE * filter_pkg::KERNEL_SIZE;
  localparam logic signed [ACC_W-1:0] PIXEL_MAX =
      ACC_W'((1 << filter_pkg::PIXEL_W) - 1);

  logic signed [ACC_W-1:0] prod_q [0:PROD_COUNT-1];
  filter_pkg::scale_shift_t shift_q;
  logic valid_mul_q;

  logic signed [ACC_W-1:0] sum_l1_0;
  logic signed [ACC_W-1:0] sum_l1_1;
  logic signed [ACC_W-1:0] sum_l1_2;
  logic signed [ACC_W-1:0] sum_l1_3;
  logic signed [ACC_W-1:0] sum_l1_4;
  logic signed [ACC_W-1:0] sum_l2_0;
  logic signed [ACC_W-1:0] sum_l2_1;
  logic signed [ACC_W-1:0] sum_l2_2;
  logic signed [ACC_W-1:0] sum_l3_0;
  logic signed [ACC_W-1:0] accum_shifted;
  filter_pkg::pixel_t pixel_d;
  filter_pkg::pixel_t pixel_q;

  assign pixel_o = pixel_q;

  always_comb begin
    sum_l1_0 = prod_q[0] + prod_q[1];
    sum_l1_1 = prod_q[2] + prod_q[3];
    sum_l1_2 = prod_q[4] + prod_q[5];
    sum_l1_3 = prod_q[6] + prod_q[7];
    sum_l1_4 = prod_q[8];

    sum_l2_0 = sum_l1_0 + sum_l1_1;
    sum_l2_1 = sum_l1_2 + sum_l1_3;
    sum_l2_2 = sum_l1_4;

    sum_l3_0 = sum_l2_0 + sum_l2_1;
    accum_shifted = (sum_l3_0 + sum_l2_2) >>> shift_q;

    if (accum_shifted > PIXEL_MAX) begin
      pixel_d = '1;
    end else if (accum_shifted < 0) begin
      pixel_d = '0;
    end else begin
      pixel_d = filter_pkg::pixel_t'(accum_shifted);
    end
  end

  always_ff @(posedge clk or negedge rst) begin
    if (!rst) begin
      prod_q[0] <= '0;
      prod_q[1] <= '0;
      prod_q[2] <= '0;
      prod_q[3] <= '0;
      prod_q[4] <= '0;
      prod_q[5] <= '0;
      prod_q[6] <= '0;
      prod_q[7] <= '0;
      prod_q[8] <= '0;
      shift_q <= '0;
      valid_mul_q <= 1'b0;
      pixel_q <= '0;
      pixel_valid_o <= 1'b0;
    end else begin
      prod_q[0] <= $signed(kernel_i[0][0]) * $signed({1'b0, window_i[0][0]});
      prod_q[1] <= $signed(kernel_i[0][1]) * $signed({1'b0, window_i[0][1]});
      prod_q[2] <= $signed(kernel_i[0][2]) * $signed({1'b0, window_i[0][2]});
      prod_q[3] <= $signed(kernel_i[1][0]) * $signed({1'b0, window_i[1][0]});
      prod_q[4] <= $signed(kernel_i[1][1]) * $signed({1'b0, window_i[1][1]});
      prod_q[5] <= $signed(kernel_i[1][2]) * $signed({1'b0, window_i[1][2]});
      prod_q[6] <= $signed(kernel_i[2][0]) * $signed({1'b0, window_i[2][0]});
      prod_q[7] <= $signed(kernel_i[2][1]) * $signed({1'b0, window_i[2][1]});
      prod_q[8] <= $signed(kernel_i[2][2]) * $signed({1'b0, window_i[2][2]});
      shift_q <= scale_shift_i;
      valid_mul_q <= window_valid_i;

      pixel_q <= pixel_d;
      pixel_valid_o <= valid_mul_q;
    end
  end

endmodule
