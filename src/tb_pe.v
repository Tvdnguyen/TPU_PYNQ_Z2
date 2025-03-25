module tb_pe;
  reg clk_i, rst_ni, clr_i, we_i;
  reg [15:0] srca_i, srcb_i, psum_i;
  wire [15:0] psum_o;

  pe uut (
    .clk_i(clk_i), .rst_ni(rst_ni), .clr_i(clr_i), .we_i(we_i),
    .srca_i(srca_i), .srcb_i(srcb_i), .psum_i(psum_i), .psum_o(psum_o)
  );

  initial begin
    clk_i = 0;
    forever #5 clk_i = ~clk_i; // Chu kỳ 10ns
  end

  initial begin
    // Reset
    rst_ni = 0; clr_i = 0; we_i = 0; srca_i = 0; srcb_i = 0; psum_i = 0;
    #20 rst_ni = 1;

    // Test 1: Nhân và cộng dồn đơn giản
    #10 clr_i = 1; // Xóa psum_q
    #10 clr_i = 0; we_i = 1; srca_i = 16'h000a; srcb_i = 16'h0002; psum_i = 16'h0000;
    #10 we_i = 1; srca_i = 16'h0009; srcb_i = 16'h0000; psum_i = 16'h0000;
    #10 we_i = 0; // Dừng ghi

    // Test 2: Kiểm tra tích lũy với psum_i
    #10 clr_i = 1;
    #10 clr_i = 0; we_i = 1; srca_i = 16'h0005; srcb_i = 16'h0003; psum_i = 16'h000a;
    #10 we_i = 0;

    #20 $finish;
  end

  initial $monitor("t=%0t: rst_ni=%b, clr_i=%b, we_i=%b, srca_i=%h, srcb_i=%h, psum_i=%h, psum_o=%h",
                   $time, rst_ni, clr_i, we_i, srca_i, srcb_i, psum_i, psum_o);
endmodule
