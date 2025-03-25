//-----------------------------------------------------------------------------
// Module: controller.v
// Author: Nguyen Trinh
// Created: Jan 10, 2025
// Last Updated: March 23, 2025
// 
// State machine based controller for the mm accelerator. The controller accepts
// the dimension of matrices, base addresses of where to read or where to write,
// and the start signal and then generates control signals for all components.
//
`ifndef _CONTROLLER_V
`define _CONTROLLER_V
`include "def.v"

module controller (
  input wire clk_i,
  input wire rst_ni,
  input wire start_i,
  input wire [`ADDR_WIDTH-1:0] base_addra_i,
  input wire [`ADDR_WIDTH-1:0] base_addrb_i,
  input wire [`ADDR_WIDTH-1:0] base_addrp_i,
  input wire [3:0] k_i,
  input wire [3:0] m_i,
  input wire [3:0] n_i,
  output reg valid_o,
  output reg ena_o,
  output reg enb_o,
  output reg enp_o,
  output reg wep_o,
  output reg [`ADDR_WIDTH-1:0] addra_o,
  output reg [`ADDR_WIDTH-1:0] addrb_o,
  output reg [`ADDR_WIDTH-1:0] addrp_o,
  output reg [3:0] wordp_sel_o,
  output reg ensys_o,
  output reg pe_we_o,
  output reg pe_clr_o
);

  // FSM states
  localparam IDLE = 2'd0, BUSY = 2'd1, DONE = 2'd2;

  // Internal registers
  reg [1:0] state_q, state_d;
  reg [1:0] rd_state_q, rd_state_d;
  reg [1:0] wr_state_q, wr_state_d;
  reg [3:0] batch_cycle_q, batch_cycle_d;
  reg [3:0] row_batch_q, row_batch_d;
  reg [3:0] col_batch_q, col_batch_d;
  reg [3:0] wr_col_batch_q, wr_col_batch_d;
  reg [9:0] row_lat_shift_reg_q;
  reg [3:0] col_lat_cnt_q, col_lat_cnt_d;
  reg [2:0] we_shift_reg_q; // Shift register cho pipeline

  // Internal signals
  wire rd_en = (rd_state_q == BUSY);
  wire wr_en = (wr_state_q == BUSY);
  wire batch_end = (batch_cycle_q == k_i - 1);
  wire row_batch_end = (row_batch_q == m_i - 1);
  wire col_batch_end = (col_batch_q == n_i - 1);
  wire pe_we_d = rd_state_q == BUSY && batch_cycle_q < k_i; // Sửa: bật pe_we mỗi chu kỳ
  wire pe_clr_d = (batch_cycle_q == 0);

  // Pipeline delay cho wep_o
  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      we_shift_reg_q <= 3'b000;
    end else begin
      we_shift_reg_q <= {we_shift_reg_q[1:0], pe_we_o};
    end
  end

  // Main FSM
  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q <= IDLE;
      rd_state_q <= IDLE;
      wr_state_q <= IDLE;
      batch_cycle_q <= 0;
      row_batch_q <= 0;
      col_batch_q <= 0;
      wr_col_batch_q <= 0;
      row_lat_shift_reg_q <= 0;
      col_lat_cnt_q <= 0;
      valid_o <= 0;
      ena_o <= 0;
      enb_o <= 0;
      enp_o <= 0;
      wep_o <= 0;
      addra_o <= 0;
      addrb_o <= 0;
      addrp_o <= 0;
      wordp_sel_o <= 0;
      ensys_o <= 0;
      pe_we_o <= 0;
      pe_clr_o <= 0;
    end else begin
      state_q <= state_d;
      rd_state_q <= rd_state_d;
      wr_state_q <= wr_state_d;
      batch_cycle_q <= batch_cycle_d;
      row_batch_q <= row_batch_d;
      col_batch_q <= col_batch_d;
      wr_col_batch_q <= wr_col_batch_d;
      row_lat_shift_reg_q <= (rd_state_q == BUSY) ? {row_lat_shift_reg_q[8:0], 1'b1} : row_lat_shift_reg_q;
      col_lat_cnt_q <= col_lat_cnt_d;
      valid_o <= (state_q == DONE);
      ena_o <= rd_en;
      enb_o <= rd_en;
      enp_o <= wr_en;
      wep_o <= we_shift_reg_q[2]; // Trì hoãn 3 chu kỳ
      addra_o <= rd_en ? base_addra_i + (batch_cycle_q << 4) : 'd0;
      addrb_o <= rd_en ? base_addrb_i + (batch_cycle_q << 4) : 'd0;
      addrp_o <= wr_en ? base_addrp_i + (wr_col_batch_q << 4) : 'd0;
      wordp_sel_o <= wr_en ? col_lat_cnt_q - `OUTPUT_LAT - 1 : 'd0;
      ensys_o <= (state_q != IDLE);
      pe_we_o <= pe_we_d;
      pe_clr_o <= pe_clr_d;
    end
  end

  // Main FSM logic
  always @(*) begin
    state_d = state_q;
    case (state_q)
      IDLE: begin
        if (start_i) state_d = BUSY;
      end
      BUSY: begin
        if (rd_state_q == DONE && wr_state_q == DONE) state_d = DONE;
      end
      DONE: state_d = IDLE;
    endcase
  end

  // Read FSM
  always @(*) begin
    rd_state_d = rd_state_q;
    batch_cycle_d = batch_cycle_q;
    row_batch_d = row_batch_q;
    col_batch_d = col_batch_q;
    case (rd_state_q)
      IDLE: begin
        if (start_i) rd_state_d = BUSY;
      end
      BUSY: begin
        if (batch_end && row_batch_end && col_batch_end) begin
          rd_state_d = DONE;
          batch_cycle_d = 0;
        end else if (batch_end) begin
          batch_cycle_d = 0;
          if (row_batch_end) begin
            row_batch_d = 0;
            col_batch_d = col_batch_q + 1;
          end else begin
            row_batch_d = row_batch_q + 1;
          end
        end else begin
          batch_cycle_d = batch_cycle_q + 1;
        end
      end
      DONE: rd_state_d = IDLE;
    endcase
  end

  // Write FSM
  always @(*) begin
    wr_state_d = wr_state_q;
    wr_col_batch_d = wr_col_batch_q;
    col_lat_cnt_d = col_lat_cnt_q;
    case (wr_state_q)
      IDLE: begin
        if (row_lat_shift_reg_q[0]) wr_state_d = BUSY;
      end
      BUSY: begin
        if (col_lat_cnt_q == n_i - 1 && row_lat_shift_reg_q[2 + `OUTPUT_LAT]) begin
          wr_state_d = DONE;
          col_lat_cnt_d = 0;
          wr_col_batch_d = wr_col_batch_q + 1;
        end else begin
          col_lat_cnt_d = col_lat_cnt_q + 1;
        end
      end
      DONE: wr_state_d = IDLE;
    endcase
  end

  // Debug
  always @(posedge clk_i) begin
    $display("Controller Debug: state_q = %0d, rd_state_q = %0d, wr_state_q = %0d, valid_o = %b",
             state_q, rd_state_q, wr_state_q, valid_o);
    $display("Counters: batch_cycle_q = %h, row_batch_q = %h, col_batch_q = %h, wr_col_batch_q = %h",
             batch_cycle_q, row_batch_q, col_batch_q, wr_col_batch_q);
    $display("Pipeline: row_lat_shift_reg_q = %b, col_lat_cnt_q = %h",
             row_lat_shift_reg_q, col_lat_cnt_q);
  end

endmodule
