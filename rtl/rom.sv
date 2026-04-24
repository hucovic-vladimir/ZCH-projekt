`timescale 1ns/1ps

// ROM module that stores the kernel weights and scale shifts. 
module rom (
  input  filter_pkg::filter_type_e filter_sel_i,
  output filter_pkg::kernel_t      kernel_o,
  output filter_pkg::scale_shift_t scale_shift_o
);

  filter_pkg::kernel_t      kernel_q;
  filter_pkg::scale_shift_t scale_shift_q;

  assign kernel_o = kernel_q;
  assign scale_shift_o = scale_shift_q;

  always_comb begin
    kernel_q[0][0] = 4'sd0;
    kernel_q[0][1] = 4'sd0;
    kernel_q[0][2] = 4'sd0;
    kernel_q[1][0] = 4'sd0;
    kernel_q[1][1] = 4'sd0;
    kernel_q[1][2] = 4'sd0;
    kernel_q[2][0] = 4'sd0;
    kernel_q[2][1] = 4'sd0;
    kernel_q[2][2] = 4'sd0;
    scale_shift_q = '0;

    unique case (filter_sel_i)
      filter_pkg::SHARPENING: kernel_q = '{
          '{ 4'sd0, -4'sd1,  4'sd0},
          '{-4'sd1,  4'sd5, -4'sd1},
          '{ 4'sd0, -4'sd1,  4'sd0}
      };

      filter_pkg::SMOOTHING: begin
        kernel_q = '{
            '{4'sd1, 4'sd2, 4'sd1},
            '{4'sd2, 4'sd4, 4'sd2},
            '{4'sd1, 4'sd2, 4'sd1}
        };
        scale_shift_q = 3'd4;
      end

      filter_pkg::EDGE_VERTICAL: kernel_q = '{
          '{-4'sd1, 4'sd0, 4'sd1},
          '{-4'sd2, 4'sd0, 4'sd2},
          '{-4'sd1, 4'sd0, 4'sd1}
      };

      filter_pkg::EDGE_HORIZONTAL: kernel_q = '{
          '{-4'sd1, -4'sd2, -4'sd1},
          '{ 4'sd0,  4'sd0,  4'sd0},
          '{ 4'sd1,  4'sd2,  4'sd1}
      };
    endcase
  end

endmodule
