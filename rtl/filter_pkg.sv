`timescale 1ns/1ps

package filter_pkg;
  parameter int IN_IMAGE_W = 64;
  parameter int IN_IMAGE_H = 64;
  parameter int RAM_ADDR_SIZE = 16;
  parameter int PIXEL_W = 8;
  parameter int KERNEL_SIZE = 3;

  parameter int OUT_IMAGE_W = IN_IMAGE_W - KERNEL_SIZE + 1;
  parameter int OUT_IMAGE_H = IN_IMAGE_H - KERNEL_SIZE + 1;

  parameter int RAM_SIZE = 1 << RAM_ADDR_SIZE;
  parameter int INPUT_IMAGE_PIXELS = IN_IMAGE_W * IN_IMAGE_H;
  parameter int OUTPUT_IMAGE_PIXELS = OUT_IMAGE_W * OUT_IMAGE_H;


  typedef logic [PIXEL_W-1 : 0] pixel_t;
  typedef pixel_t window_t [0 : KERNEL_SIZE-1][0 : KERNEL_SIZE-1];

  typedef logic signed [3:0] coeff_t;
  typedef coeff_t kernel_t [0 : KERNEL_SIZE-1][0 : KERNEL_SIZE-1];

  typedef logic [2:0] scale_shift_t;

  typedef logic [RAM_ADDR_SIZE-1 : 0] ram_addr_t;

  parameter ram_addr_t MAX_IN_ADDR = ram_addr_t'(RAM_SIZE - INPUT_IMAGE_PIXELS);
  parameter ram_addr_t MAX_OUT_ADDR = ram_addr_t'(RAM_SIZE - OUTPUT_IMAGE_PIXELS);

  typedef enum logic [1:0] {
    SHARPENING,
    SMOOTHING,
    EDGE_VERTICAL,
    EDGE_HORIZONTAL
  } filter_type_e;

  endpackage
