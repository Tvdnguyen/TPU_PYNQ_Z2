//-----------------------------------------------------------------------------
// Module: TPU
// Author: Nguyen Trinh
// Created: Jan 10, 2025
// Last Updated: March 23, 2025
//-----------------------------------------------------------------------------
`ifndef _TPU_V
`define _TPU_V

`include "def.v"

module tpu (
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

  // Global buffer A interface
  output                   ena_o,
  output                   wea_o,
  output [`ADDR_WIDTH-1:0] addra_o,
  input  [`WORD_WIDTH-1:0] worda_i,

  // Global buffer B interface
  output                   enb_o,
  output                   web_o,
  output [`ADDR_WIDTH-1:0] addrb_o,
  input  [`WORD_WIDTH-1:0] wordb_i,

  // Global buffer P interface
  output                       enp_o,
  output                       wep_o,
  output     [`ADDR_WIDTH-1:0] addrp_o,
  output reg [`WORD_WIDTH-1:0] wordp_o
);

  // Internal controller control signals
  wire       pe_clr, pe_we, ensys, bubble;
  wire [3:0] wordp_sel;

  // Wires connecting each pe array
  wire pe_clr_q1, pe_clr_q2, pe_clr_q3, pe_clr_q4,
       pe_clr_q5, pe_clr_q6, pe_clr_q7, pe_clr_q8, pe_clr_q9;

  wire pe_we_q1, pe_we_q2, pe_we_q3, pe_we_q4,
       pe_we_q5, pe_we_q6, pe_we_q7, pe_we_q8, pe_we_q9;

  wire [`WORD_WIDTH-1:0] srca_word_q1, srca_word_q2, srca_word_q3, srca_word_q4,
                         srca_word_q5, srca_word_q6, srca_word_q7, srca_word_q8, srca_word_q9;

  wire [`WORD_WIDTH-1:0] wordp0, wordp1, wordp2, wordp3,
                         wordp4, wordp5, wordp6, wordp7, wordp8, wordp9;

  // Source operands
  wire [`WORD_WIDTH-1:0] srca_word, srcb_word;

  // Output multiplexer
  always @(*) begin
    if (wep_o) begin
      case (wordp_sel)
        4'd0: wordp_o = wordp0;
        4'd1: wordp_o = wordp1;
        4'd2: wordp_o = wordp2;
        4'd3: wordp_o = wordp3;
        4'd4: wordp_o = wordp4;
        4'd5: wordp_o = wordp5;
        4'd6: wordp_o = wordp6;
        4'd7: wordp_o = wordp7;
        4'd8: wordp_o = wordp8;
        4'd9: wordp_o = wordp9;
        default: wordp_o = 'd0;
      endcase
    end else begin
      wordp_o = 'd0;
    end
  end

  // Debug output
  always @(posedge clk_i) begin
    $display("TPU Debug: ensys = %b, pe_we = %b, pe_clr = %b, wep_o = %b, wordp_sel = %h, valid_o = %b",
             ensys, pe_we, pe_clr, wep_o, wordp_sel, valid_o);
    $display("TPU Data: srca_word = %h, srcb_word = %h, wordp_o = %h",
             srca_word, srcb_word, wordp_o);
    $display("PE Outputs: wordp0 = %h, wordp1 = %h, wordp9 = %h",
             wordp0, wordp1, wordp9);
  end

  // Instantiate controller
  controller controller (
    .clk_i       (clk_i),
    .rst_ni      (rst_ni),

    .start_i     (start_i),
    .valid_o     (valid_o),

    .m_i         (m_i),
    .k_i         (k_i),
    .n_i         (n_i),

    .base_addra_i(base_addra_i),
    .base_addrb_i(base_addrb_i),
    .base_addrp_i(base_addrp_i),

    .pe_clr_o    (pe_clr),
    .pe_we_o     (pe_we),

    .ensys_o     (ensys),
    .bubble_o    (bubble),

    .ena_o       (ena_o),
    .wea_o       (wea_o),
    .addra_o     (addra_o),

    .enb_o       (enb_o),
    .web_o       (web_o),
    .addrb_o     (addrb_o),

    .enp_o       (enp_o),
    .wep_o       (wep_o),
    .addrp_o     (addrp_o),

    .wordp_sel_o (wordp_sel)
  );

  // Systolic input setup for A
  systolic_input_setup srca_setup (
    .clk_i (clk_i),
    .rst_ni(rst_ni),
    .en_i  (ensys),
    .word_i(bubble ? 'd0 : worda_i),
    .skew_o(srca_word)
  );

  // Systolic input setup for B
  systolic_input_setup srcb_setup (
    .clk_i (clk_i),
    .rst_ni(rst_ni),
    .en_i  (ensys),
    .word_i(bubble ? 'd0 : wordb_i),
    .skew_o(srcb_word)
  );

  // PE array columns
  pe_array col0 (
    .clk_i      (clk_i),
    .rst_ni     (rst_ni),
    .clr_i      (pe_clr),
    .clr_o      (pe_clr_q1),
    .we_i       (pe_we),
    .we_o       (pe_we_q1),
    .srca_word_i(srca_word),
    .srca_word_o(srca_word_q1),
    .srcb_i     (srcb_word[`DATA0]),
    .wordp_o    (wordp0)
  );

  pe_array col1 (
    .clk_i      (clk_i),
    .rst_ni     (rst_ni),
    .clr_i      (pe_clr_q1),
    .clr_o      (pe_clr_q2),
    .we_i       (pe_we_q1),
    .we_o       (pe_we_q2),
    .srca_word_i(srca_word_q1),
    .srca_word_o(srca_word_q2),
    .srcb_i     (srcb_word[`DATA1]),
    .wordp_o    (wordp1)
  );

  pe_array col2 (
    .clk_i      (clk_i),
    .rst_ni     (rst_ni),
    .clr_i      (pe_clr_q2),
    .clr_o      (pe_clr_q3),
    .we_i       (pe_we_q2),
    .we_o       (pe_we_q3),
    .srca_word_i(srca_word_q2),
    .srca_word_o(srca_word_q3),
    .srcb_i     (srcb_word[`DATA2]),
    .wordp_o    (wordp2)
  );

  pe_array col3 (
    .clk_i      (clk_i),
    .rst_ni     (rst_ni),
    .clr_i      (pe_clr_q3),
    .clr_o      (pe_clr_q4),
    .we_i       (pe_we_q3),
    .we_o       (pe_we_q4),
    .srca_word_i(srca_word_q3),
    .srca_word_o(srca_word_q4),
    .srcb_i     (srcb_word[`DATA3]),
    .wordp_o    (wordp3)
  );

  pe_array col4 (
    .clk_i      (clk_i),
    .rst_ni     (rst_ni),
    .clr_i      (pe_clr_q4),
    .clr_o      (pe_clr_q5),
    .we_i       (pe_we_q4),
    .we_o       (pe_we_q5),
    .srca_word_i(srca_word_q4),
    .srca_word_o(srca_word_q5),
    .srcb_i     (srcb_word[`DATA4]),
    .wordp_o    (wordp4)
  );

  pe_array col5 (
    .clk_i      (clk_i),
    .rst_ni     (rst_ni),
    .clr_i      (pe_clr_q5),
    .clr_o      (pe_clr_q6),
    .we_i       (pe_we_q5),
    .we_o       (pe_we_q6),
    .srca_word_i(srca_word_q5),
    .srca_word_o(srca_word_q6),
    .srcb_i     (srcb_word[`DATA5]),
    .wordp_o    (wordp5)
  );

  pe_array col6 (
    .clk_i      (clk_i),
    .rst_ni     (rst_ni),
    .clr_i      (pe_clr_q6),
    .clr_o      (pe_clr_q7),
    .we_i       (pe_we_q6),
    .we_o       (pe_we_q7),
    .srca_word_i(srca_word_q6),
    .srca_word_o(srca_word_q7),
    .srcb_i     (srcb_word[`DATA6]),
    .wordp_o    (wordp6)
  );

  pe_array col7 (
    .clk_i      (clk_i),
    .rst_ni     (rst_ni),
    .clr_i      (pe_clr_q7),
    .clr_o      (pe_clr_q8),
    .we_i       (pe_we_q7),
    .we_o       (pe_we_q8),
    .srca_word_i(srca_word_q7),
    .srca_word_o(srca_word_q8),
    .srcb_i     (srcb_word[`DATA7]),
    .wordp_o    (wordp7)
  );

  pe_array col8 (
    .clk_i      (clk_i),
    .rst_ni     (rst_ni),
    .clr_i      (pe_clr_q8),
    .clr_o      (pe_clr_q9),
    .we_i       (pe_we_q8),
    .we_o       (pe_we_q9),
    .srca_word_i(srca_word_q8),
    .srca_word_o(srca_word_q9),
    .srcb_i     (srcb_word[`DATA8]),
    .wordp_o    (wordp8)
  );

  pe_array col9 (
    .clk_i      (clk_i),
    .rst_ni     (rst_ni),
    .clr_i      (pe_clr_q9),
    .clr_o      (),
    .we_i       (pe_we_q9),
    .we_o       (),
    .srca_word_i(srca_word_q9),
    .srca_word_o(),
    .srcb_i     (srcb_word[`DATA9]),
    .wordp_o    (wordp9)
  );

endmodule

`endif
