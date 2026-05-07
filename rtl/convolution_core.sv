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
  input  logic                     abs_result_i,
  output filter_pkg::pixel_t       pixel_o,
  output logic                     pixel_valid_o
);

  localparam int ACC_W = filter_pkg::PIXEL_W + 8;
  localparam int PROD_COUNT = filter_pkg::KERNEL_SIZE * filter_pkg::KERNEL_SIZE;
  localparam logic signed [ACC_W-1:0] PIXEL_MAX =
      ACC_W'((1 << filter_pkg::PIXEL_W) - 1);

  logic signed [ACC_W-1:0] prod_d [0:PROD_COUNT-1];
  logic signed [ACC_W-1:0] prod_q [0:PROD_COUNT-1];
  filter_pkg::scale_shift_t shift_d;
  filter_pkg::scale_shift_t shift_q;
  logic abs_result_d;
  logic abs_result_q;
  logic valid_mul_d;
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
  logic signed [ACC_W-1:0] accum_magnitude;
  filter_pkg::pixel_t pixel_d;
  filter_pkg::pixel_t pixel_q;
  logic pixel_valid_d;

  assign pixel_o = pixel_q;

  // 1st stage work: multiply.
  always_comb begin
    prod_d[0] = $signed(kernel_i[0][0]) * $signed({1'b0, window_i[0][0]});
    prod_d[1] = $signed(kernel_i[0][1]) * $signed({1'b0, window_i[0][1]});
    prod_d[2] = $signed(kernel_i[0][2]) * $signed({1'b0, window_i[0][2]});
    prod_d[3] = $signed(kernel_i[1][0]) * $signed({1'b0, window_i[1][0]});
    prod_d[4] = $signed(kernel_i[1][1]) * $signed({1'b0, window_i[1][1]});
    prod_d[5] = $signed(kernel_i[1][2]) * $signed({1'b0, window_i[1][2]});
    prod_d[6] = $signed(kernel_i[2][0]) * $signed({1'b0, window_i[2][0]});
    prod_d[7] = $signed(kernel_i[2][1]) * $signed({1'b0, window_i[2][1]});
    prod_d[8] = $signed(kernel_i[2][2]) * $signed({1'b0, window_i[2][2]});

    shift_d = scale_shift_i;
    abs_result_d = abs_result_i;
    valid_mul_d = window_valid_i;
  end

  // 2nd stage work: add + shift + clamp.
  always_comb begin
    pixel_valid_d = valid_mul_q;

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

    if (abs_result_q && (accum_shifted < 0)) begin
      accum_magnitude = -accum_shifted;
    end else begin
      accum_magnitude = accum_shifted;
    end

    if (accum_magnitude > PIXEL_MAX) begin
      pixel_d = '1;
    end else if (accum_magnitude < 0) begin
      pixel_d = '0;
    end else begin
      pixel_d = filter_pkg::pixel_t'(accum_magnitude);
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
      abs_result_q <= 1'b0;
      valid_mul_q <= 1'b0;
      pixel_q <= '0;
      pixel_valid_o <= 1'b0;
    end else begin
      prod_q[0] <= prod_d[0];
      prod_q[1] <= prod_d[1];
      prod_q[2] <= prod_d[2];
      prod_q[3] <= prod_d[3];
      prod_q[4] <= prod_d[4];
      prod_q[5] <= prod_d[5];
      prod_q[6] <= prod_d[6];
      prod_q[7] <= prod_d[7];
      prod_q[8] <= prod_d[8];
      shift_q <= shift_d;
      abs_result_q <= abs_result_d;
      valid_mul_q <= valid_mul_d;

      pixel_q <= pixel_d;
      pixel_valid_o <= pixel_valid_d;
    end
  end

endmodule
