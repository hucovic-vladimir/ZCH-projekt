`timescale 1ns/1ps

// Input buffer module that stores 4 lines of input image (3 for window,
// 1 extra for pre-filling). Has multiple states: 
// - IDLE -> no request was made yet or after computation finished 
// - PREFILL -> computation has started and the line-buffers are not yet filled
//  (window not ready)
// - STREAM -> line buffers filled, window is ready, continues reading into
// extra line buffer while constructing windows
// - ROTATE -> rotates line buffers so that each line shifts one row up
// - DRAIN -> last rows of picture were read, nothing else to read, simply
// passes windows to conv pipeline 
module input_buffer (
  input  logic                  clk,
  input  logic                  rst,
  input  filter_pkg::ram_addr_t in_addr_i,
  input  logic                  enable_i,
  input  logic                  ram_data_ready_i,
  input  filter_pkg::pixel_t    ram_data_i,
  output logic                  ram_req_o,
  output filter_pkg::ram_addr_t ram_addr_o,
  output logic                  window_ready_o,
  output filter_pkg::window_t   window_o
);

  localparam int ROW_W = (filter_pkg::IN_IMAGE_H <= 1) ? 1 : $clog2(filter_pkg::IN_IMAGE_H + 1);
  localparam int BUF_ROW_W = (filter_pkg::KERNEL_SIZE <= 1) ? 1 : $clog2(filter_pkg::KERNEL_SIZE);
  localparam int COL_W = (filter_pkg::IN_IMAGE_W <= 1) ? 1 : $clog2(filter_pkg::IN_IMAGE_W);
  localparam int OUT_COL_W = (filter_pkg::OUT_IMAGE_W <= 1) ? 1 : $clog2(filter_pkg::OUT_IMAGE_W);
  localparam logic [ROW_W-1:0] PREFILL_LAST_ROW = ROW_W'(filter_pkg::KERNEL_SIZE - 1);
  localparam logic [ROW_W-1:0] FIRST_STREAM_ROW = ROW_W'(filter_pkg::KERNEL_SIZE);
  localparam logic [ROW_W-1:0] LAST_STREAM_ROW =
      ROW_W'(filter_pkg::OUT_IMAGE_H + filter_pkg::KERNEL_SIZE - 2);
  localparam logic [COL_W-1:0] LAST_IN_COL = COL_W'(filter_pkg::IN_IMAGE_W - 1);
  localparam logic [COL_W-1:0] LAST_OUT_COL = COL_W'(filter_pkg::OUT_IMAGE_W - 1);
  localparam logic [OUT_COL_W-1:0] LAST_DRAIN_COL = OUT_COL_W'(filter_pkg::OUT_IMAGE_W - 1);

  typedef enum logic [2:0] {
    IDLE,
    PREFILL,
    STREAM,
    ROTATE,
    DRAIN
  } state_e;

  state_e state_q;

  filter_pkg::pixel_t rows [0:filter_pkg::KERNEL_SIZE-1][0:filter_pkg::IN_IMAGE_W-1];
  filter_pkg::pixel_t extra_row [0:filter_pkg::IN_IMAGE_W-1];

  logic [ROW_W-1:0] req_row_q;
  logic [COL_W-1:0] req_col_q;
  logic [ROW_W-1:0] resp_row_q;
  logic [COL_W-1:0] resp_col_q;
  logic [OUT_COL_W-1:0] drain_col_q;
  logic ram_req_q;
  logic window_ready_q;
  filter_pkg::ram_addr_t ram_addr_q;
  filter_pkg::window_t window_q;

  assign ram_req_o = ram_req_q;
  assign ram_addr_o = ram_addr_q;
  assign window_o = window_q;
  assign window_ready_o = window_ready_q;

  always_ff @(posedge clk or negedge rst) begin
    if (!rst) begin
      state_q <= IDLE;
      req_row_q <= '0;
      req_col_q <= '0;
      resp_row_q <= '0;
      resp_col_q <= '0;
      drain_col_q <= '0;
      ram_req_q <= 1'b0;
      ram_addr_q <= '0;
      window_ready_q <= 1'b0;
      window_q[0][0] <= '0;
      window_q[0][1] <= '0;
      window_q[0][2] <= '0;
      window_q[1][0] <= '0;
      window_q[1][1] <= '0;
      window_q[1][2] <= '0;
      window_q[2][0] <= '0;
      window_q[2][1] <= '0;
      window_q[2][2] <= '0;
    end else begin
      int col_idx;

      window_ready_q <= 1'b0;

      case (state_q)
        IDLE: begin
          ram_req_q <= 1'b0;
          if (enable_i) begin
            state_q <= PREFILL;
            req_row_q <= '0;
            req_col_q <= '0;
            resp_row_q <= '0;
            resp_col_q <= '0;
            drain_col_q <= '0;
            ram_req_q <= 1'b1;
            ram_addr_q <= in_addr_i;
          end
        end

        PREFILL: begin
          if (ram_req_q) begin
            ram_addr_q <= ram_addr_q + 1'b1;

            if (req_col_q == LAST_IN_COL) begin
              req_col_q <= '0;
              if (req_row_q == PREFILL_LAST_ROW) begin
                ram_req_q <= 1'b0;
              end else begin
                req_row_q <= req_row_q + 1'b1;
              end
            end else begin
              req_col_q <= req_col_q + 1'b1;
            end
          end

          if (ram_data_ready_i) begin
            rows[resp_row_q[BUF_ROW_W-1:0]][resp_col_q] <= ram_data_i;

            if (resp_col_q == LAST_IN_COL) begin
              resp_col_q <= '0;
              if (resp_row_q == PREFILL_LAST_ROW) begin
                state_q <= STREAM;
                req_row_q <= FIRST_STREAM_ROW;
                req_col_q <= '0;
                resp_row_q <= FIRST_STREAM_ROW;
                resp_col_q <= '0;
                ram_req_q <= 1'b1;
              end else begin
                resp_row_q <= resp_row_q + 1'b1;
              end
            end else begin
              resp_col_q <= resp_col_q + 1'b1;
            end
          end
        end

        STREAM: begin
          if (ram_req_q) begin
            ram_addr_q <= ram_addr_q + 1'b1;

            if (req_col_q == LAST_IN_COL) begin
              req_col_q <= '0;
              ram_req_q <= 1'b0;
            end else begin
              req_col_q <= req_col_q + 1'b1;
            end
          end

          if (ram_data_ready_i) begin
            extra_row[resp_col_q] <= ram_data_i;

            if (resp_col_q <= LAST_OUT_COL) begin
              window_q[0][0] <= rows[0][resp_col_q];
              window_q[0][1] <= rows[0][resp_col_q + 1];
              window_q[0][2] <= rows[0][resp_col_q + 2];
              window_q[1][0] <= rows[1][resp_col_q];
              window_q[1][1] <= rows[1][resp_col_q + 1];
              window_q[1][2] <= rows[1][resp_col_q + 2];
              window_q[2][0] <= rows[2][resp_col_q];
              window_q[2][1] <= rows[2][resp_col_q + 1];
              window_q[2][2] <= rows[2][resp_col_q + 2];
              window_ready_q <= 1'b1;
            end

            if (resp_col_q == LAST_IN_COL) begin
              resp_col_q <= '0;
              state_q <= ROTATE;
            end else begin
              resp_col_q <= resp_col_q + 1'b1;
            end
          end
        end

        ROTATE: begin
          for (col_idx = 0; col_idx < filter_pkg::IN_IMAGE_W; col_idx++) begin
            rows[0][col_idx] <= rows[1][col_idx];
            rows[1][col_idx] <= rows[2][col_idx];
            rows[2][col_idx] <= extra_row[col_idx];
          end

          if (resp_row_q == LAST_STREAM_ROW) begin
            drain_col_q <= '0;
            ram_req_q <= 1'b0;
            state_q <= DRAIN;
          end else begin
            req_row_q <= resp_row_q + 1'b1;
            req_col_q <= '0;
            resp_row_q <= resp_row_q + 1'b1;
            resp_col_q <= '0;
            ram_req_q <= 1'b1;
            state_q <= STREAM;
          end
        end

        DRAIN: begin
          ram_req_q <= 1'b0;
          window_q[0][0] <= rows[0][drain_col_q];
          window_q[0][1] <= rows[0][drain_col_q + 1];
          window_q[0][2] <= rows[0][drain_col_q + 2];
          window_q[1][0] <= rows[1][drain_col_q];
          window_q[1][1] <= rows[1][drain_col_q + 1];
          window_q[1][2] <= rows[1][drain_col_q + 2];
          window_q[2][0] <= rows[2][drain_col_q];
          window_q[2][1] <= rows[2][drain_col_q + 1];
          window_q[2][2] <= rows[2][drain_col_q + 2];
          window_ready_q <= 1'b1;

          if (drain_col_q == LAST_DRAIN_COL) begin
            state_q <= IDLE;
          end else begin
            drain_col_q <= drain_col_q + 1'b1;
          end
        end

        default: begin
          state_q <= IDLE;
          ram_req_q <= 1'b0;
        end
      endcase
    end
  end

endmodule
