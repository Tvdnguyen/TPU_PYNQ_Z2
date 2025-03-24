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
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .start_i(start_i),
    .valid_o(valid_o),
    .m_i(m_i),
    .k_i(k_i),
    .n_i(n_i),
    .base_addra_i(base_addra_i),
    .base_addrb_i(base_addrb_i),
    .base_addrp_i(base_addrp_i),
    .ena_o(ena_o),
    .wea_o(wea_o),
    .addra_o(addra_o),
    .worda_i(worda_i),
    .enb_o(enb_o),
    .web_o(web_o),
    .addrb_o(addrb_o),
    .wordb_i(wordb_i),
    .enp_o(enp_o),
    .wep_o(wep_o),
    .addrp_o(addrp_o),
    .wordp_o(wordp_o)
  );

  // Clock generation
  initial begin
    clk_i = 0;
    forever #5 clk_i = ~clk_i;  // 100 MHz clock (10ns period)
  end

  // Simulated global buffers (A, B, P)
  reg [`WORD_WIDTH-1:0] buffer_a [0:4095];
  reg [`WORD_WIDTH-1:0] buffer_b [0:4095];
  reg [`WORD_WIDTH-1:0] buffer_p [0:4095];
  reg [`WORD_WIDTH-1:0] expected_p [0:4095];

  // Variables for monitoring
  integer i, j, k, cycle_count;

  // Test procedure
  initial begin
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

    // --- Test 1: Matrix Multiplication 10x10 x 10x10 ---
    $display("Test 1: Matrix Multiplication 10x10 x 10x10");

    // Initialize matrices A (10x10) and B (10x10)
    m_i = 10;  // Rows of A
    k_i = 10;  // Columns of A = Rows of B
    n_i = 10;  // Columns of B
    base_addra_i = 12'h000;
    base_addrb_i = 12'h100;
    base_addrp_i = 12'h200;

    // Fill buffer_a with A = [[1, 2, ..., 10], [2, 4, ..., 20], ..., [10, 20, ..., 100]]
    // Each word contains 10 elements (160-bit = 10 x 16-bit)
    for (i = 0; i < 10; i = i + 1) begin
      for (j = 0; j < 10; j = j + 1) begin
        buffer_a[i][j*16 +: 16] = (i + 1) * (j + 1);  // A[i][j] = (i+1)*(j+1)
      end
    end

    // Fill buffer_b with B = Identity matrix (scaled by 2)
    // B = [[2, 0, ..., 0], [0, 2, ..., 0], ..., [0, 0, ..., 2]]
    for (i = 0; i < 10; i = i + 1) begin
      for (j = 0; j < 10; j = j + 1) begin
        buffer_b[i][j*16 +: 16] = (i == j) ? 2 : 0;
      end
    end

    // Calculate expected output C = A * B
    // Expected C = [[2, 4, ..., 20], [4, 8, ..., 40], ..., [20, 40, ..., 200]]
    for (i = 0; i < 10; i = i + 1) begin
      for (j = 0; j < 10; j = j + 1) begin
        expected_p[i][j*16 +: 16] = buffer_a[i][j*16 +: 16] * 2;  // A[i][j] * 2
      end
    end

    // Start the TPU
    #10 start_i = 1;
    #10 start_i = 0;

    // Simulate global buffer read
    while (!valid_o) begin
      @(posedge clk_i);
      cycle_count = cycle_count + 1;

      // Provide data from buffer_a when ena_o is high
      if (ena_o && !wea_o) begin
        worda_i = buffer_a[addra_o];
        $display("Cycle %0d: Reading A from addr %h: %h", cycle_count, addra_o, worda_i);
      end else worda_i = 0;

      // Provide data from buffer_b when enb_o is high
      if (enb_o && !web_o) begin
        wordb_i = buffer_b[addrb_o];
        $display("Cycle %0d: Reading B from addr %h: %h", cycle_count, addrb_o, wordb_i);
      end else wordb_i = 0;

      // Write result to buffer_p when wep_o is high
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

    // --- Test 2: Matrix Multiplication 20x20 x 20x20 (Tiling) ---
    #50;
    $display("\nTest 2: Matrix Multiplication 20x20 x 20x20 (Tiling)");

    // Reset buffers
    for (i = 0; i < 4096; i = i + 1) begin
      buffer_a[i] = 0;
      buffer_b[i] = 0;
      buffer_p[i] = 0;
      expected_p[i] = 0;
    end

    // Initialize matrices A (20x20) and B (20x20)
    m_i = 20;
    k_i = 20;
    n_i = 20;
    base_addra_i = 12'h000;
    base_addrb_i = 12'h100;
    base_addrp_i = 12'h200;

    // Fill buffer_a with A = [[1, 1, ..., 1], [2, 2, ..., 2], ..., [20, 20, ..., 20]]
    for (i = 0; i < 20; i = i + 1) begin
      for (j = 0; j < 20; j = j + 1) begin
        buffer_a[i*2 + (j/10)][(j%10)*16 +: 16] = i + 1;  // 2 words per row (10 elements each)
      end
    end

    // Fill buffer_b with B = Identity matrix
    for (i = 0; i < 20; i = i + 1) begin
      for (j = 0; j < 20; j = j + 1) begin
        buffer_b[i*2 + (j/10)][(j%10)*16 +: 16] = (i == j) ? 1 : 0;
      end
    end

    // Calculate expected output C = A * B = A (since B is identity)
    for (i = 0; i < 20; i = i + 1) begin
      for (j = 0; j < 20; j = j + 1) begin
        expected_p[i*2 + (j/10)][(j%10)*16 +: 16] = buffer_a[i*2 + (j/10)][(j%10)*16 +: 16];
      end
    end

    // Start the TPU
    #10 start_i = 1;
    #10 start_i = 0;
    cycle_count = 0;

    // Simulate global buffer read/write
    while (!valid_o) begin
      @(posedge clk_i);
      cycle_count = cycle_count + 1;

      if (ena_o && !wea_o) begin
        worda_i = buffer_a[addra_o];
        $display("Cycle %0d: Reading A from addr %h: %h", cycle_count, addra_o, worda_i);
      end else worda_i = 0;

      if (enb_o && !web_o) begin
        wordb_i = buffer_b[addrb_o];
        $display("Cycle %0d: Reading B from addr %h: %h", cycle_count, addrb_o, wordb_i);
      end else wordb_i = 0;

      if (enp_o && wep_o) begin
        buffer_p[addrp_o] = wordp_o;
        $display("Cycle %0d: Writing P to addr %h: %h", cycle_count, addrp_o, wordp_o);
      end
    end

    // Check results
    #20;
    $display("Test 2 Results:");
    for (i = 0; i < 4; i = i + 1) begin  // 20 rows = 4 words (2 words per row)
      if (buffer_p[base_addrp_i + i] === expected_p[i])
        $display("Block %0d: PASS - Expected: %h, Got: %h", i, expected_p[i], buffer_p[base_addrp_i + i]);
      else
        $display("Block %0d: FAIL - Expected: %h, Got: %h", i, expected_p[i], buffer_p[base_addrp_i + i]);
    end

    // Finish simulation
    #50 $finish;
  end

endmodule
