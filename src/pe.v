//-----------------------------------------------------------------------------
// Module: pe
// Author: Nguyen Trinh
// Created: Jan 10, 2025
// Last Updated: March 23, 2025
// pe.v
//
// The process element doing mac operations and propagating the input a and b to
// its adjacent PEs. The mac operation assumes 16 fixed-point data input with
// 8 fraction bits. The computation is done in 16-32-16 manner to ensure better
// precision. The propagation delay from src to psum is 2 cc's.
//
`ifndef _PE_V
`define _PE_V

`include "def.v"

module pe (
  input  clk_i,
  input  rst_ni,
  input  clr_i,  // Clear signal for accumulated value
  output clr_o,  // Propagation of the clear signal
  input  we_i,   // Write enable for accumulation (thêm)
  output we_o,   // Propagation of the write enable (thêm)

  input  signed [`DATA_WIDTH-1:0] srca_i,
  input  signed [`DATA_WIDTH-1:0] srcb_i,

  output signed [`DATA_WIDTH-1:0] srca_o,
  output signed [`DATA_WIDTH-1:0] srcb_o,
  output signed [`DATA_WIDTH-1:0] psum_o
);

  // Pipeline registers
  reg                     clr_q;
  reg                     we_q;    // Thêm thanh ghi cho we_i
  reg [`DATA_WIDTH-1:0]   srca_q, srcb_q;
  reg [`DATA_WIDTH*2-1:0] ab_q;
  reg [`DATA_WIDTH*2-1:0] psum_q;

  // Input of pipeline registers
  wire                     clr_d  = clr_i;
  wire                     we_d   = we_i;   // Thêm
  wire [`DATA_WIDTH-1:0]   srca_d = srca_i;
  wire [`DATA_WIDTH-1:0]   srcb_d = srcb_i;
  wire [`DATA_WIDTH*2-1:0] ab_d   = srca_i * srcb_i;
  wire [`DATA_WIDTH*2-1:0] psum_d = ab_q + (clr_q ? 'd0 : psum_q);

  // Assign output signals
  assign clr_o  = clr_q;
  assign we_o   = we_q;    // Thêm
  assign srca_o = srca_q;
  assign srcb_o = srcb_q;
  assign psum_o = psum_q[8+`DATA_WIDTH-1:8];  // Fraction bits are psum_q[15:0]

  // Pipeline propagation of srca and srcb
  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      srca_q <= 'd0;
      srcb_q <= 'd0;
    end else begin
      srca_q <= srca_d;
      srcb_q <= srcb_d;
    end
  end

  // Pipeline propagation of clear and write enable signals
  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      clr_q <= 1'b0;
      we_q  <= 1'b0;    // Thêm
    end else begin
      clr_q <= clr_d;
      we_q  <= we_d;    // Thêm
    end
  end

  // Pipeline propagation of ab and psum
  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      ab_q   <= 'd0;
      psum_q <= 'd0;
    end else if (clr_q) begin
      ab_q   <= 'd0;
      psum_q <= 'd0;
    end else if (we_q) begin  // Thêm điều kiện we_q để điều khiển tích lũy
      ab_q   <= ab_d;
      psum_q <= psum_d;
    end
  end

  // Debug
  always @(posedge clk_i) begin
    $display("PE Debug: clr_i = %b, we_i = %b, srca_i = %h, srcb_i = %h, ab_q = %h, psum_q = %h, psum_o = %h",
             clr_i, we_i, srca_i, srcb_i, ab_q, psum_q, psum_o);
  end

endmodule

`endif
