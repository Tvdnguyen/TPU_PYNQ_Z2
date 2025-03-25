//-----------------------------------------------------------------------------
// Module: pe_array.v
// Author: Nguyen Trinh
// Created: Jan 10, 2025
// Last Updated: March 23, 2025
// 
// 10 PEs in vertical are grouped into a PE array. The PE array receives the 
// clear signal from controller and then stores the psum output from PEs.
// All the psum output from PEs are assembled into an output word of 128 bits,
// which is to write to the output global buffer.
//
`ifndef _PE_ARRAY_V
`define _PE_ARRAY_V

`include "def.v"

module pe_array (
  input  clk_i,
  input  rst_ni,

  // Control signals from controller
  input  clr_i,
  output clr_o,
  input  we_i,
  output we_o,

  // A (word)
  input  [`WORD_WIDTH-1:0] srca_word_i,
  output [`WORD_WIDTH-1:0] srca_word_o,

  // B (data)
  input  [`DATA_WIDTH-1:0] srcb_i,

  // Output word
  output [`WORD_WIDTH-1:0] wordp_o
);

  // Wires connecting each PE
  wire clr_q1, clr_q2, clr_q3, clr_q4, clr_q5, clr_q6, clr_q7, clr_q8, clr_q9;

  wire [`DATA_WIDTH-1:0] srcb_q1, srcb_q2, srcb_q3, srcb_q4,
                         srcb_q5, srcb_q6, srcb_q7, srcb_q8, srcb_q9;

  // Output word register
  reg  [`WORD_WIDTH-1:0] wordp_q;
  wire [`WORD_WIDTH-1:0] wordp_d;

  // Assign output signals
  assign clr_o   = clr_q1;    // 1 cycle delay
  assign we_o    = we_i;      // Truyền trực tiếp we_i
  assign wordp_o = wordp_q;   // Kết quả tích lũy

  // Output word control
  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      wordp_q <= 'd0;
    end else begin
      if (clr_i) begin
        wordp_q <= 'd0;       // Xóa khi clr_i bật
      end else if (we_i) begin
        wordp_q <= wordp_d;   // Cập nhật kết quả từ PE khi we_i bật
      end
    end
  end

  // Debug
  always @(posedge clk_i) begin
    $display("PE Array Debug: clr_i = %b, we_i = %b, wordp_q = %h, wordp_d = %h",
             clr_i, we_i, wordp_q, wordp_d);
  end

  // PE instances
  pe pe0 (
    .clk_i  (clk_i),
    .rst_ni (rst_ni),
    .clr_i  (clr_i),
    .clr_o  (clr_q1),
    .srca_i (srca_word_i[`DATA0]),
    .srca_o (srca_word_o[`DATA0]),
    .srcb_i (srcb_i),
    .srcb_o (srcb_q1),
    .psum_o (wordp_d[`DATA0])
  );

  pe pe1 (
    .clk_i  (clk_i),
    .rst_ni (rst_ni),
    .clr_i  (clr_q1),
    .clr_o  (clr_q2),
    .srca_i (srca_word_i[`DATA1]),
    .srca_o (srca_word_o[`DATA1]),
    .srcb_i (srcb_q1),
    .srcb_o (srcb_q2),
    .psum_o (wordp_d[`DATA1])
  );

  pe pe2 (
    .clk_i  (clk_i),
    .rst_ni (rst_ni),
    .clr_i  (clr_q2),
    .clr_o  (clr_q3),
    .srca_i (srca_word_i[`DATA2]),
    .srca_o (srca_word_o[`DATA2]),
    .srcb_i (srcb_q2),
    .srcb_o (srcb_q3),
    .psum_o (wordp_d[`DATA2])
  );

  pe pe3 (
    .clk_i  (clk_i),
    .rst_ni (rst_ni),
    .clr_i  (clr_q3),
    .clr_o  (clr_q4),
    .srca_i (srca_word_i[`DATA3]),
    .srca_o (srca_word_o[`DATA3]),
    .srcb_i (srcb_q3),
    .srcb_o (srcb_q4),
    .psum_o (wordp_d[`DATA3])
  );

  pe pe4 (
    .clk_i  (clk_i),
    .rst_ni (rst_ni),
    .clr_i  (clr_q4),
    .clr_o  (clr_q5),
    .srca_i (srca_word_i[`DATA4]),
    .srca_o (srca_word_o[`DATA4]),
    .srcb_i (srcb_q4),
    .srcb_o (srcb_q5),
    .psum_o (wordp_d[`DATA4])
  );

  pe pe5 (
    .clk_i  (clk_i),
    .rst_ni (rst_ni),
    .clr_i  (clr_q5),
    .clr_o  (clr_q6),
    .srca_i (srca_word_i[`DATA5]),
    .srca_o (srca_word_o[`DATA5]),
    .srcb_i (srcb_q5),
    .srcb_o (srcb_q6),
    .psum_o (wordp_d[`DATA5])
  );

  pe pe6 (
    .clk_i  (clk_i),
    .rst_ni (rst_ni),
    .clr_i  (clr_q6),
    .clr_o  (clr_q7),
    .srca_i (srca_word_i[`DATA6]),
    .srca_o (srca_word_o[`DATA6]),
    .srcb_i (srcb_q6),
    .srcb_o (srcb_q7),
    .psum_o (wordp_d[`DATA6])
  );

  pe pe7 (
    .clk_i  (clk_i),
    .rst_ni (rst_ni),
    .clr_i  (clr_q7),
    .clr_o  (clr_q8),
    .srca_i (srca_word_i[`DATA7]),
    .srca_o (srca_word_o[`DATA7]),
    .srcb_i (srcb_q7),
    .srcb_o (srcb_q8),
    .psum_o (wordp_d[`DATA7])
  );

  pe pe8 (
    .clk_i  (clk_i),
    .rst_ni (rst_ni),
    .clr_i  (clr_q8),
    .clr_o  (clr_q9),
    .srca_i (srca_word_i[`DATA8]),
    .srca_o (srca_word_o[`DATA8]),
    .srcb_i (srcb_q8),
    .srcb_o (srcb_q9),
    .psum_o (wordp_d[`DATA8])
  );

  pe pe9 (
    .clk_i  (clk_i),
    .rst_ni (rst_ni),
    .clr_i  (clr_q9),
    .clr_o  (),
    .srca_i (srca_word_i[`DATA9]),
    .srca_o (srca_word_o[`DATA9]),
    .srcb_i (srcb_q9),
    .srcb_o (),
    .psum_o (wordp_d[`DATA9])
  );

endmodule

`endif
