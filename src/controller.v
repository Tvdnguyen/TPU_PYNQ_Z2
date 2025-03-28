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

`define IDLE 2'b00
`define BUSY 2'b01
`define DONE 2'b10

module controller (
  input  clk_i,
  input  rst_ni,

  input  start_i,
  output valid_o,

  // Matrix dimensions
  input  [`ADDR_WIDTH-1:0] m_i,
  input  [`ADDR_WIDTH-1:0] k_i,
  input  [`ADDR_WIDTH-1:0] n_i,

  // Base addresses
  input  [`ADDR_WIDTH-1:0] base_addra_i,
  input  [`ADDR_WIDTH-1:0] base_addrb_i,
  input  [`ADDR_WIDTH-1:0] base_addrp_i,

  // PE control signals
  output pe_clr_o,
  output pe_we_o,

  // Systolic input setup interface
  output ensys_o,
  output bubble_o,

  // Global buffer A interface
  output                   ena_o,
  output                   wea_o,
  output [`ADDR_WIDTH-1:0] addra_o,

  // Global buffer B interface
  output                   enb_o,
  output                   web_o,
  output [`ADDR_WIDTH-1:0] addrb_o,

  // Global buffer P interface
  output                   enp_o,
  output                   wep_o,
  output [`ADDR_WIDTH-1:0] addrp_o,

  output [2:0]             wordp_sel_o
);

  // Main state
  reg [1:0] state_q, state_d;

  // Boundaries for batches (constant)
  wire [`ADDR_WIDTH-1:0] n_row_batches = (m_i + 9) / 10;  // 10/10 = 1
  wire [`ADDR_WIDTH-1:0] n_col_batches = (n_i + 9) / 10;  // 10/10 = 1
  wire [`ADDR_WIDTH-1:0] n_batch_cycles = k_i < 'h00A ? 'h00A : k_i;  // >= 10

  // Counters for batches
  reg [`ADDR_WIDTH-1:0] row_batch_q, row_batch_d;
  reg [`ADDR_WIDTH-1:0] col_batch_q, col_batch_d;
  reg [`ADDR_WIDTH-1:0] batch_cycle_q, batch_cycle_d;
  reg [`ADDR_WIDTH-1:0] wr_col_batch_q, wr_col_batch_d;

  // Global buffer read/write enable
  wire rd_en = rd_state_q == `BUSY && !bubble_d;
  wire wr_en = wr_state_q == `BUSY;

  // Base source addresses
  wire [`ADDR_WIDTH-1:0] batch_base_addra = ((row_batch_q * k_i) << 4) + base_addra_i;
  wire [`ADDR_WIDTH-1:0] batch_base_addrb = ((col_batch_q * k_i) << 4) + base_addrb_i;

  // Source address generator
  reg  [1:0] rd_state_q, rd_state_d;

  // Target address generator
  reg  [1:0] wr_state_q, wr_state_d;
  reg  [2:0] col_lat_cnt_q, col_lat_cnt_d;

  reg  [8+`OUTPUT_LAT-1:0] row_lat_shift_reg_q;
  reg  [`ADDR_WIDTH-1:0]   addrp_q, addrp_d;

  wire wr_start = row_lat_shift_reg_q[7+`OUTPUT_LAT];

  // Boundary conditions
  wire row_batch_end    = row_batch_q == n_row_batches - 'd1;
  wire col_batch_end    = col_batch_q == n_col_batches - 'd1;
  wire batch_end        = batch_cycle_q == n_batch_cycles - 'd1;
  wire wr_col_batch_end = wr_col_batch_q == n_col_batches - 'd1;

  // Write boundary condition
  wire [3:0] rem_n   = n_i[3:0] & 4'b1111;  // n % 10
  wire [3:0] batch_n = wr_col_batch_end ? rem_n - 4'd1 : 4'd9; 

  // PE & systolic input setup control signals
  reg  pe_clr_q, pe_we_q, ensys_q, bubble_q;
  wire pe_clr_d = ~|batch_cycle_q;               // == 0
  wire pe_we_d  = rd_state_q == `BUSY && batch_cycle_q < k_i;  // Sửa: bật pe_we mỗi chu kỳ trong batch
  wire ensys_d  = state_q == `BUSY;
  wire bubble_d = batch_cycle_q > (k_i - 1);     // Insert bubbles khi > k

  // Pipeline delay cho wep_o
  reg [2:0] we_shift_reg_q;
  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      we_shift_reg_q <= 3'b000;
    end else begin
      we_shift_reg_q <= {we_shift_reg_q[1:0], pe_we_q};
    end
  end

  // Assign output signals
  assign valid_o  = state_q == `DONE;
  assign pe_we_o  = pe_we_q;
  assign pe_clr_o = pe_clr_q;
  assign ensys_o  = ensys_q;
  assign bubble_o = bubble_q;

  // Global buffer interfaces
  assign ena_o   = rd_en;    // Enable khi read enable
  assign wea_o   = 1'b0;     // Luôn đọc
  assign addra_o = rd_en ? batch_base_addra + (batch_cycle_q << 4) : 'd0;

  assign enb_o   = rd_en;    // Enable khi read enable
  assign web_o   = 1'b0;     // Luôn đọc
  assign addrb_o = rd_en ? batch_base_addrb + (batch_cycle_q << 4) : 'd0;

  assign enp_o   = wr_en;    // Enable khi write enable
  assign wep_o   = we_shift_reg_q[2];  // Sửa: Trì hoãn wep_o để đồng bộ với OUTPUT_LAT
  assign addrp_o = wr_en ? base_addrp_i + addrp_q << 4 : 'd0;

  // Word P select signal
  assign wordp_sel_o = wr_en ? col_lat_cnt_q - `OUTPUT_LAT : 'o0;  // Sửa: Điều chỉnh cho pipeline

  // PE & systolic input setup control signals
  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      pe_clr_q <= 1'b0;
      pe_we_q  <= 1'b0;
      ensys_q  <= 1'b0;
      bubble_q <= 1'b0;
    end else begin
      if (state_q == `BUSY) begin
        pe_clr_q <= pe_clr_d;
        pe_we_q  <= pe_we_d;
        ensys_q  <= ensys_d;
        bubble_q <= bubble_d;
      end else begin
        pe_clr_q <= 'd0;
        pe_we_q  <= 'd0;
        ensys_q  <= 'd0;
        bubble_q <= 'd0;
      end
    end
  end

  // Batch counters
  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      batch_cycle_q <= 'd0;
      row_batch_q   <= 'd0;
      col_batch_q   <= 'd0;
    end else begin
      batch_cycle_q <= batch_cycle_d;
      row_batch_q   <= row_batch_d;
      col_batch_q   <= col_batch_d;
    end
  end

  // Row batch counter (slowest)
  always @(*) begin
    if (rd_state_q == `IDLE) begin
      row_batch_d = 'd0;
    end else if (rd_state_q == `BUSY) begin
      if (row_batch_end && col_batch_end && batch_end) begin
        row_batch_d = 'd0;                // Reset khi tất cả kết thúc
      end else if (col_batch_end && batch_end) begin
        row_batch_d = row_batch_q + 'd1;  // Tăng khi col batch kết thúc
      end else begin
        row_batch_d = row_batch_q;        // Giữ nguyên
      end
    end else begin
      row_batch_d = row_batch_q;
    end
  end

  // Column batch counter (medium)
  always @(*) begin
    if (rd_state_q == `IDLE) begin
      col_batch_d = 'd0;
    end else if (rd_state_q == `BUSY) begin
      if (col_batch_end && batch_end) begin
        col_batch_d = 'd0;                // Reset khi column batch kết thúc
      end else if (batch_end) begin
        col_batch_d = col_batch_q + 'd1;  // Tăng khi batch kết thúc
      end else begin
        col_batch_d = col_batch_q;        // Giữ nguyên
      end
    end else begin
      col_batch_d = col_batch_q;
    end
  end

  // Batch cycle counter (fastest)
  always @(*) begin
    if (rd_state_q == `BUSY) begin            // Khi read enable
      if (batch_end) begin
        batch_cycle_d = 'd0;                  // Reset khi kết thúc
      end else begin
        batch_cycle_d = batch_cycle_q + 'd1;  // Tăng mỗi chu kỳ
      end
    end else begin
      batch_cycle_d = 'd0;
    end
  end

  // Source address generator state machine behavior
  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      rd_state_q <= `IDLE;
    end else begin
      rd_state_q <= rd_state_d;
    end
  end

  always @(*) begin
    case (rd_state_q)
      `IDLE:
        rd_state_d = state_q == `BUSY ? `BUSY : `IDLE;
      `BUSY:
        rd_state_d =
          row_batch_end && col_batch_end && batch_end ? `DONE : `BUSY;
      `DONE:
        rd_state_d = state_q == `DONE ? `IDLE : `DONE;
      default: begin
        rd_state_d = `IDLE;
      end
    endcase
  end

  // Row latency shift register
  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      row_lat_shift_reg_q <= 'd0;
    end else if (rd_state_q == `BUSY) begin
      row_lat_shift_reg_q <= {row_lat_shift_reg_q[8+`OUTPUT_LAT-2:0], 1'b1};  // Sửa: Dịch khi đọc
    end else begin
      row_lat_shift_reg_q <= row_lat_shift_reg_q;
    end
  end

  // Target address generation
  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      wr_col_batch_q <= 'd0;
    end else begin
      wr_col_batch_q <= wr_col_batch_d;
    end
  end

  always @(*) begin
    if (state_q == `BUSY) begin
      if (wr_state_q == `BUSY && col_lat_cnt_q == batch_n) begin
        if (wr_col_batch_q == n_col_batches - 1) begin
          wr_col_batch_d = 'd0;
        end else begin
          wr_col_batch_d = wr_col_batch_q + 'd1;
        end
      end else begin
        wr_col_batch_d = wr_col_batch_q;
      end
    end else begin
      wr_col_batch_d = 'd0;
    end
  end

  // Target address generator state machine behavior
  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      wr_state_q <= `IDLE;
    end else begin
      wr_state_q <= wr_state_d;
    end
  end

  always @(*) begin
    if (state_q == `BUSY) begin
      case (wr_state_q)
        `IDLE: begin
          wr_state_d = wr_start ? `BUSY : `IDLE;
        end
        `BUSY: begin
          if (col_lat_cnt_q == batch_n && row_lat_shift_reg_q[7+`OUTPUT_LAT]) begin  // Sửa: Điều kiện thoát
            if (rd_state_q == `DONE && ~|row_lat_shift_reg_q) begin
              wr_state_d = `DONE;
            end else begin
              wr_state_d = `IDLE;
            end
          end else begin
            wr_state_d = `BUSY;
          end
        end
        `DONE: begin
          wr_state_d = state_q == `DONE ? `IDLE : `DONE;
        end
        default: begin
          wr_state_d = `IDLE;
        end
      endcase
    end else begin
      wr_state_d = `IDLE;
    end
  end

  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      col_lat_cnt_q <= 'd0;
    end else begin
      col_lat_cnt_q <= col_lat_cnt_d;
    end
  end

  always @(*) begin
    if (state_q == `BUSY) begin
      case (wr_state_q)
        `IDLE: begin
          col_lat_cnt_d = 'd0;
        end
        `BUSY: begin
          if (row_lat_shift_reg_q[7+`OUTPUT_LAT]) begin
            col_lat_cnt_d = 'd0;
          end else if (col_lat_cnt_q == batch_n) begin
            col_lat_cnt_d = 'd0;
          end else begin
            col_lat_cnt_d = col_lat_cnt_q + 'd1;
          end
        end
        `DONE: begin
          col_lat_cnt_d = 'd0;
        end
        default: begin
          col_lat_cnt_d = 'd0;
        end
      endcase
    end else begin
      col_lat_cnt_d = 'd0;
    end
  end

  // Target address generation
  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      addrp_q <= 'd0;
    end else begin
      addrp_q <= addrp_d;
    end
  end

  always @(*) begin
    if (state_q == `IDLE) begin
      addrp_d = 'd0;
    end else if (wr_en) begin
      addrp_d = addrp_q + 'd1;
    end else begin
      addrp_d = addrp_q;  // Giữ nguyên
    end
  end

  // Main state machine behavior
  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q <= `IDLE;
    end else begin
      state_q <= state_d;
    end
  end

  always @(*) begin
    case (state_q)
      `IDLE: begin
        state_d = start_i ? `BUSY : `IDLE;
      end
      `BUSY: begin
        // Cho đến khi đọc và ghi hoàn tất
        if (rd_state_q == `DONE && wr_state_q == `DONE) begin
          state_d = `DONE;
        end else begin
          state_d = `BUSY;
        end
      end
      `DONE: begin
        // Chờ start_i được kéo xuống
        state_d = !start_i ? `IDLE : `DONE;
      end
      default: begin
        state_d = `IDLE;
      end
    endcase
  end

  // Debug FSM và tiling
  always @(posedge clk_i) begin
    $display("state_q = %0d, valid_o = %b, rd_state_q = %0d, wr_state_q = %0d, n_row_batches = %h, n_col_batches = %h",
             state_q, valid_o, rd_state_q, wr_state_q, n_row_batches, n_col_batches);
    $display("Counters: batch_cycle_q = %h, row_batch_q = %h, col_batch_q = %h, wr_col_batch_q = %h",
             batch_cycle_q, row_batch_q, col_batch_q, wr_col_batch_q);
    $display("Pipeline: row_lat_shift_reg_q = %b, col_lat_cnt_q = %h, we_shift_reg_q = %b",
             row_lat_shift_reg_q, col_lat_cnt_q, we_shift_reg_q);
  end

endmodule

`endif
