//-----------------------------------------------------------------------------
// Module: DSP_Group
// Author: Nguyen Trinh
// Created: jan 10, 2025
// Last Updated: March 23, 2025
`timescale 1ns / 1ps
`include "def.v"

module tb_tpu;

  // Inputs
  reg clk_i;
  reg rst_ni;
  reg start_i;
  reg [`ADDR_WIDTH-1:0] m_i, k_i, n_i;
  reg [`ADDR_WIDTH-1:0] base_addra_i, base_addrb_i, base_addrp_i;
  reg [`WORD_WIDTH-1:0] worda_i, wordb_i;

  // Outputs
  wire valid_o;
  wire ena_o, wea_o;
  wire [`ADDR_WIDTH-1:0] addra_o;
  wire enb_o, web_o;
  wire [`ADDR_WIDTH-1:0] addrb_o;
  wire enp_o, wep_o;
  wire [`ADDR_WIDTH-1:0] addrp_o;
  wire [`WORD_WIDTH-1:0] wordp_o;

  // Instantiate the Unit Under Test (UUT)
  tpu uut (
    .clk_i(clk_i), .rst_ni(rst_ni), .start_i(start_i), .valid_o(valid_o),
    .m_i(m_i), .k_i(k_i), .n_i(n_i),
    .base_addra_i(base_addra_i), .base_addrb_i(base_addrb_i), .base_addrp_i(base_addrp_i),
    .ena_o(ena_o), .wea_o(wea_o), .addra_o(addra_o), .worda_i(worda_i),
    .enb_o(enb_o), .web_o(web_o), .addrb_o(addrb_o), .wordb_i(wordb_i),
    .enp_o(enp_o), .wep_o(wep_o), .addrp_o(addrp_o), .wordp_o(wordp_o)
  );

  // Clock generation
  initial begin
    clk_i = 0;
    forever #5 clk_i = ~clk_i;  // 10ns period (100 MHz)
  end

  // Simulated global buffers
  reg [`WORD_WIDTH-1:0] buffer_a [0:4095];
  reg [`WORD_WIDTH-1:0] buffer_b [0:4095];
  reg [`WORD_WIDTH-1:0] buffer_p [0:4095];
  reg [`WORD_WIDTH-1:0] expected_p [0:4095];
  integer i, j, cycle_count;

  // Test procedure
  initial begin
    // Timeout sau 1000ns (100 chu kỳ, đủ cho 10x10)
    #1000;
    $display("Simulation timeout after 1000ns!");
    $finish;

    // Initialize signals
    rst_ni = 0;
    start_i = 0;
    m_i = 0;
    k_i = 0;
    n_i = 0;
    base_addra_i = 0;
    base_addrb_i = 0;
    base_addrp_i = 0;
    worda_i = 0;
    wordb_i = 0;
    cycle_count = 0;

    // Reset
    #20 rst_ni = 1;

    // Test 1: Matrix Multiplication 10x10 x 10x10
    $display("Test 1: Matrix Multiplication 10x10 x 10x10");
    m_i = 10;
    k_i = 10;
    n_i = 10;
    base_addra_i = 12'h000;
    base_addrb_i = 12'h100;
    base_addrp_i = 12'h200;

    // Fill buffer_a: A[i][j] = (i+1)*(j+1)
    for (i = 0; i < 10; i = i + 1) begin
      for (j = 0; j < 10; j = j + 1) begin
        buffer_a[i][j*16 +: 16] = (i + 1) * (j + 1);
      end
    end

    // Fill buffer_b: Identity matrix scaled by 2
    for (i = 0; i < 10; i = i + 1) begin
      for (j = 0; j < 10; j = j + 1) begin
        buffer_b[i][j*16 +: 16] = (i == j) ? 2 : 0;
      end
    end

    // Calculate expected output: C = A * 2
    for (i = 0; i < 10; i = i + 1) begin
      for (j = 0; j < 10; j = j + 1) begin
        expected_p[i][j*16 +: 16] = buffer_a[i][j*16 +: 16] * 2;
      end
    end

    // Start the TPU
    #10 start_i = 1;
    #10 start_i = 0;

    // Simulate global buffer read/write
    while (!valid_o) begin
      @(posedge clk_i);
      cycle_count = cycle_count + 1;

      if (ena_o && !wea_o) begin
        worda_i = buffer_a[addra_o];
        $display("Cycle %0d: Reading A from addr %h: %h", cycle_count, addra_o, worda_i);
      end else begin
        worda_i = 0;
        $display("Cycle %0d: No read A, ena_o = %b", cycle_count, ena_o);
      end

      if (enb_o && !web_o) begin
        wordb_i = buffer_b[addrb_o];
        $display("Cycle %0d: Reading B from addr %h: %h", cycle_count, addrb_o, wordb_i);
      end else begin
        wordb_i = 0;
        $display("Cycle %0d: No read B, enb_o = %b", cycle_count, enb_o);
      end

      if (enp_o && wep_o) begin
        buffer_p[addrp_o] = wordp_o;
        $display("Cycle %0d: Writing P to addr %h: %h", cycle_count, addrp_o, wordp_o);
      end
    end

    // Check results
    #20;
    $display("Test 1 Results:");
    for (i = 0; i < 10; i = i + 1) begin
      if (buffer_p[base_addrp_i + i] === expected_p[i])
        $display("Row %0d: PASS - Expected: %h, Got: %h", i, expected_p[i], buffer_p[base_addrp_i + i]);
      else
        $display("Row %0d: FAIL - Expected: %h, Got: %h", i, expected_p[i], buffer_p[base_addrp_i + i]);
    end

    #50 $finish;
  end

endmodule
