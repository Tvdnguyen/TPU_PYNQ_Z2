//-----------------------------------------------------------------------------
// Module: systolic_input_setup
// Author: Nguyen Trinh
// Created: Jan 10, 2025
// Last Updated: March 23, 2025
// 
// Using shift registers to skew the word so that the timing is correct for
// further computation.
//
//  buf_q
//  |  buf_q2
//  |  |  buf_q3
//  |  |  |  buf_q4
//  |  |  |  |  buf_q5
//  |  |  |  |  |  buf_q6
//  |  |  |  |  |  |  buf_q7
//  |  |  |  |  |  |  |  buf_q8
//  |  |  |  |  |  |  |  |  buf_q9
`ifndef _SYSTOLIC_INPUT_SETUP_V
`define _SYSTOLIC_INPUT_SETUP_V

`include "def.v"

module systolic_input_setup (
  input  clk_i,
  input  rst_ni,
  input  en_i,  // Enable

  input  [`WORD_WIDTH-1:0] word_i,
  output [`WORD_WIDTH-1:0] skew_o
);

  reg [`DATA_WIDTH*9-1:0] buf_q1;  // 1-cycle delay
  reg [`DATA_WIDTH*8-1:0] buf_q2;
  reg [`DATA_WIDTH*7-1:0] buf_q3;
  reg [`DATA_WIDTH*6-1:0] buf_q4;
  reg [`DATA_WIDTH*5-1:0] buf_q5;
  reg [`DATA_WIDTH*4-1:0] buf_q6;
  reg [`DATA_WIDTH*3-1:0] buf_q7;
  reg [`DATA_WIDTH*2-1:0] buf_q8;
  reg [`DATA_WIDTH-1:0]   buf_q9;  // 9-cycle delay

  assign skew_o = {
    buf_q9[`DATA0], buf_q8[`DATA0], buf_q7[`DATA0], buf_q6[`DATA0],
    buf_q5[`DATA0], buf_q4[`DATA0], buf_q3[`DATA0], buf_q2[`DATA0],
    buf_q1[`DATA0], word_i[`DATA0]
  };

  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      buf_q1 <= 'd0;
      buf_q2 <= 'd0;
      buf_q3 <= 'd0;
      buf_q4 <= 'd0;
      buf_q5 <= 'd0;
      buf_q6 <= 'd0;
      buf_q7 <= 'd0;
      buf_q8 <= 'd0;
      buf_q9 <= 'd0;
    end else begin
      if (en_i) begin
        buf_q1 <= word_i[`WORD_WIDTH-1:`DATA_WIDTH];
        buf_q2 <= buf_q1[`DATA_WIDTH*9-1:`DATA_WIDTH];
        buf_q3 <= buf_q2[`DATA_WIDTH*8-1:`DATA_WIDTH];
        buf_q4 <= buf_q3[`DATA_WIDTH*7-1:`DATA_WIDTH];
        buf_q5 <= buf_q4[`DATA_WIDTH*6-1:`DATA_WIDTH];
        buf_q6 <= buf_q5[`DATA_WIDTH*5-1:`DATA_WIDTH];
        buf_q7 <= buf_q6[`DATA_WIDTH*4-1:`DATA_WIDTH];
        buf_q8 <= buf_q7[`DATA_WIDTH*3-1:`DATA_WIDTH];
        buf_q9 <= buf_q8[`DATA_WIDTH*2-1:`DATA_WIDTH];
      end
    end
  end

  // Debug
  always @(posedge clk_i) begin
    $display("Systolic Input Debug: en_i = %b, word_i = %h, skew_o = %h",
             en_i, word_i, skew_o);
    $display("Shift Regs: buf_q1 = %h, buf_q9 = %h", buf_q1, buf_q9);
  end

endmodule

`endif
